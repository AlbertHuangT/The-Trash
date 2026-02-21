import { create } from 'zustand';

import { achievementService } from 'src/services/achievement';

const initialStats = {
  scans: 0,
  classicWins: 0,
  speedScore: 0,
  streakBest: 0,
  dailyCompleted: 0,
  duelWins: 0
};

const updateStatsForTrigger = (stats, trigger) => {
  const next = { ...stats };
  if (trigger?.type === 'scan') {
    next.scans += 1;
  }
  if (trigger?.type === 'arena') {
    if (trigger.mode === 'classic' && trigger.correct) {
      next.classicWins += 1;
    }
    if (trigger.mode === 'speed' && typeof trigger.score === 'number') {
      next.speedScore = Math.max(next.speedScore, trigger.score);
    }
    if (trigger.mode === 'streak' && typeof trigger.streak === 'number') {
      next.streakBest = Math.max(next.streakBest, trigger.streak);
    }
    if (trigger.mode === 'daily' && trigger.completed) {
      next.dailyCompleted += 1;
    }
    if (trigger.mode === 'duel' && trigger.correct) {
      next.duelWins += 1;
    }
  }
  return next;
};

export const useAchievementStore = create((set, get) => ({
  badges: [],
  rewards: [],
  loading: false,
  points: 0,
  stats: { ...initialStats },
  toastQueue: [],
  history: [],
  equippedBadgeId: null,

  async load() {
    set({ loading: true });
    const [badgesResult, rewardsResult] = await Promise.allSettled([
      achievementService.fetchBadges(),
      achievementService.fetchRewards()
    ]);

    if (badgesResult.status === 'rejected') {
      console.warn(
        '[achievementStore] badges load failed',
        badgesResult.reason
      );
    }
    if (rewardsResult.status === 'rejected') {
      console.warn(
        '[achievementStore] rewards load failed',
        rewardsResult.reason
      );
    }

    const badges =
      badgesResult.status === 'fulfilled' ? badgesResult.value : [];
    const rewards =
      rewardsResult.status === 'fulfilled' ? rewardsResult.value : [];
    const equipped = badges.find((badge) => badge.equipped)?.id ?? null;
    const points = badges.filter((badge) => badge.unlocked).length * 25;
    set({ badges, rewards, equippedBadgeId: equipped, points, loading: false });
  },

  async redeem(rewardId) {
    const reward = get().rewards.find((item) => item.id === rewardId);
    if (!reward || reward.redeemed) return;
    try {
      await achievementService.redeemReward(rewardId);
    } catch (error) {
      console.warn('[achievementStore] redeem failed', error);
      return;
    }
    set((state) => ({
      rewards: state.rewards.map((item) =>
        item.id === rewardId ? { ...item, redeemed: true } : item
      ),
      points: Math.max(0, state.points - reward.points),
      history: [
        {
          id: `reward-${rewardId}-${Date.now()}`,
          title: `兑换 ${reward.title}`,
          timestamp: new Date().toISOString(),
          kind: 'reward'
        },
        ...state.history
      ].slice(0, 20)
    }));
  },

  async checkAndGrant(trigger) {
    const nextStats = updateStatsForTrigger(get().stats, trigger);
    set({ stats: nextStats });
    try {
      const { unlocked, points } = await achievementService.checkAndGrant({
        trigger,
        stats: nextStats
      });
      if (!unlocked?.length && !points) {
        return;
      }
      const timestamp = new Date().toISOString();
      set((state) => {
        const previouslyUnlocked = new Set(
          state.badges
            .filter((badge) => badge.unlocked)
            .map((badge) => badge.id)
        );
        const mergedBadges = state.badges.map((badge) =>
          unlocked?.some((item) => item.id === badge.id)
            ? { ...badge, unlocked: true }
            : badge
        );
        const appendedBadges = (unlocked ?? [])
          .filter(
            (badge) =>
              !state.badges.some((existing) => existing.id === badge.id)
          )
          .map((badge) => ({ ...badge, unlocked: true }));
        const badges = [...mergedBadges, ...appendedBadges];
        const newToasts = (unlocked ?? [])
          .filter((badge) => !previouslyUnlocked.has(badge.id))
          .map((badge) => ({
            id: badge.id,
            title: badge.title,
            description: badge.description,
            icon: badge.icon ?? '✨'
          }));
        const newHistory = [
          ...newToasts.map((toast) => ({
            id: `badge-${toast.id}-${timestamp}`,
            title: toast.title,
            description: toast.description,
            timestamp,
            kind: 'badge'
          })),
          ...state.history
        ].slice(0, 20);
        return {
          badges,
          points: state.points + (points ?? 0),
          toastQueue: [...state.toastQueue, ...newToasts],
          history: newHistory
        };
      });
    } catch (error) {
      console.warn('[achievementStore] checkAndGrant failed', error);
    }
  },

  consumeToast() {
    set((state) => ({ toastQueue: state.toastQueue.slice(1) }));
  },

  equipBadge(id) {
    const badge = get().badges.find((item) => item.id === id);
    if (!badge?.unlocked) return;
    set({ equippedBadgeId: id });
  }
}));
