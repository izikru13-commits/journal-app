// Zikkit — fill-in-the-blank sentence bank. Powers: השלמת משפט (skill:"vocab"),
// דיוק דקדוקי (skill:"grammar"), and סדר את המשפט (derives the full sentence via
// template.replace("___", answer)). Each template has exactly one "___"; answer appears
// in options exactly once; options have no duplicates.
const SENTENCE_BANK = [
  // beginner vocab
  { id: "s-b-v1", template: "I drink ___ every morning.", answer: "coffee", options: ["coffee", "chair", "mountain", "bicycle"], translation: "אני שותה קפה כל בוקר.", skill: "vocab", difficulty: "beginner" },
  { id: "s-b-v2", template: "The sun is very ___ today.", answer: "hot", options: ["hot", "blue", "fast", "tall"], translation: "השמש חמה מאוד היום.", skill: "vocab", difficulty: "beginner" },
  { id: "s-b-v3", template: "She has a pet ___.", answer: "dog", options: ["dog", "book", "table", "cloud"], translation: "יש לה כלב מחמד.", skill: "vocab", difficulty: "beginner" },
  { id: "s-b-v4", template: "He is reading a ___.", answer: "book", options: ["book", "spoon", "river", "shoe"], translation: "הוא קורא ספר.", skill: "vocab", difficulty: "beginner" },
  { id: "s-b-v5", template: "We eat dinner in the ___.", answer: "kitchen", options: ["kitchen", "sky", "ocean", "forest"], translation: "אנחנו אוכלים ארוחת ערב במטבח.", skill: "vocab", difficulty: "beginner" },
  { id: "s-b-v6", template: "The baby is ___.", answer: "sleeping", options: ["sleeping", "flying", "cooking", "driving"], translation: "התינוק ישן.", skill: "vocab", difficulty: "beginner" },
  { id: "s-b-v7", template: "I wash my hands with ___.", answer: "soap", options: ["soap", "sand", "paper", "glass"], translation: "אני שוטף ידיים עם סבון.", skill: "vocab", difficulty: "beginner" },
  { id: "s-b-v8", template: "The little girl is wearing a red ___.", answer: "dress", options: ["dress", "engine", "theory", "budget"], translation: "הילדה הקטנה לובשת שמלה אדומה.", skill: "vocab", difficulty: "beginner" },

  // beginner grammar
  { id: "s-b-g1", template: "She ___ to school every day.", answer: "goes", options: ["goes", "go", "going", "gone"], translation: "היא הולכת לבית הספר כל יום.", skill: "grammar", difficulty: "beginner" },
  { id: "s-b-g2", template: "There ___ two cats in the garden.", answer: "are", options: ["are", "is", "am", "be"], translation: "יש שני חתולים בגינה.", skill: "grammar", difficulty: "beginner" },
  { id: "s-b-g3", template: "I ___ a student.", answer: "am", options: ["am", "is", "are", "be"], translation: "אני תלמיד.", skill: "grammar", difficulty: "beginner" },
  { id: "s-b-g4", template: "He ___ his homework yesterday.", answer: "did", options: ["did", "do", "does", "doing"], translation: "הוא עשה שיעורי בית אתמול.", skill: "grammar", difficulty: "beginner" },
  { id: "s-b-g5", template: "This is ___ apple.", answer: "an", options: ["an", "a", "the", "some"], translation: "זה תפוח.", skill: "grammar", difficulty: "beginner" },
  { id: "s-b-g6", template: "They ___ playing football now.", answer: "are", options: ["are", "is", "am", "was"], translation: "הם משחקים כדורגל עכשיו.", skill: "grammar", difficulty: "beginner" },
  { id: "s-b-g7", template: "My mother ___ a nurse.", answer: "is", options: ["is", "are", "am", "be"], translation: "אמא שלי אחות.", skill: "grammar", difficulty: "beginner" },
  { id: "s-b-g8", template: "We ___ to the beach last week.", answer: "went", options: ["went", "go", "goes", "going"], translation: "הלכנו לחוף הים בשבוע שעבר.", skill: "grammar", difficulty: "beginner" },

  // intermediate vocab
  { id: "s-i-v1", template: "The detective found an important ___ at the scene.", answer: "clue", options: ["clue", "ladder", "carpet", "engine"], translation: "הבלש מצא רמז חשוב בזירה.", skill: "vocab", difficulty: "intermediate" },
  { id: "s-i-v2", template: "Please ___ the window, it's cold.", answer: "close", options: ["close", "paint", "sell", "borrow"], translation: "בבקשה תסגור את החלון, קר.", skill: "vocab", difficulty: "intermediate" },
  { id: "s-i-v3", template: "Her speech was so ___ that everyone applauded.", answer: "inspiring", options: ["inspiring", "boring", "silent", "heavy"], translation: "הנאום שלה היה כל כך מעורר השראה שכולם מחאו כפיים.", skill: "vocab", difficulty: "intermediate" },
  { id: "s-i-v4", template: "He tends to ___ his problems instead of facing them.", answer: "avoid", options: ["avoid", "celebrate", "measure", "repair"], translation: "הוא נוטה להימנע מהבעיות שלו במקום להתמודד איתן.", skill: "vocab", difficulty: "intermediate" },
  { id: "s-i-v5", template: "The company decided to ___ the project.", answer: "cancel", options: ["cancel", "swim", "whisper", "freeze"], translation: "החברה החליטה לבטל את הפרויקט.", skill: "vocab", difficulty: "intermediate" },
  { id: "s-i-v6", template: "It's important to ___ enough water every day.", answer: "drink", options: ["drink", "fold", "borrow", "paint"], translation: "חשוב לשתות מספיק מים כל יום.", skill: "vocab", difficulty: "intermediate" },
  { id: "s-i-v7", template: "The teacher will ___ the exam results tomorrow.", answer: "announce", options: ["announce", "whisper", "bury", "fold"], translation: "המורה יודיע על תוצאות המבחן מחר.", skill: "vocab", difficulty: "intermediate" },
  { id: "s-i-v8", template: "She managed to ___ her fear of heights.", answer: "overcome", options: ["overcome", "borrow", "paint", "fold"], translation: "היא הצליחה להתגבר על הפחד שלה מגבהים.", skill: "vocab", difficulty: "intermediate" },

  // intermediate grammar
  { id: "s-i-g1", template: "If it rains, we ___ stay home.", answer: "will", options: ["will", "would", "are", "did"], translation: "אם ירד גשם, נישאר בבית.", skill: "grammar", difficulty: "intermediate" },
  { id: "s-i-g2", template: "She has ___ finished her homework.", answer: "already", options: ["already", "yesterday", "tomorrow", "soon ago"], translation: "היא כבר סיימה את שיעורי הבית.", skill: "grammar", difficulty: "intermediate" },
  { id: "s-i-g3", template: "By next year, I ___ graduated.", answer: "will have", options: ["will have", "have", "had", "having"], translation: "עד השנה הבאה אני אסיים תואר.", skill: "grammar", difficulty: "intermediate" },
  { id: "s-i-g4", template: "He is interested ___ learning Spanish.", answer: "in", options: ["in", "at", "on", "for"], translation: "הוא מתעניין בלימוד ספרדית.", skill: "grammar", difficulty: "intermediate" },
  { id: "s-i-g5", template: "This book is ___ than that one.", answer: "more interesting", options: ["more interesting", "interesting", "interestinger", "most interesting"], translation: "הספר הזה מעניין יותר מההוא.", skill: "grammar", difficulty: "intermediate" },
  { id: "s-i-g6", template: "They ___ been living here since 2010.", answer: "have", options: ["have", "has", "had", "having"], translation: "הם גרים כאן מאז 2010.", skill: "grammar", difficulty: "intermediate" },
  { id: "s-i-g7", template: "You should apologize ___ her.", answer: "to", options: ["to", "for", "with", "at"], translation: "אתה צריך להתנצל בפניה.", skill: "grammar", difficulty: "intermediate" },
  { id: "s-i-g8", template: "I wish I ___ more time.", answer: "had", options: ["had", "have", "has", "having"], translation: "הלוואי והיה לי יותר זמן.", skill: "grammar", difficulty: "intermediate" },

  // advanced vocab
  { id: "s-a-v1", template: "The negotiations reached a sudden ___.", answer: "impasse", options: ["impasse", "picnic", "melody", "fabric"], translation: "המשא ומתן הגיע למבוי סתום.", skill: "vocab", difficulty: "advanced" },
  { id: "s-a-v2", template: "His argument was completely ___ and lacked evidence.", answer: "baseless", options: ["baseless", "delicious", "fragrant", "cozy"], translation: "הטיעון שלו היה חסר בסיס לחלוטין.", skill: "vocab", difficulty: "advanced" },
  { id: "s-a-v3", template: "The committee will ___ the proposal next week.", answer: "deliberate", options: ["deliberate", "decorate", "whistle", "sprinkle"], translation: "הוועדה תדון בהצעה בשבוע הבא.", skill: "vocab", difficulty: "advanced" },
  { id: "s-a-v4", template: "Her ___ remarks offended several guests.", answer: "tactless", options: ["tactless", "cheerful", "fragrant", "spacious"], translation: "ההערות חסרות הטקט שלה פגעו במספר אורחים.", skill: "vocab", difficulty: "advanced" },
  { id: "s-a-v5", template: "The evidence was entirely ___.", answer: "circumstantial", options: ["circumstantial", "edible", "musical", "tropical"], translation: "הראיות היו נסיבתיות בלבד.", skill: "vocab", difficulty: "advanced" },
  { id: "s-a-v6", template: "It is difficult to ___ such a complex issue in one sentence.", answer: "summarize", options: ["summarize", "decorate", "whistle", "harvest"], translation: "קשה לסכם נושא כה מורכב במשפט אחד.", skill: "vocab", difficulty: "advanced" },
  { id: "s-a-v7", template: "The scientist's theory was later ___ by new data.", answer: "refuted", options: ["refuted", "decorated", "harvested", "whispered"], translation: "התיאוריה של המדען נסתרה מאוחר יותר על ידי נתונים חדשים.", skill: "vocab", difficulty: "advanced" },
  { id: "s-a-v8", template: "His speech was full of ___ that confused the audience.", answer: "jargon", options: ["jargon", "melody", "fabric", "picnic"], translation: "הנאום שלו היה מלא בז'רגון שבלבל את הקהל.", skill: "vocab", difficulty: "advanced" },

  // advanced grammar
  { id: "s-a-g1", template: "Had I known earlier, I ___ differently.", answer: "would have acted", options: ["would have acted", "will act", "act", "acted"], translation: "אילו ידעתי מוקדם יותר, הייתי פועל אחרת.", skill: "grammar", difficulty: "advanced" },
  { id: "s-a-g2", template: "Rarely ___ such dedication.", answer: "have I seen", options: ["have I seen", "I have seen", "I saw", "did I saw"], translation: "לעיתים רחוקות ראיתי מסירות כזו.", skill: "grammar", difficulty: "advanced" },
  { id: "s-a-g3", template: "Not only ___ late, but he also forgot the documents.", answer: "was he", options: ["was he", "he was", "he is", "is he"], translation: "הוא לא רק איחר, אלא גם שכח את המסמכים.", skill: "grammar", difficulty: "advanced" },
  { id: "s-a-g4", template: "The report, ___ was published yesterday, raised concerns.", answer: "which", options: ["which", "who", "whom", "whose"], translation: "הדוח, שפורסם אתמול, עורר חששות.", skill: "grammar", difficulty: "advanced" },
  { id: "s-a-g5", template: "She insisted that he ___ present at the meeting.", answer: "be", options: ["be", "is", "was", "being"], translation: "היא התעקשה שהוא יהיה נוכח בפגישה.", skill: "grammar", difficulty: "advanced" },
  { id: "s-a-g6", template: "No sooner ___ than it started to rain.", answer: "had we left", options: ["had we left", "we had left", "we left", "did we left"], translation: "בקושי יצאנו כשהתחיל לרדת גשם.", skill: "grammar", difficulty: "advanced" },
  { id: "s-a-g7", template: "It is essential that every employee ___ the new policy.", answer: "follow", options: ["follow", "follows", "followed", "following"], translation: "חיוני שכל עובד יעקוב אחר המדיניות החדשה.", skill: "grammar", difficulty: "advanced" },
  { id: "s-a-g8", template: "Were I in your position, I ___ accept the offer.", answer: "would", options: ["would", "will", "am", "was"], translation: "אילו הייתי במקומך, הייתי מקבל את ההצעה.", skill: "grammar", difficulty: "advanced" },
];
