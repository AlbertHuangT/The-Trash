import { create } from 'zustand';

import { createDuelArenaSlice } from './arena/duelSlice';
import { createSoloArenaSlice } from './arena/soloSlice';

export const useArenaStore = create((set, get) => ({
  ...createSoloArenaSlice(set, get),
  ...createDuelArenaSlice(set, get)
}));
