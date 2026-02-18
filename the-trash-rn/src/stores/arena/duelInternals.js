import { DUEL_GC_INTERVAL_MS, DUEL_STALE_SESSION_MS } from './shared';

const duelCountdownTimers = new Map();
const duelEventQueues = new Map();
let duelGcInterval = null;

export const clearDuelCountdown = (duelId) => {
  const timer = duelCountdownTimers.get(duelId);
  if (timer) {
    clearInterval(timer);
    duelCountdownTimers.delete(duelId);
  }
};

export const registerDuelCountdown = (duelId, timer) => {
  duelCountdownTimers.set(duelId, timer);
};

export const queueDuelEvent = (duelId, task) => {
  const previous = duelEventQueues.get(duelId) ?? Promise.resolve();
  const next = previous
    .catch(() => {})
    .then(task)
    .catch((error) => {
      console.warn('[arenaStore] duel event queue error', duelId, error);
    });

  duelEventQueues.set(
    duelId,
    next.finally(() => {
      if (duelEventQueues.get(duelId) === next) {
        duelEventQueues.delete(duelId);
      }
    })
  );

  return next;
};

export const clearQueuedDuelEvents = (duelId) => {
  duelEventQueues.delete(duelId);
};

export const createDuelState = (duelId, submit) => ({
  id: duelId,
  status: 'loading',
  opponent: '等待对手',
  countdown: 0,
  countdownStartAtServerMs: null,
  questions: [],
  totalQuestions: 0,
  currentIndex: 0,
  currentQuestion: null,
  score: 0,
  correctCount: 0,
  myReady: false,
  opponentReady: false,
  bothReady: false,
  opponentProgress: 0,
  opponentCorrect: 0,
  opponentScore: 0,
  opponentFinished: false,
  opponentOnline: false,
  hasFinished: false,
  awaitingResult: false,
  finalizing: false,
  submitting: false,
  realtimeStatus: 'idle',
  channelName: null,
  challengerId: null,
  opponentId: null,
  myUserId: null,
  result: null,
  error: null,
  send: null,
  sendReady: null,
  sendAnswerSubmitted: null,
  sendFinished: null,
  unsubscribe: null,
  submit,
  createdAt: Date.now(),
  updatedAt: Date.now()
});

export const patchDuel = (state, duelId, patch) => {
  const duel = state.duels[duelId];
  if (!duel) return null;
  return {
    ...state.duels,
    [duelId]: {
      ...duel,
      ...patch,
      updatedAt: Date.now()
    }
  };
};

const ACTIVE_DUEL_STATUSES = new Set(['playing', 'countdown', 'finalizing']);

export const ensureDuelWatchdog = (get, set) => {
  if (duelGcInterval) return;

  duelGcInterval = setInterval(() => {
    const now = Date.now();
    const state = get();
    const staleIds = Object.entries(state.duels)
      .filter(([, duel]) => {
        if (!duel) return false;
        if (ACTIVE_DUEL_STATUSES.has(duel.status)) return false;
        const updatedAt = Number(duel.updatedAt ?? duel.createdAt ?? now);
        return now - updatedAt > DUEL_STALE_SESSION_MS;
      })
      .map(([id]) => id);

    if (!staleIds.length) return;

    staleIds.forEach((duelId) => {
      clearDuelCountdown(duelId);
      const duel = get().duels[duelId];
      duel?.unsubscribe?.();
      clearQueuedDuelEvents(duelId);
    });

    set((current) => {
      const duels = { ...current.duels };
      staleIds.forEach((duelId) => {
        delete duels[duelId];
      });
      return { duels };
    });
  }, DUEL_GC_INTERVAL_MS);
};
