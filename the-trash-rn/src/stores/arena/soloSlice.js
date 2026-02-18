import { arenaService } from 'src/services/arena';
import { dailyChallengeService } from 'src/services/dailyChallenge';
import { streakModeService } from 'src/services/streakMode';

import {
  initialClassic,
  initialDailyChallenge,
  initialSpeed,
  initialStreak,
  normalizeAnswer,
  notifyAchievement
} from './shared';

let speedTimerRef = null;

export const createSoloArenaSlice = (set, get) => ({
  classic: { ...initialClassic },
  speed: { ...initialSpeed },
  streak: { ...initialStreak },
  dailyChallenge: { ...initialDailyChallenge },
  pendingChallenges: {},
  friends: [],
  dailyLeaderboard: [],
  streakLeaderboard: [],

  async startClassic() {
    set({ classic: { ...initialClassic, state: 'loading' } });
    const session = await arenaService.startClassic();
    set({
      classic: {
        sessionId: session.sessionId,
        question: session.question,
        questionIndex: 1,
        score: 0,
        state: 'playing',
        lastAnswerCorrect: null
      }
    });
  },

  async answerClassic(option) {
    const { classic } = get();
    if (!classic.question) return;
    const result = await arenaService.submitClassic({
      sessionId: classic.sessionId,
      questionId: classic.question.id,
      answer: option
    });
    const newScore = result.correct ? classic.score + 10 : classic.score;
    set({
      classic: {
        ...classic,
        score: newScore,
        question: result.nextQuestion,
        questionIndex: result.nextQuestion
          ? classic.questionIndex + 1
          : classic.questionIndex,
        lastAnswerCorrect: result.correct,
        state: result.nextQuestion ? 'playing' : 'finished'
      }
    });
    notifyAchievement({
      type: 'arena',
      mode: 'classic',
      correct: result.correct,
      score: newScore
    });
  },

  async startSpeedSort() {
    clearInterval(speedTimerRef);
    set({ speed: { ...initialSpeed, state: 'loading' } });
    const session = await arenaService.startSpeedSort();
    set({
      speed: {
        sessionId: session.sessionId,
        question: session.question,
        score: 0,
        remaining: session.duration,
        total: session.duration,
        state: 'playing'
      }
    });
    speedTimerRef = setInterval(() => {
      set((state) => {
        if (state.speed.remaining <= 1) {
          clearInterval(speedTimerRef);
          return {
            speed: {
              ...state.speed,
              state: 'finished',
              remaining: 0
            }
          };
        }
        return {
          speed: {
            ...state.speed,
            remaining: state.speed.remaining - 1
          }
        };
      });
    }, 1000);
  },

  async answerSpeedSort(option) {
    const { speed } = get();
    if (!speed.question || speed.state !== 'playing') return;
    const result = await arenaService.submitSpeedAnswer({
      sessionId: speed.sessionId,
      questionId: speed.question.id,
      answer: option
    });
    const newScore = speed.score + (result.scoreDelta ?? 0);
    set({
      speed: {
        ...speed,
        score: newScore,
        question: result.question
      }
    });
    if (result.correct) {
      notifyAchievement({
        type: 'arena',
        mode: 'speed',
        score: newScore,
        correct: true
      });
    }
  },

  stopSpeedSort() {
    clearInterval(speedTimerRef);
    set({ speed: { ...initialSpeed } });
  },

  async loadStreakStats() {
    const stats = await streakModeService.fetchStats();
    set({
      streak: {
        ...initialStreak,
        best: stats.best ?? 0,
        current: stats.current ?? 0
      }
    });
  },

  async startStreakSession() {
    await get().loadStreakStats();
    const question = await arenaService.fetchQuestion('streak');
    set((state) => ({
      streak: {
        ...state.streak,
        question,
        current: 0,
        state: question ? 'playing' : 'idle'
      }
    }));
  },

  async answerStreak(option) {
    const { streak } = get();
    if (!streak.question || streak.state !== 'playing') return;
    const correct =
      normalizeAnswer(streak.question.answer) === normalizeAnswer(option);
    const finished = !correct;
    const achievedStreak = correct ? streak.current + 1 : streak.current;
    await streakModeService.submitAnswer({
      finished,
      streakCount: achievedStreak
    });
    const nextQuestion = await arenaService.fetchQuestion('streak');
    const nextCurrent = correct ? streak.current + 1 : 0;
    const nextBest = correct ? Math.max(streak.best, nextCurrent) : streak.best;
    set({
      streak: {
        question: nextQuestion,
        current: nextCurrent,
        best: nextBest,
        state: correct ? 'playing' : 'cooldown'
      }
    });
    if (correct) {
      notifyAchievement({
        type: 'arena',
        mode: 'streak',
        streak: nextCurrent
      });
    }
  },

  async loadDailyChallenge() {
    const challenge = await dailyChallengeService.fetch();
    set({
      dailyChallenge: {
        ...challenge,
        state: challenge?.alreadyPlayed ? 'completed' : 'ready'
      }
    });
  },

  async incrementDailyChallenge() {
    const { dailyChallenge } = get();
    if (!dailyChallenge.id || dailyChallenge.state === 'completed') return;
    await dailyChallengeService.submit({
      score: dailyChallenge.total * 10,
      correctCount: dailyChallenge.total,
      timeSeconds: 60,
      maxCombo: dailyChallenge.total
    });
    const nextProgress = dailyChallenge.total;
    set({
      dailyChallenge: {
        ...dailyChallenge,
        progress: nextProgress,
        state: 'completed'
      }
    });
    notifyAchievement({ type: 'arena', mode: 'daily', completed: true });
  },

  async loadLeaderboards() {
    const data = await arenaService.fetchLeaderboards();
    set({
      dailyLeaderboard: data.daily ?? [],
      streakLeaderboard: data.streak ?? []
    });
  },

  async refreshChallenges() {
    const pending = await arenaService.fetchPendingChallenges();
    set({ pendingChallenges: pending ?? {} });
  },

  async loadFriends() {
    const friends = await arenaService.fetchFriends();
    set({ friends });
  },

  async sendInvite(friendId, mode = 'duel') {
    const challenge = await arenaService.sendInvite(friendId, mode);
    set((state) => ({
      pendingChallenges: {
        ...state.pendingChallenges,
        [challenge.id]: challenge
      }
    }));
  },

  async acceptDeepLink(id) {
    await get().refreshChallenges();
    return `/(tabs)/arena/duel/${id}`;
  }
});
