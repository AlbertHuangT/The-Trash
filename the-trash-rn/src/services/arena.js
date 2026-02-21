import AsyncStorage from '@react-native-async-storage/async-storage';

import { hasSupabaseConfig } from 'src/services/config';
import { AppError, ERROR_CODES, fromSupabaseError } from 'src/utils/errors';

import { supabase } from './supabase';

const supabaseUrl = process.env.EXPO_PUBLIC_SUPABASE_URL;
const supabaseAnonKey = process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY;

// Fallback quiz options (English) — these match the quiz_questions.correct_category
// schema, NOT the classifier's Chinese category names (可回收/湿垃圾/干垃圾/有害垃圾).
const QUIZ_OPTIONS = ['Recyclable', 'Compostable', 'Hazardous', 'Landfill'];
const SPEED_DURATION = 60;
const CLASSIC_SESSIONS_STORAGE_KEY = 'the-trash/arena/classic-sessions-v1';
const SPEED_SESSIONS_STORAGE_KEY = 'the-trash/arena/speed-sessions-v1';
const SESSION_TTL_MS = 1000 * 60 * 60 * 6;

const classicSessions = new Map();
const speedSessions = new Map();
let sessionsHydrationPromise = null;

const normalizeAnswer = (value) =>
  String(value ?? '')
    .trim()
    .toLowerCase();

const formatQuestion = (row) => {
  if (!row) return null;
  return {
    id: row.id ?? row.question_id ?? `q-${Date.now()}`,
    prompt:
      row.prompt ??
      row.question ??
      (row.item_name
        ? `Where should "${row.item_name}" go?`
        : 'How should this item be sorted?'),
    options:
      Array.isArray(row.options) && row.options.length
        ? row.options
        : QUIZ_OPTIONS,
    answer: row.correct_category ?? row.correct_answer ?? row.answer ?? null,
    imageUrl: row.image_url ?? null,
    itemName: row.item_name ?? null
  };
};

const rpc = async (fn, args = {}) => {
  const { data, error } = await supabase.rpc(fn, args);
  if (error) {
    throw fromSupabaseError(error, {
      message: '请求竞技场服务失败'
    });
  }
  return data;
};

const getCurrentUserId = async () => {
  const { data, error } = await supabase.auth.getUser();
  if (error) {
    throw fromSupabaseError(error, {
      code: ERROR_CODES.AUTH,
      message: '读取用户信息失败'
    });
  }
  return data.user?.id ?? null;
};

const fetchQuestionBatch = async (limit = 10) => {
  const rows = await rpc('get_quiz_questions_batch', { p_limit: limit });
  return (rows ?? []).map(formatQuestion).filter(Boolean);
};

const restoreSessionMap = async (storageKey, targetMap) => {
  try {
    const raw = await AsyncStorage.getItem(storageKey);
    if (!raw) return;
    const entries = JSON.parse(raw);
    if (!Array.isArray(entries)) return;
    const now = Date.now();
    entries.forEach((entry) => {
      if (!Array.isArray(entry) || entry.length !== 2) return;
      const [sessionId, payload] = entry;
      if (!sessionId || !payload || typeof payload !== 'object') return;
      const persistedAt = Number(payload.persistedAt ?? 0);
      if (persistedAt && now - persistedAt > SESSION_TTL_MS) return;
      if (!Array.isArray(payload.questions) || payload.questions.length === 0)
        return;
      const index = Number.isFinite(payload.index) ? Number(payload.index) : 0;
      targetMap.set(String(sessionId), {
        questions: payload.questions,
        index: Math.max(0, Math.min(index, payload.questions.length - 1))
      });
    });
  } catch (error) {
    console.warn(
      '[arenaService] restore session map failed',
      storageKey,
      error
    );
  }
};

const persistSessionMap = async (storageKey, sourceMap) => {
  try {
    const persistedAt = Date.now();
    const entries = Array.from(sourceMap.entries()).map(([id, value]) => [
      id,
      { ...value, persistedAt }
    ]);
    await AsyncStorage.setItem(storageKey, JSON.stringify(entries));
  } catch (error) {
    console.warn(
      '[arenaService] persist session map failed',
      storageKey,
      error
    );
  }
};

const ensureSessionsHydrated = async () => {
  if (sessionsHydrationPromise) {
    await sessionsHydrationPromise;
    return;
  }

  sessionsHydrationPromise = Promise.all([
    restoreSessionMap(CLASSIC_SESSIONS_STORAGE_KEY, classicSessions),
    restoreSessionMap(SPEED_SESSIONS_STORAGE_KEY, speedSessions)
  ]).finally(() => {
    sessionsHydrationPromise = Promise.resolve();
  });

  await sessionsHydrationPromise;
};

export const arenaService = {
  async fetchServerTimeOffset() {
    if (!supabaseUrl || !supabaseAnonKey) return 0;

    try {
      const requestStartedAt = Date.now();
      const response = await fetch(`${supabaseUrl}/rest/v1/`, {
        method: 'HEAD',
        headers: {
          apikey: supabaseAnonKey,
          Authorization: `Bearer ${supabaseAnonKey}`
        }
      });
      const requestEndedAt = Date.now();
      const dateHeader = response.headers.get('date');

      if (!dateHeader) return 0;

      const serverMs = new Date(dateHeader).getTime();
      if (!Number.isFinite(serverMs)) return 0;

      const roundTripMs = requestEndedAt - requestStartedAt;
      const estimatedClientAtServerMs = requestStartedAt + roundTripMs / 2;
      return serverMs - estimatedClientAtServerMs;
    } catch (error) {
      console.warn('[arenaService] fetchServerTimeOffset failed', error);
      return 0;
    }
  },

  async getCurrentUserId() {
    if (!hasSupabaseConfig()) return null;
    return getCurrentUserId();
  },

  async fetchQuestion() {
    if (!hasSupabaseConfig()) return null;
    const rows = await fetchQuestionBatch(1);
    return rows[0] ?? null;
  },

  async startClassic() {
    await ensureSessionsHydrated();
    const questions = hasSupabaseConfig() ? await fetchQuestionBatch(10) : [];
    if (!questions.length) {
      throw new AppError('题库为空，请先检查 Supabase 题目数据', {
        code: ERROR_CODES.BACKEND
      });
    }
    const sessionId = `classic-${Date.now()}`;
    classicSessions.set(sessionId, { questions, index: 0 });
    await persistSessionMap(CLASSIC_SESSIONS_STORAGE_KEY, classicSessions);
    return {
      sessionId,
      question: questions[0]
    };
  },

  async submitClassic({ sessionId, questionId, answer }) {
    await ensureSessionsHydrated();
    const session = classicSessions.get(sessionId);
    if (!session) {
      throw new AppError('经典模式会话不存在，请重新开始', {
        code: ERROR_CODES.VALIDATION
      });
    }
    const current = session.questions[session.index];
    const isSameQuestion = current?.id === questionId;
    const correct = isSameQuestion
      ? normalizeAnswer(current.answer) === normalizeAnswer(answer)
      : false;
    const nextIndex = session.index + 1;
    const nextQuestion = session.questions[nextIndex] ?? null;

    if (nextQuestion) {
      classicSessions.set(sessionId, { ...session, index: nextIndex });
    } else {
      classicSessions.delete(sessionId);
    }
    await persistSessionMap(CLASSIC_SESSIONS_STORAGE_KEY, classicSessions);

    return {
      correct,
      nextQuestion
    };
  },

  async startSpeedSort() {
    await ensureSessionsHydrated();
    const questions = hasSupabaseConfig() ? await fetchQuestionBatch(80) : [];
    if (!questions.length) {
      throw new AppError('没有可用题目，无法开始极速模式', {
        code: ERROR_CODES.BACKEND
      });
    }
    const sessionId = `speed-${Date.now()}`;
    speedSessions.set(sessionId, { questions, index: 0 });
    await persistSessionMap(SPEED_SESSIONS_STORAGE_KEY, speedSessions);
    return {
      sessionId,
      question: questions[0],
      duration: SPEED_DURATION
    };
  },

  async submitSpeedAnswer({ sessionId, questionId, answer }) {
    await ensureSessionsHydrated();
    const session = speedSessions.get(sessionId);
    if (!session) {
      throw new AppError('极速模式会话不存在，请重新开始', {
        code: ERROR_CODES.VALIDATION
      });
    }
    const current = session.questions[session.index];
    const isSameQuestion = current?.id === questionId;
    const correct = isSameQuestion
      ? normalizeAnswer(current.answer) === normalizeAnswer(answer)
      : false;
    const nextIndex = (session.index + 1) % session.questions.length;
    const nextQuestion = session.questions[nextIndex] ?? null;
    speedSessions.set(sessionId, { ...session, index: nextIndex });
    await persistSessionMap(SPEED_SESSIONS_STORAGE_KEY, speedSessions);
    return {
      correct,
      question: nextQuestion,
      scoreDelta: correct ? 1 : 0
    };
  },

  async fetchDailyChallenge() {
    if (!hasSupabaseConfig()) {
      return {
        id: null,
        prompt: '请先配置 Supabase',
        progress: 0,
        total: 0,
        reward: null,
        alreadyPlayed: false,
        questions: []
      };
    }
    const data = await rpc('get_daily_challenge');
    const questions = (data?.questions ?? [])
      .map(formatQuestion)
      .filter(Boolean);
    const total = questions.length;
    const progress = data?.already_played ? total : 0;
    return {
      id: data?.challenge_id ?? null,
      prompt: total ? `今日挑战 ${total} 题` : '今日暂无挑战',
      progress,
      total,
      reward: '完成后自动结算积分',
      alreadyPlayed: Boolean(data?.already_played),
      questions
    };
  },

  async submitDailyChallenge(payload = {}) {
    if (!hasSupabaseConfig()) return true;
    const score = Number(payload.score ?? 100);
    const correctCount = Number(payload.correctCount ?? 10);
    const timeSeconds = Number(payload.timeSeconds ?? 60);
    const maxCombo = Number(payload.maxCombo ?? 10);
    await rpc('submit_daily_challenge', {
      p_score: score,
      p_correct_count: correctCount,
      p_time_seconds: timeSeconds,
      p_max_combo: maxCombo
    });
    return true;
  },

  async fetchStreakStats() {
    if (!hasSupabaseConfig()) {
      return { best: 0, current: 0 };
    }
    const userId = await getCurrentUserId();
    if (!userId) {
      return { best: 0, current: 0 };
    }
    const { data, error } = await supabase
      .from('streak_records')
      .select('streak_count')
      .eq('user_id', userId)
      .order('streak_count', { ascending: false })
      .limit(1);
    if (error) {
      throw fromSupabaseError(error, {
        message: '加载连击数据失败'
      });
    }
    return {
      best: data?.[0]?.streak_count ?? 0,
      current: 0
    };
  },

  async submitStreakAnswer({ finished, streakCount }) {
    if (!hasSupabaseConfig()) {
      return { correct: true };
    }
    if (!finished) {
      return { correct: true };
    }
    await rpc('submit_streak_record', {
      p_streak_count: Number(streakCount ?? 0)
    });
    return { correct: true };
  },

  async fetchLeaderboards() {
    if (!hasSupabaseConfig()) {
      return { daily: [], streak: [] };
    }
    const [daily, streak] = await Promise.all([
      rpc('get_daily_leaderboard', { p_limit: 20 }),
      rpc('get_streak_leaderboard', { p_limit: 20 })
    ]);
    return {
      daily: (daily ?? []).map((item) => ({
        id: item.user_id ?? String(item.rank),
        name: item.display_name ?? 'Anonymous',
        city: `答对 ${item.correct_count ?? 0} 题`,
        score: item.score ?? 0
      })),
      streak: (streak ?? []).map((item) => ({
        id: item.user_id ?? String(item.display_name),
        name: item.display_name ?? 'Anonymous',
        community: `总场次 ${item.total_games ?? 0}`,
        streak: item.best_streak ?? 0
      }))
    };
  },

  async fetchPendingChallenges() {
    if (!hasSupabaseConfig()) {
      return {};
    }
    const userId = await getCurrentUserId();
    const rows = await rpc('get_my_challenges', { p_status: 'pending' });
    const pending = Array.isArray(rows) ? rows : [];
    const map = {};
    pending.forEach((item) => {
      const isChallenger = item.challenger_id === userId;
      map[item.id] = {
        id: item.id,
        status: item.status,
        mode: 'duel',
        channelName: item.channel_name,
        createdAt: item.created_at,
        opponentId: isChallenger ? item.opponent_id : item.challenger_id,
        opponentName: isChallenger ? item.opponent_name : item.challenger_name
      };
    });
    return map;
  },

  async fetchFriends() {
    if (!hasSupabaseConfig()) {
      return [];
    }
    const rows = await rpc('get_daily_leaderboard', { p_limit: 30 });
    const userId = await getCurrentUserId();
    return (rows ?? [])
      .filter((item) => item.user_id && item.user_id !== userId)
      .map((item) => ({
        id: item.user_id,
        name: item.display_name ?? 'Anonymous',
        score: item.score ?? 0
      }));
  },

  async sendInvite(friendId) {
    if (!hasSupabaseConfig()) {
      throw new AppError('请先连接 Supabase', { code: ERROR_CODES.BACKEND });
    }
    const data = await rpc('create_arena_challenge', {
      p_opponent_id: friendId
    });
    if (!data?.challenge_id) {
      throw new AppError('创建对战失败', { code: ERROR_CODES.BACKEND });
    }
    return {
      id: data.challenge_id,
      opponentId: friendId,
      mode: 'duel',
      status: data.status ?? 'pending',
      channelName: data.channel_name
    };
  },

  async acceptChallenge(challengeId) {
    if (!hasSupabaseConfig()) {
      throw new AppError('请先连接 Supabase', { code: ERROR_CODES.BACKEND });
    }
    const data = await rpc('accept_arena_challenge', {
      p_challenge_id: challengeId
    });
    return {
      id: data?.challenge_id ?? challengeId,
      duelId: data?.challenge_id ?? challengeId,
      channelName: data?.channel_name,
      questions: (data?.questions ?? []).map(formatQuestion).filter(Boolean),
      challengerId: data?.challenger_id,
      opponentId: data?.opponent_id
    };
  },

  async getChallengeQuestions(challengeId) {
    if (!hasSupabaseConfig()) {
      return { questions: [], channelName: null };
    }
    const data = await rpc('get_challenge_questions', {
      p_challenge_id: challengeId
    });
    const myUserId = await getCurrentUserId();
    return {
      challengeId: data?.challenge_id ?? challengeId,
      channelName: data?.channel_name,
      questions: (data?.questions ?? []).map(formatQuestion).filter(Boolean),
      challengerId: data?.challenger_id,
      opponentId: data?.opponent_id,
      myUserId
    };
  },

  async submitDuelAnswer({
    challengeId,
    questionIndex,
    selectedCategory,
    answerTimeMs = 0
  }) {
    if (!hasSupabaseConfig()) {
      return { is_correct: false, correct_category: null };
    }
    return rpc('submit_duel_answer', {
      p_challenge_id: challengeId,
      p_question_index: questionIndex,
      p_selected_category: selectedCategory,
      p_answer_time_ms: answerTimeMs
    });
  },

  async completeDuel(challengeId) {
    if (!hasSupabaseConfig()) {
      return null;
    }
    return rpc('complete_arena_challenge', {
      p_challenge_id: challengeId
    });
  }
};
