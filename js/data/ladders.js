// Zikkit — word ladder puzzles (hand-authored, not dictionary-validated). Each consecutive pair
// in `chain` has equal length and differs by exactly one letter. Used by סולם מילים: a few middle
// rungs are blanked out and the player picks the correct rung from a multiple-choice bank.
const WORD_LADDERS = [
  // beginner
  { id: "l-b-1", chain: ["CAT", "COT", "COG", "DOG"], difficulty: "beginner" },
  { id: "l-b-2", chain: ["HOT", "HOP", "HIP", "HIT"], difficulty: "beginner" },
  { id: "l-b-3", chain: ["PIG", "BIG", "BAG", "BAT"], difficulty: "beginner" },
  { id: "l-b-4", chain: ["COLD", "CORD", "WORD", "WARD", "WARM"], difficulty: "beginner" },
  { id: "l-b-5", chain: ["CAKE", "LAKE", "LACE", "RACE"], difficulty: "beginner" },

  // intermediate
  { id: "l-i-1", chain: ["HEAD", "HEAT", "HEAR", "HEAL", "SEAL"], difficulty: "intermediate" },
  { id: "l-i-2", chain: ["BLACK", "BLANK", "PLANK", "PLANT"], difficulty: "intermediate" },
  { id: "l-i-3", chain: ["STONE", "STORE", "SCORE", "SCARE"], difficulty: "intermediate" },
  { id: "l-i-4", chain: ["FLOUR", "FLOOR", "FLOOD", "BLOOD"], difficulty: "intermediate" },
  { id: "l-i-5", chain: ["SHARE", "SHORE", "SCORE", "SCARE"], difficulty: "intermediate" },

  // advanced
  { id: "l-a-1", chain: ["LOVE", "LIVE", "LIME", "TIME", "TIDE", "SIDE"], difficulty: "advanced" },
  { id: "l-a-2", chain: ["COLD", "BOLD", "BOLT", "BELT", "BELL"], difficulty: "advanced" },
  { id: "l-a-3", chain: ["FIRE", "FIRM", "FORM", "FORT", "SORT", "SORE"], difficulty: "advanced" },
  { id: "l-a-4", chain: ["SPACE", "SPICE", "SLICE", "SLIME"], difficulty: "advanced" },
  { id: "l-a-5", chain: ["GRAPE", "GRADE", "TRADE", "TRACE"], difficulty: "advanced" },
];
