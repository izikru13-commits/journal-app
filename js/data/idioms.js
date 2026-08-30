// Zikkit — common English idioms with one missing word. Used by השלמת ניבים; `meaning` (in
// Hebrew) is revealed only after the player answers.
const IDIOMS = [
  // beginner
  { id: "id-b-1", idiom: "It's raining cats and ___.", answer: "dogs", meaning: "יורד גשם חזק מאוד", difficulty: "beginner" },
  { id: "id-b-2", idiom: "Break a ___!", answer: "leg", meaning: "בהצלחה! (איחול לפני הופעה)", difficulty: "beginner" },
  { id: "id-b-3", idiom: "Piece of ___.", answer: "cake", meaning: "דבר קל מאוד לביצוע", difficulty: "beginner" },
  { id: "id-b-4", idiom: "Once in a blue ___.", answer: "moon", meaning: "לעיתים נדירות מאוד", difficulty: "beginner" },
  { id: "id-b-5", idiom: "The ball is in your ___.", answer: "court", meaning: "התור שלך להחליט או לפעול", difficulty: "beginner" },
  { id: "id-b-6", idiom: "Better late than ___.", answer: "never", meaning: "עדיף מאוחר מאשר בכלל לא", difficulty: "beginner" },
  { id: "id-b-7", idiom: "Time ___ all wounds.", answer: "heals", meaning: "הזמן מרפא הכל", difficulty: "beginner" },
  { id: "id-b-8", idiom: "Don't cry over spilled ___.", answer: "milk", meaning: "אל תצטער על מה שכבר קרה ולא ניתן לתקן", difficulty: "beginner" },
  { id: "id-b-9", idiom: "Actions speak louder than ___.", answer: "words", meaning: "מעשים חשובים יותר ממילים", difficulty: "beginner" },
  { id: "id-b-10", idiom: "Every cloud has a silver ___.", answer: "lining", meaning: "יש טוב בכל דבר רע", difficulty: "beginner" },
  { id: "id-b-11", idiom: "When it rains, it ___.", answer: "pours", meaning: "צרות באות בצרורות", difficulty: "beginner" },
  { id: "id-b-12", idiom: "The early bird catches the ___.", answer: "worm", meaning: "מי שמקדים זוכה", difficulty: "beginner" },
  { id: "id-b-13", idiom: "Look before you ___.", answer: "leap", meaning: "תחשוב לפני שתפעל", difficulty: "beginner" },
  { id: "id-b-14", idiom: "A picture is worth a thousand ___.", answer: "words", meaning: "תמונה שווה אלף מילים", difficulty: "beginner" },

  // intermediate
  { id: "id-i-1", idiom: "Bite the ___.", answer: "bullet", meaning: "להתמודד עם משהו קשה באומץ", difficulty: "intermediate" },
  { id: "id-i-2", idiom: "Hit the nail on the ___.", answer: "head", meaning: "לפגוע בול, לצדוק בדיוק", difficulty: "intermediate" },
  { id: "id-i-3", idiom: "Let the cat out of the ___.", answer: "bag", meaning: "לחשוף סוד", difficulty: "intermediate" },
  { id: "id-i-4", idiom: "Feeling under the ___.", answer: "weather", meaning: "לא מרגישים טוב", difficulty: "intermediate" },
  { id: "id-i-5", idiom: "Once bitten, twice ___.", answer: "shy", meaning: "מי שנכווה ברותחין נזהר בצוננין", difficulty: "intermediate" },
  { id: "id-i-6", idiom: "Kill two birds with one ___.", answer: "stone", meaning: "להשיג שתי מטרות במכה אחת", difficulty: "intermediate" },
  { id: "id-i-7", idiom: "That was the last straw that broke the camel's ___.", answer: "back", meaning: "הדבר האחרון שגרם להתפרצות", difficulty: "intermediate" },
  { id: "id-i-8", idiom: "Stop beating around the ___.", answer: "bush", meaning: "לדבר סחור סחור, לא ישירות", difficulty: "intermediate" },
  { id: "id-i-9", idiom: "This will cost an arm and a ___.", answer: "leg", meaning: "עולה הרבה מאוד כסף", difficulty: "intermediate" },
  { id: "id-i-10", idiom: "He got out of ___ on the wrong side today.", answer: "bed", meaning: "לקום עם הרגל השמאלית", difficulty: "intermediate" },
  { id: "id-i-11", idiom: "She had to burn the midnight ___.", answer: "oil", meaning: "לעבוד עד מאוחר בלילה", difficulty: "intermediate" },
  { id: "id-i-12", idiom: "Speak of the ___.", answer: "devil", meaning: "מדברים על החמור...", difficulty: "intermediate" },
  { id: "id-i-13", idiom: "Don't add insult to ___.", answer: "injury", meaning: "להוסיף חטא על פשע", difficulty: "intermediate" },

  // advanced
  { id: "id-a-1", idiom: "It was a blessing in ___.", answer: "disguise", meaning: "דבר שנראה רע אך מתגלה כטוב", difficulty: "advanced" },
  { id: "id-a-2", idiom: "Don't cut ___ on this project.", answer: "corners", meaning: "לוותר על איכות כדי לחסוך זמן או כסף", difficulty: "advanced" },
  { id: "id-a-3", idiom: "You're barking up the wrong ___.", answer: "tree", meaning: "לטעות לגמרי בכיוון", difficulty: "advanced" },
  { id: "id-a-4", idiom: "You need to read between the ___.", answer: "lines", meaning: "להבין את המשמעות הסמויה", difficulty: "advanced" },
  { id: "id-a-5", idiom: "Now he gets a taste of his own ___.", answer: "medicine", meaning: "לקבל יחס דומה למה שנתת לאחרים", difficulty: "advanced" },
  { id: "id-a-6", idiom: "No one mentioned the elephant in the ___.", answer: "room", meaning: "בעיה ברורה שאף אחד לא מדבר עליה", difficulty: "advanced" },
  { id: "id-a-7", idiom: "He decided to throw caution to the ___.", answer: "wind", meaning: "לפעול בפזיזות, בלי זהירות", difficulty: "advanced" },
  { id: "id-a-8", idiom: "He turned out to be a wolf in sheep's ___.", answer: "clothing", meaning: "אדם רע המתחזה לטוב", difficulty: "advanced" },
  { id: "id-a-9", idiom: "Everyone started to jump on the ___.", answer: "bandwagon", meaning: "להצטרף למגמה פופולרית", difficulty: "advanced" },
  { id: "id-a-10", idiom: "We'll cross that ___ when we come to it.", answer: "bridge", meaning: "להתמודד עם בעיה כשהיא תגיע", difficulty: "advanced" },
  { id: "id-a-11", idiom: "The manager decided to turn a blind ___.", answer: "eye", meaning: "להתעלם במכוון", difficulty: "advanced" },
  { id: "id-a-12", idiom: "Such phones are a dime a ___ nowadays.", answer: "dozen", meaning: "דבר נפוץ מאוד, חסר ערך מיוחד", difficulty: "advanced" },
  { id: "id-a-13", idiom: "She's been burning the ___ at both ends.", answer: "candle", meaning: "לעבוד או לפעול יותר מדי בלי מנוחה", difficulty: "advanced" },
];
