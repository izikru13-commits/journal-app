// Zikkit — hand-authored mini crossword puzzles (not runtime-generated). `solution` is a 2D
// grid of letters or `null` for unused cells. Every across/down answer must match the solution
// grid exactly (verified by a Node test, not just by eye). Used by תשחץ מיני.
const CROSSWORD_PUZZLES = [
  // beginner
  {
    id: "cw-b-1",
    difficulty: "beginner",
    size: { rows: 3, cols: 3 },
    solution: [
      ["C", "A", "T"],
      ["O", null, "E"],
      ["W", null, "N"],
    ],
    across: [{ number: 1, row: 0, col: 0, length: 3, clue: "חיה שאומרת מיאו", answer: "CAT" }],
    down: [
      { number: 1, row: 0, col: 0, length: 3, clue: "פרה", answer: "COW" },
      { number: 2, row: 0, col: 2, length: 3, clue: "המספר עשר", answer: "TEN" },
    ],
  },
  {
    id: "cw-b-2",
    difficulty: "beginner",
    size: { rows: 3, cols: 3 },
    solution: [
      ["S", "U", "N"],
      ["E", null, "E"],
      ["A", null, "T"],
    ],
    across: [{ number: 1, row: 0, col: 0, length: 3, clue: "מקור האור והחום ביום", answer: "SUN" }],
    down: [
      { number: 1, row: 0, col: 0, length: 3, clue: "מקווה מים גדול ומלוח", answer: "SEA" },
      { number: 2, row: 0, col: 2, length: 3, clue: "רשת (למשל לדיג)", answer: "NET" },
    ],
  },

  // intermediate
  {
    id: "cw-i-1",
    difficulty: "intermediate",
    size: { rows: 4, cols: 4 },
    solution: [
      ["S", "T", "A", "R"],
      ["T", null, null, "A"],
      ["O", null, null, "I"],
      ["P", null, null, "N"],
    ],
    across: [{ number: 1, row: 0, col: 0, length: 4, clue: "כוכב בשמיים", answer: "STAR" }],
    down: [
      { number: 1, row: 0, col: 0, length: 4, clue: "לעצור", answer: "STOP" },
      { number: 2, row: 0, col: 3, length: 4, clue: "גשם", answer: "RAIN" },
    ],
  },
  {
    id: "cw-i-2",
    difficulty: "intermediate",
    size: { rows: 4, cols: 4 },
    solution: [
      ["M", "O", "O", "N"],
      ["I", null, null, "I"],
      ["L", null, null, "N"],
      ["K", null, null, "E"],
    ],
    across: [{ number: 1, row: 0, col: 0, length: 4, clue: "גוף שמיים שרואים בלילה", answer: "MOON" }],
    down: [
      { number: 1, row: 0, col: 0, length: 4, clue: "משקה לבן מהפרה", answer: "MILK" },
      { number: 2, row: 0, col: 3, length: 4, clue: "המספר תשע", answer: "NINE" },
    ],
  },

  // advanced
  {
    id: "cw-a-1",
    difficulty: "advanced",
    size: { rows: 5, cols: 5 },
    solution: [
      ["T", "R", "U", "T", "H"],
      ["R", null, null, null, "O"],
      ["E", null, null, null, "N"],
      ["N", null, null, null, "O"],
      ["D", null, null, null, "R"],
    ],
    across: [{ number: 1, row: 0, col: 0, length: 5, clue: "אמת", answer: "TRUTH" }],
    down: [
      { number: 1, row: 0, col: 0, length: 5, clue: "מגמה", answer: "TREND" },
      { number: 2, row: 0, col: 4, length: 5, clue: "כבוד", answer: "HONOR" },
    ],
  },
  {
    id: "cw-a-2",
    difficulty: "advanced",
    size: { rows: 5, cols: 5 },
    solution: [
      ["B", "R", "A", "V", "E"],
      ["L", null, null, null, "A"],
      ["A", null, null, null, "G"],
      ["M", null, null, null, "E"],
      ["E", null, null, null, "R"],
    ],
    across: [{ number: 1, row: 0, col: 0, length: 5, clue: "אמיץ", answer: "BRAVE" }],
    down: [
      { number: 1, row: 0, col: 0, length: 5, clue: "להאשים", answer: "BLAME" },
      { number: 2, row: 0, col: 4, length: 5, clue: "להוט / נלהב", answer: "EAGER" },
    ],
  },
];
