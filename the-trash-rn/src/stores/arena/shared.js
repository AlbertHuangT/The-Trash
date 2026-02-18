import { useAchievementStore } from 'src/stores/achievementStore';

export const SPEED_DURATION = 60;
export const DUEL_COUNTDOWN_SECONDS = 3;
export const DUEL_COMPLETE_RETRY_MS = 1200;
export const DUEL_COMPLETE_MAX_ATTEMPTS = 20;
export const DUEL_CLOCK_OFFSET_CACHE_MS = 1000 * 60 * 5;
export const DUEL_GC_INTERVAL_MS = 1000 * 30;
export const DUEL_STALE_SESSION_MS = 1000 * 60 * 10;

export const initialClassic = {
  sessionId: null,
  question: null,
  questionIndex: 0,
  score: 0,
  state: 'idle',
  lastAnswerCorrect: null
};

export const initialSpeed = {
  sessionId: null,
  question: null,
  score: 0,
  remaining: SPEED_DURATION,
  total: SPEED_DURATION,
  state: 'idle'
};

export const initialStreak = {
  question: null,
  current: 0,
  best: 0,
  state: 'idle'
};

export const initialDailyChallenge = {
  id: null,
  prompt: '加载中…',
  progress: 0,
  total: 0,
  reward: null,
  state: 'idle'
};

export const normalizeAnswer = (value) =>
  String(value ?? '')
    .trim()
    .toLowerCase();

export const notifyAchievement = (payload) => {
  useAchievementStore.getState().checkAndGrant(payload);
};

export const sleep = (ms) =>
  new Promise((resolve) => {
    setTimeout(resolve, ms);
  });

export const toId = (value) => {
  if (value == null) return null;
  return String(value);
};

export const isSameId = (a, b) => {
  const left = toId(a);
  const right = toId(b);
  return Boolean(left && right && left === right);
};

export const resolveOpponentId = ({ myUserId, challengerId, opponentId }) => {
  if (!myUserId) return null;
  if (isSameId(myUserId, challengerId)) return toId(opponentId);
  if (isSameId(myUserId, opponentId)) return toId(challengerId);
  return toId(opponentId ?? challengerId);
};

export const toNumber = (value) => {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
};

export const getEstimatedServerNow = (offsetMs = 0) =>
  Date.now() + Number(offsetMs ?? 0);

export const computeCountdownSeconds = (startAtServerMs, offsetMs = 0) => {
  const startAt = toNumber(startAtServerMs);
  if (startAt == null) return 0;
  const remainingMs = startAt - getEstimatedServerNow(offsetMs);
  return Math.max(0, Math.ceil(remainingMs / 1000));
};
