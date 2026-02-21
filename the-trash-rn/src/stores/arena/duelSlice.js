import { arenaService } from 'src/services/arena';
import { realtimeService } from 'src/services/realtime';

import {
  clearDuelCountdown,
  clearQueuedDuelEvents,
  createDuelState,
  ensureDuelWatchdog,
  hasDuelCountdown,
  patchDuel,
  queueDuelEvent,
  registerDuelCountdown
} from './duelInternals';
import {
  DUEL_CLOCK_OFFSET_CACHE_MS,
  DUEL_COMPLETE_MAX_ATTEMPTS,
  DUEL_COMPLETE_RETRY_MS,
  DUEL_COUNTDOWN_SECONDS,
  computeCountdownSeconds,
  getEstimatedServerNow,
  isSameId,
  notifyAchievement,
  resolveOpponentId,
  sleep,
  toNumber
} from './shared';

export const createDuelArenaSlice = (set, get) => {
  if (process.env.NODE_ENV !== 'test') {
    ensureDuelWatchdog(get, set);
  }

  return {
    duels: {},
    serverTimeOffsetMs: 0,
    serverTimeOffsetFetchedAt: 0,

    async syncServerTimeOffset({ force = false } = {}) {
      const cachedAt = Number(get().serverTimeOffsetFetchedAt ?? 0);
      const now = Date.now();
      if (
        !force &&
        cachedAt > 0 &&
        now - cachedAt < DUEL_CLOCK_OFFSET_CACHE_MS
      ) {
        return Number(get().serverTimeOffsetMs ?? 0);
      }

      const offsetMs = await arenaService.fetchServerTimeOffset();
      set({
        serverTimeOffsetMs: Number(offsetMs ?? 0),
        serverTimeOffsetFetchedAt: Date.now()
      });
      return Number(offsetMs ?? 0);
    },

    async acceptChallenge(challengeId) {
      const payload = await arenaService.acceptChallenge(challengeId);
      const duelId = payload?.duelId ?? challengeId;

      set((state) => {
        const duel =
          state.duels[duelId] ??
          createDuelState(duelId, (option) =>
            get().submitDuelAnswer(duelId, option)
          );
        return {
          duels: {
            ...state.duels,
            [duelId]: {
              ...duel,
              status: 'lobby',
              channelName: payload?.channelName ?? duel.channelName,
              challengerId: payload?.challengerId ?? duel.challengerId,
              opponentId: payload?.opponentId ?? duel.opponentId,
              questions: payload?.questions ?? duel.questions,
              totalQuestions: (payload?.questions ?? duel.questions ?? [])
                .length,
              currentQuestion:
                (payload?.questions ?? duel.questions)?.[0] ?? null,
              currentIndex: 0,
              hasFinished: false,
              awaitingResult: false,
              finalizing: false,
              error: null
            }
          }
        };
      });

      await get().ensureDuel(duelId, { preloadedPayload: payload });
      await get().refreshChallenges();
      return {
        ...payload,
        duelId
      };
    },

    async ensureDuel(duelId, options = {}) {
      if (!duelId) return null;

      const existing = get().duels[duelId];
      if (!existing) {
        set((state) => ({
          duels: {
            ...state.duels,
            [duelId]: createDuelState(duelId, (option) =>
              get().submitDuelAnswer(duelId, option)
            )
          }
        }));
      }

      let payload = options.preloadedPayload ?? null;
      try {
        if (!payload) {
          payload = await arenaService.getChallengeQuestions(duelId);
        }
      } catch (error) {
        console.warn('[arenaStore] getChallengeQuestions failed', error);
        set((state) => {
          const duels = patchDuel(state, duelId, {
            status: 'lobby',
            error: '无法加载对战题目'
          });
          return duels ? { duels } : {};
        });
        return get().duels[duelId] ?? null;
      }

      const myUserId =
        payload?.myUserId ?? (await arenaService.getCurrentUserId());
      const challengerId = payload?.challengerId ?? null;
      const opponentId = payload?.opponentId ?? null;
      const remoteOpponentId = resolveOpponentId({
        myUserId,
        challengerId,
        opponentId
      });
      const channelName = payload?.channelName ?? `duel:${duelId}`;
      const pending = get().pendingChallenges[duelId];

      const onPlayerReady = ({ userId, isOpponent }) => {
        queueDuelEvent(duelId, async () => {
          if (!userId) return;
          const latest = get().duels[duelId];
          if (!latest) return;
          if (isSameId(userId, latest.myUserId ?? myUserId)) return;

          const opponentReady = Boolean(
            isOpponent ||
            !remoteOpponentId ||
            latest.opponentReady ||
            isSameId(userId, latest.opponentId) ||
            isSameId(userId, latest.challengerId)
          );
          const bothReady = Boolean(latest.myReady && opponentReady);

          set((state) => {
            const duel = state.duels[duelId];
            if (!duel) return {};
            return {
              duels: {
                ...state.duels,
                [duelId]: {
                  ...duel,
                  opponentReady,
                  bothReady
                }
              }
            };
          });

          if (bothReady) {
            await get().beginSynchronizedCountdown(duelId);
          }
        });
      };

      const onAnswerSubmitted = ({ userId, questionIndex, isCorrect }) => {
        queueDuelEvent(duelId, async () => {
          const latest = get().duels[duelId];
          if (!latest) return;
          if (!userId || isSameId(userId, latest.myUserId ?? myUserId)) return;

          set((state) => {
            const duel = state.duels[duelId];
            if (!duel) return {};
            const safeIndex = Number.isFinite(questionIndex)
              ? questionIndex
              : 0;
            return {
              duels: {
                ...state.duels,
                [duelId]: {
                  ...duel,
                  opponentProgress: Math.max(
                    duel.opponentProgress,
                    safeIndex + 1
                  ),
                  opponentCorrect: isCorrect
                    ? duel.opponentCorrect + 1
                    : duel.opponentCorrect,
                  opponentScore: isCorrect
                    ? duel.opponentScore + 20
                    : duel.opponentScore
                }
              }
            };
          });
        });
      };

      const onPlayerFinished = ({ userId, totalCorrect, totalScore }) => {
        queueDuelEvent(duelId, async () => {
          const latest = get().duels[duelId];
          if (!latest) return;
          if (!userId || isSameId(userId, latest.myUserId ?? myUserId)) return;

          set((state) => {
            const duel = state.duels[duelId];
            if (!duel) return {};
            const nextStatus = duel.hasFinished
              ? 'finalizing'
              : 'waiting-result';
            return {
              duels: {
                ...state.duels,
                [duelId]: {
                  ...duel,
                  opponentFinished: true,
                  opponentProgress:
                    duel.totalQuestions > 0
                      ? Math.max(duel.opponentProgress, duel.totalQuestions)
                      : duel.opponentProgress,
                  opponentCorrect: Number.isFinite(totalCorrect)
                    ? totalCorrect
                    : duel.opponentCorrect,
                  opponentScore: Number.isFinite(totalScore)
                    ? totalScore
                    : duel.opponentScore,
                  status: nextStatus,
                  awaitingResult: duel.hasFinished
                }
              }
            };
          });

          await get().maybeFinalizeDuel(duelId);
        });
      };

      const onPresence = ({ opponentOnline }) => {
        queueDuelEvent(duelId, async () => {
          set((state) => {
            const duels = patchDuel(state, duelId, { opponentOnline });
            return duels ? { duels } : {};
          });
        });
      };

      const onStatusChange = (status) => {
        queueDuelEvent(duelId, async () => {
          set((state) => {
            const duels = patchDuel(state, duelId, {
              realtimeStatus: String(status ?? 'unknown')
            });
            return duels ? { duels } : {};
          });
        });
      };

      const onState = (payloadState) => {
        queueDuelEvent(duelId, async () => {
          if (!payloadState || typeof payloadState !== 'object') return;
          const nextPatch = {};

          if (typeof payloadState.status === 'string') {
            nextPatch.status = payloadState.status;
          }
          if (Number.isFinite(payloadState.countdown)) {
            nextPatch.countdown = payloadState.countdown;
          }
          if (Number.isFinite(payloadState.currentIndex)) {
            nextPatch.opponentProgress = Math.max(
              0,
              Number(payloadState.currentIndex) + 1
            );
          }
          if (Number.isFinite(payloadState.score)) {
            nextPatch.opponentScore = Number(payloadState.score);
          }

          const startAtServerMs = toNumber(payloadState.startAtServerMs);
          if (startAtServerMs != null) {
            nextPatch.countdownStartAtServerMs = startAtServerMs;
            nextPatch.status = 'countdown';
          }

          if (!Object.keys(nextPatch).length) return;

          set((state) => {
            const duels = patchDuel(state, duelId, nextPatch);
            return duels ? { duels } : {};
          });

          if (startAtServerMs != null) {
            await get().beginSynchronizedCountdown(duelId, startAtServerMs);
          }
        });
      };

      clearQueuedDuelEvents(duelId);
      const existingDuel = get().duels[duelId];
      existingDuel?.unsubscribe?.();

      const realtime = realtimeService.joinDuel(
        duelId,
        {
          onState,
          onPlayerReady,
          onAnswerSubmitted,
          onPlayerFinished,
          onPresence,
          onStatusChange
        },
        {
          channelName,
          myUserId,
          opponentUserId: remoteOpponentId
        }
      );

      const questions = payload?.questions ?? existingDuel?.questions ?? [];
      const hasQuestions = questions.length > 0;

      set((state) => {
        const duel = state.duels[duelId];
        if (!duel) return {};
        return {
          duels: {
            ...state.duels,
            [duelId]: {
              ...duel,
              status:
                duel.status === 'playing' || duel.status === 'countdown'
                  ? duel.status
                  : 'lobby',
              opponent: pending?.opponentName ?? duel.opponent ?? '等待对手',
              channelName,
              challengerId,
              opponentId,
              myUserId,
              questions,
              totalQuestions: questions.length,
              currentIndex: duel.currentIndex ?? 0,
              currentQuestion:
                duel.currentQuestion ?? (hasQuestions ? questions[0] : null),
              error: hasQuestions ? null : '题目尚未准备完成',
              send: realtime.send,
              sendReady: realtime.sendReady,
              sendAnswerSubmitted: realtime.sendAnswerSubmitted,
              sendFinished: realtime.sendFinished,
              unsubscribe: realtime.unsubscribe,
              submit: (option) => get().submitDuelAnswer(duelId, option)
            }
          }
        };
      });

      return get().duels[duelId] ?? null;
    },

    async beginSynchronizedCountdown(duelId, explicitStartAtServerMs = null) {
      if (!duelId) return null;

      const duel = get().duels[duelId];
      if (!duel) return null;
      if (duel.status === 'playing' || duel.status === 'completed') {
        return duel.countdownStartAtServerMs ?? null;
      }
      if (!duel.questions?.length) return null;

      let startAtServerMs = toNumber(explicitStartAtServerMs);
      if (startAtServerMs == null) {
        startAtServerMs = toNumber(duel.countdownStartAtServerMs);
      }

      if (startAtServerMs == null) {
        const iAmCountdownHost = isSameId(duel.myUserId, duel.challengerId);
        if (!iAmCountdownHost) {
          return null;
        }
        const offsetMs = await get().syncServerTimeOffset();
        startAtServerMs =
          getEstimatedServerNow(offsetMs) + DUEL_COUNTDOWN_SECONDS * 1000 + 450;
        duel.send?.({
          status: 'countdown',
          startAtServerMs
        });
      }

      get().startDuelCountdown(duelId, startAtServerMs);
      return startAtServerMs;
    },

    startDuelCountdown(duelId, startAtServerMs = null) {
      if (!duelId) return;
      const duel = get().duels[duelId];
      if (!duel) return;
      if (!duel.questions?.length) return;
      if (duel.status === 'playing' || duel.status === 'completed') return;
      if (hasDuelCountdown(duelId) && duel.status === 'countdown') return;

      const countdownStartAt =
        toNumber(startAtServerMs) ?? toNumber(duel.countdownStartAtServerMs);
      if (countdownStartAt == null) return;
      const offsetMs = Number(get().serverTimeOffsetMs ?? 0);

      clearDuelCountdown(duelId);
      set((state) => {
        const duels = patchDuel(state, duelId, {
          status: 'countdown',
          countdownStartAtServerMs: countdownStartAt,
          countdown: computeCountdownSeconds(countdownStartAt, offsetMs),
          error: null
        });
        return duels ? { duels } : {};
      });

      const initialState = get().duels[duelId];
      if (!initialState || (initialState.countdown ?? 0) <= 0) {
        set((state) => {
          const duelState = state.duels[duelId];
          if (!duelState) return {};
          return {
            duels: {
              ...state.duels,
              [duelId]: {
                ...duelState,
                status: 'playing',
                countdown: 0,
                currentQuestion:
                  duelState.currentQuestion ?? duelState.questions?.[0] ?? null
              }
            }
          };
        });
        return;
      }

      const timer = setInterval(() => {
        const latest = get().duels[duelId];
        if (!latest) {
          clearDuelCountdown(duelId);
          return;
        }

        const startAt = toNumber(
          latest.countdownStartAtServerMs ?? countdownStartAt
        );
        if (startAt == null) {
          clearDuelCountdown(duelId);
          return;
        }

        const latestOffset = Number(get().serverTimeOffsetMs ?? 0);
        const remainingSeconds = computeCountdownSeconds(startAt, latestOffset);

        if (remainingSeconds <= 0) {
          clearDuelCountdown(duelId);
          set((state) => {
            const duelState = state.duels[duelId];
            if (!duelState) return {};
            return {
              duels: {
                ...state.duels,
                [duelId]: {
                  ...duelState,
                  status: 'playing',
                  countdown: 0,
                  currentQuestion:
                    duelState.currentQuestion ??
                    duelState.questions?.[0] ??
                    null
                }
              }
            };
          });
          return;
        }

        if (remainingSeconds !== latest.countdown) {
          set((state) => {
            const duelState = state.duels[duelId];
            if (!duelState) return {};
            return {
              duels: {
                ...state.duels,
                [duelId]: {
                  ...duelState,
                  countdown: remainingSeconds
                }
              }
            };
          });
        }
      }, 250);

      registerDuelCountdown(duelId, timer);
    },

    async startDuel(duelId) {
      if (!duelId) return;
      let duel = get().duels[duelId];

      if (!duel) {
        duel = await get().ensureDuel(duelId);
      }
      if (!duel) return;

      if (!duel.questions?.length) {
        await get().ensureDuel(duelId);
        duel = get().duels[duelId];
      }

      if (!duel) return;
      if (duel.status === 'playing' || duel.status === 'completed') return;
      if (!duel.myReady) {
        duel.sendReady?.();
        set((state) => {
          const current = state.duels[duelId];
          if (!current) return {};
          const bothReady = current.opponentReady;
          return {
            duels: {
              ...state.duels,
              [duelId]: {
                ...current,
                myReady: true,
                bothReady,
                status:
                  current.status === 'countdown' || current.status === 'playing'
                    ? current.status
                    : 'lobby',
                error: null
              }
            }
          };
        });
        const latest = get().duels[duelId];
        if (latest?.bothReady) {
          await get().beginSynchronizedCountdown(duelId);
        }
        return;
      }

      if (duel.myReady && duel.opponentReady) {
        await get().beginSynchronizedCountdown(duelId);
      }
    },

    async submitDuelAnswer(duelId, option) {
      const duel = get().duels[duelId];
      if (!duel?.currentQuestion) return;
      if (duel.status !== 'playing' || duel.submitting) return;

      set((state) => {
        const duels = patchDuel(state, duelId, {
          submitting: true,
          error: null
        });
        return duels ? { duels } : {};
      });

      try {
        const result = await arenaService.submitDuelAnswer({
          challengeId: duelId,
          questionIndex: duel.currentIndex ?? 0,
          selectedCategory: option,
          answerTimeMs: 0
        });

        const correct = Boolean(result?.is_correct);
        const nextIndex = (duel.currentIndex ?? 0) + 1;
        const nextQuestion = duel.questions?.[nextIndex] ?? null;
        const nextScore = correct ? duel.score + 20 : duel.score;
        const nextCorrectCount = correct
          ? duel.correctCount + 1
          : duel.correctCount;
        const finished = !nextQuestion;

        set((state) => {
          const current = state.duels[duelId];
          if (!current) return {};
          return {
            duels: {
              ...state.duels,
              [duelId]: {
                ...current,
                submitting: false,
                currentQuestion: nextQuestion,
                currentIndex: nextIndex,
                score: nextScore,
                correctCount: nextCorrectCount,
                hasFinished: finished,
                status: finished
                  ? current.opponentFinished
                    ? 'finalizing'
                    : 'waiting-result'
                  : 'playing',
                awaitingResult: finished,
                opponentProgress: current.opponentProgress,
                error: null
              }
            }
          };
        });

        const latest = get().duels[duelId];
        latest?.sendAnswerSubmitted?.({
          questionIndex: duel.currentIndex ?? 0,
          isCorrect: correct
        });
        latest?.send?.({
          currentIndex: nextIndex,
          score: nextScore,
          status: finished ? 'waiting-result' : 'playing'
        });

        if (finished) {
          latest?.sendFinished?.({
            totalCorrect: nextCorrectCount,
            totalScore: nextScore
          });
          get().maybeFinalizeDuel(duelId);
        }

        if (correct) {
          notifyAchievement({ type: 'arena', mode: 'duel', correct: true });
        }
      } catch (error) {
        console.warn('[arenaStore] submit duel answer failed', error);
        set((state) => {
          const duels = patchDuel(state, duelId, {
            submitting: false,
            error: error?.message ?? '提交答案失败'
          });
          return duels ? { duels } : {};
        });
      }
    },

    async maybeFinalizeDuel(duelId) {
      const duel = get().duels[duelId];
      if (!duel) return;
      if (!duel.hasFinished || !duel.opponentFinished) return;
      if (duel.finalizing || duel.status === 'completed') return;

      set((state) => {
        const duels = patchDuel(state, duelId, {
          finalizing: true,
          awaitingResult: false,
          status: 'finalizing',
          error: null
        });
        return duels ? { duels } : {};
      });

      let hardErrors = 0;
      for (
        let attempt = 0;
        attempt < DUEL_COMPLETE_MAX_ATTEMPTS;
        attempt += 1
      ) {
        try {
          const result = await arenaService.completeDuel(duelId);
          if (result) {
            set((state) => {
              const duels = patchDuel(state, duelId, {
                finalizing: false,
                awaitingResult: false,
                status: 'completed',
                result,
                error: null
              });
              return duels ? { duels } : {};
            });
            return;
          }
        } catch (error) {
          hardErrors += 1;
          console.warn('[arenaStore] finalize duel failed', error);
          if (hardErrors >= 3) break;
        }
        await sleep(DUEL_COMPLETE_RETRY_MS);
      }

      set((state) => {
        const duels = patchDuel(state, duelId, {
          finalizing: false,
          awaitingResult: true,
          status: 'waiting-result',
          error: '等待对手完成结算，稍后会自动同步结果。'
        });
        return duels ? { duels } : {};
      });
    },

    disposeDuel(duelId) {
      if (!duelId) return;
      clearDuelCountdown(duelId);
      clearQueuedDuelEvents(duelId);
      const duel = get().duels[duelId];
      try {
        duel?.unsubscribe?.();
      } catch (_) {
        // Swallow cleanup errors to ensure state is always cleared
      }
      set((state) => {
        const duels = { ...state.duels };
        delete duels[duelId];
        return { duels };
      });
    }
  };
};
