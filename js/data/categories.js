// Zikkit — category/grouping word sets. Used by quartets (רביעיות, group all 4) and
// odd-one-out (הזר בחבורה, category words + one intruder from a different category).
// Each category's 4 words are unique within it; no word is reused across categories in the same band.
const CATEGORY_LIST = [
  // beginner
  { id: "animals", label: "בעלי חיים", difficulty: "beginner", words: ["DOG", "CAT", "LION", "BIRD"] },
  { id: "colors", label: "צבעים", difficulty: "beginner", words: ["RED", "BLUE", "GREEN", "BLACK"] },
  { id: "food", label: "אוכל", difficulty: "beginner", words: ["BREAD", "APPLE", "RICE", "MILK"] },
  { id: "family", label: "משפחה", difficulty: "beginner", words: ["MOTHER", "FATHER", "SISTER", "BROTHER"] },
  { id: "numbers", label: "מספרים", difficulty: "beginner", words: ["ONE", "TWO", "THREE", "FOUR"] },
  { id: "body", label: "חלקי גוף", difficulty: "beginner", words: ["HAND", "LEG", "EYE", "EAR"] },
  { id: "weather", label: "מזג אוויר", difficulty: "beginner", words: ["RAIN", "SNOW", "WIND", "SUN"] },
  { id: "school", label: "בית ספר", difficulty: "beginner", words: ["BOOK", "PEN", "DESK", "CHAIR"] },

  // intermediate
  { id: "emotions", label: "רגשות", difficulty: "intermediate", words: ["HAPPY", "ANGRY", "AFRAID", "PROUD"] },
  { id: "professions", label: "מקצועות", difficulty: "intermediate", words: ["DOCTOR", "TEACHER", "LAWYER", "FARMER"] },
  { id: "transport", label: "תחבורה", difficulty: "intermediate", words: ["CAR", "TRAIN", "PLANE", "SHIP"] },
  { id: "sports", label: "ספורט", difficulty: "intermediate", words: ["SOCCER", "TENNIS", "BOXING", "GOLF"] },
  { id: "furniture", label: "רהיטים", difficulty: "intermediate", words: ["TABLE", "SOFA", "SHELF", "LAMP"] },
  { id: "kitchen", label: "כלי מטבח", difficulty: "intermediate", words: ["FORK", "KNIFE", "SPOON", "PLATE"] },
  { id: "clothing", label: "ביגוד", difficulty: "intermediate", words: ["SHIRT", "PANTS", "SHOES", "HAT"] },
  { id: "nature", label: "טבע", difficulty: "intermediate", words: ["RIVER", "MOUNTAIN", "FOREST", "DESERT"] },

  // advanced
  { id: "emotions_adv", label: "רגשות מורכבים", difficulty: "advanced", words: ["ANXIOUS", "JEALOUS", "GRATEFUL", "ASHAMED"] },
  { id: "abstract", label: "מושגים מופשטים", difficulty: "advanced", words: ["JUSTICE", "FREEDOM", "WISDOM", "COURAGE"] },
  { id: "science", label: "מדע", difficulty: "advanced", words: ["GRAVITY", "MOLECULE", "ENERGY", "ORBIT"] },
  { id: "business", label: "עסקים", difficulty: "advanced", words: ["BUDGET", "INVESTMENT", "REVENUE", "CONTRACT"] },
  { id: "politics", label: "פוליטיקה", difficulty: "advanced", words: ["DEMOCRACY", "ELECTION", "SENATE", "POLICY"] },
  { id: "literature", label: "ספרות", difficulty: "advanced", words: ["METAPHOR", "NARRATIVE", "IRONY", "DIALOGUE"] },
  { id: "law", label: "משפטים", difficulty: "advanced", words: ["VERDICT", "LAWSUIT", "EVIDENCE", "TESTIMONY"] },
  { id: "psychology", label: "פסיכולוגיה", difficulty: "advanced", words: ["COGNITION", "PERCEPTION", "MOTIVATION", "BEHAVIOR"] },
];
