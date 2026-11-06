---
name: "app-launch-audit"
description: "Pre-launch security, privacy, accessibility and copyright audit for a Web/PWA app (Supabase/Vercel). Use before going live, or for בדיקה לפני העלאה לאוויר."
---

# בדיקת אפליקציה לפני העלאה לאוויר

מטרה: לעבור על אפליקציית Web/PWA (בדרך כלל Supabase + Vercel) לפני השקה, ולמצוא בעיות באבטחה, בפרטיות, בנגישות ובזכויות יוצרים. התוצאה היא דוח בעברית שמתחיל במה שחוסם השקה.

## לפני שמתחילים

1. להשיג את הקוד. אם הוא לא נמצא בסשן, לבקש את ה-repo ב-GitHub (owner/repo) ולצרף אותו, או לבקש קובץ zip. אם אין קוד, לעבור על הרשימה כשאלות למשתמש ולסמן הכל "בדיקה ידנית".
2. לזהות את הסטאק: framework (Next.js / Vite / אחר), backend (Supabase / Firebase / אחר), אירוח (Vercel / Netlify / אחר), והאם יש Service Worker. אם הסטאק שונה, להתאים את הבדיקות לאותו עיקרון.
3. לשאול רק מה שלא ברור מהקוד: מה דומיין הייצור, האם יש משתמשים מאירופה, האם נאסף מידע רגיש (בריאות, קטינים, כסף), האם משתמשים מעלים תוכן, והאם העסק הוא עוסק פטור או מה המחזור שלו.
4. לפני שמציינים עובדה משפטית (תיקון 13, תקנות נגישות, פטורים), לוודא בחיפוש שהיא עדיין בתוקף.

דרגות חומרה: **קריטי** = חוסם השקה. **גבוה** = לתקן בשבוע הראשון. **בינוני** = שיפור.

## 1. בסיס נתונים והרשאות (Supabase)

להריץ ב-SQL Editor, או לבקש מהמשתמש להריץ ולהדביק את התוצאה:

```sql
-- טבלאות בלי RLS
select tablename from pg_tables
where schemaname = 'public' and rowsecurity = false;

-- טבלאות עם RLS אבל בלי מדיניות (חוסמות הכל; לוודא שזה מכוון)
select t.tablename from pg_tables t
left join pg_policies p on p.schemaname = t.schemaname and p.tablename = t.tablename
where t.schemaname = 'public' and t.rowsecurity and p.policyname is null;

-- כל המדיניות לסקירה ידנית: לחפש true, תנאים בלי auth.uid(), ו-user_metadata
select schemaname, tablename, policyname, cmd, roles, qual, with_check
from pg_policies where schemaname in ('public', 'storage')
order by tablename, cmd;

-- פונקציות SECURITY DEFINER (עוקפות RLS)
select p.proname from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.prosecdef;

-- Views בלי security_invoker (עוקפות RLS)
select c.relname from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and c.relkind = 'v'
and not coalesce(array_to_string(c.reloptions, ',') ~* 'security_invoker=(true|on|1)', false);

-- buckets ציבוריים
select id, public from storage.buckets;
```

מה לבדוק:

- [קריטי] RLS פעיל בכל טבלה שיש בה מידע של משתמשים. טבלאות שנוצרות במיגרציות לא מקבלות RLS אוטומטית, אז לוודא שבקבצי ה-migrations יש `enable row level security` לכל `create table`.
- [קריטי] יש מדיניות לכל פעולה (select / insert / update / delete). ב-insert וב-update יש `with check (auth.uid() = user_id)`, כדי שמשתמש לא יוכל לכתוב שורה בשם מישהו אחר. מדיניות עם `true` נבדקת ידנית.
- [קריטי] אף מדיניות לא מתבססת על `user_metadata`, כי המשתמש יכול לערוך אותו. תפקיד admin נשמר בטבלה מוגנת או ב-`app_metadata`.
- [קריטי] Storage: לכל bucket יש מדיניות select / insert / update / delete על `storage.objects` שתלויה ב-`auth.uid()` (למשל תיקייה לפי מזהה המשתמש: `(storage.foldername(name))[1] = auth.uid()::text`). bucket ציבורי רק לתוכן שבאמת ציבורי.
- [גבוה] כל פונקציית SECURITY DEFINER בודקת הרשאות בעצמה ומגדירה `set search_path = ''`. Views מוגדרות עם `security_invoker = true`.
- [גבוה] אין IDOR: כל API או Edge Function שמקבל מזהה בודק שהמשתמש הוא הבעלים, לא רק שהוא מחובר. פעולות admin נבדקות בשרת, לא רק מוסתרות ב-UI.
- [בינוני] יש אינדקס על כל עמודה שמשמשת במדיניות (user_id וכו').
- להריץ את Security Advisor ואת Performance Advisor בדשבורד ולטפל בכל שגיאה.

## 2. מפתחות וסודות

```bash
# מפתחות סודיים מוכרים בקוד
grep -rnE "sb_secret_|SERVICE_ROLE|sk_live_|-----BEGIN" --exclude-dir=node_modules --exclude-dir=.git .

# משתני סביבה ציבוריים שהשם שלהם נראה כמו סוד
grep -rnE "(NEXT_PUBLIC|VITE|EXPO_PUBLIC|PUBLIC)_[A-Z0-9_]*(SECRET|SERVICE|PRIVATE|PASSWORD|TOKEN)" --exclude-dir=node_modules .

# כל ה-JWT בקוד ובקבצי ה-build, עם פענוח ה-payload. אם מופיע "role":"service_role" זה קריטי
npm run build
grep -rhoE "eyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]+" --exclude-dir=node_modules --exclude-dir=.git . 2>/dev/null | sort -u | while read t; do echo "$t" | cut -d. -f2 | node -e 'const s=require("fs").readFileSync(0,"utf8").trim();console.log(Buffer.from(s,"base64url").toString())'; done

# סודות בהיסטוריית git (אותו פענוח על JWT שנמצאים)
git log -p --all | grep -oE "eyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]+|sb_secret_[A-Za-z0-9_-]+|sk_live_[A-Za-z0-9]+" | sort -u
# אם gitleaks מותקן:  gitleaks detect -v

# קבצי .env שנמצאים במעקב
git ls-files | grep -E "(^|/)\.env"
```

- [קריטי] בקוד שרץ בדפדפן ובקבצי ה-build אין service_role, sb_secret_, סיסמת DB או מפתח API פרטי. בצד הלקוח מותר רק anon או sb_publishable_.
- [קריטי] אם סוד נכנס פעם ל-git, צריך להחליף אותו (rotate). מחיקה מהקוד לא מספיקה, כי הוא נשאר בהיסטוריה.
- [גבוה] קבצי `.env*` נמצאים ב-.gitignore ולא במעקב.
- [גבוה] משתני הסביבה ב-Production (ב-Vercel) שייכים לפרויקט הייצור, לא מפתחות test/dev. יש פרויקט Supabase נפרד לפיתוח ולייצור.

## 3. קלט, XSS ושגיאות

```bash
grep -rnE "dangerouslySetInnerHTML|\.innerHTML\s*=|v-html|eval\(|new Function\(" --exclude-dir=node_modules .
grep -rniE "console\.(log|debug|info)\(.*(token|session|password|auth)" --exclude-dir=node_modules .
grep -rnE "EXECUTE |execute format" supabase/ 2>/dev/null
```

- [קריטי] קלט של משתמש לא נכנס ל-innerHTML או ל-dangerouslySetInnerHTML בלי DOMPurify.
- [גבוה] הוולידציה האמיתית נעשית בשרת: constraints, CHECK ואורך שדות ב-DB, או בדיקה ב-Edge Function. ולידציה בלקוח היא רק חוויית משתמש.
- [גבוה] אין SQL דינמי משורשר בפונקציות. אם צריך EXECUTE, רק עם `format()` ו-`%L` / `%I`.
- [גבוה] אין console.log שמדפיס טוקנים או מידע אישי בייצור.
- [גבוה] המשתמש רואה רק הודעת שגיאה כללית, בלי stack trace ובלי הודעות DB גולמיות.

## 4. Auth והגבלת קצב (בדיקה ידנית בדשבורד)

- [גבוה] אימות מייל פעיל, אורך סיסמה מינימלי, והגנה מסיסמאות שדלפו (אם התוכנית כוללת אותה).
- [גבוה] ב-Redirect URLs יש רק את הדומיינים שלך, בלי wildcard רחב, וה-Site URL הוא דומיין הייצור.
- [גבוה] CAPTCHA (hCaptcha או Turnstile) בהרשמה ובאיפוס סיסמה, ו-Rate limits של Auth מוגדרים.
- [גבוה] הגבלת קצב על endpoints יקרים: Edge Functions, קריאות AI, שליחת מיילים.
- [בינוני] זמן תפוגה סביר ל-JWT, ו-Logout מנקה את ה-session.
- [בינוני] אם לא כולם צריכים להירשם, לכבות הרשמה פתוחה.

## 5. כותרות אבטחה ותשתית

```bash
curl -sI https://YOUR-DOMAIN | grep -iE "strict-transport|content-security|x-content-type|x-frame|referrer-policy|permissions-policy"
```

- [קריטי] האפליקציה עובדת רק ב-HTTPS, כולל הפניה מ-http.
- [גבוה] הכותרות האלה קיימות: Strict-Transport-Security, Content-Security-Policy (לפחות `frame-ancestors 'none'` ו-default-src מוגבל), `X-Content-Type-Options: nosniff`, `Referrer-Policy: strict-origin-when-cross-origin`, Permissions-Policy. מגדירים אותן ב-vercel.json או ב-headers() של next.config, ובודקים גם ב-securityheaders.com.
- [גבוה] CORS ב-Edge Functions מוגבל לדומיין שלך.
- [גבוה] גיבויים: לבדוק מה התוכנית ב-Supabase כוללת. אם אין גיבוי אוטומטי, להריץ `supabase db dump` לפני ההשקה, ולנסות שחזור לפחות פעם אחת.
- [בינוני] אין source maps ציבוריים בייצור (`productionBrowserSourceMaps: false` ב-Next, `build.sourcemap: false` או `'hidden'` ב-Vite).
- [בינוני] נמחקו נתיבי דיבאג, דפי בדיקה, משתמשי test ונתוני seed.

## 6. תלויות

```bash
npm audit --omit=dev
npx license-checker --production --summary
npx license-checker --production --onlyAllow "MIT;ISC;Apache-2.0;BSD-2-Clause;BSD-3-Clause;0BSD;CC0-1.0;Unlicense;BlueOak-1.0.0;CC-BY-4.0"
```

- [גבוה] אין פגיעויות high או critical ב-npm audit.
- [בינוני] Dependabot פעיל ב-GitHub, וה-lockfile נמצא ב-git.
- את הרישיונות בודקים בסעיף 10.

## 7. PWA ו-Service Worker

לחפש: sw.js, service-worker, workbox, next-pwa, vite-plugin-pwa, manifest.json, manifest.webmanifest.

- [קריטי לפרטיות] ה-Service Worker לא שומר בקאש תגובות מ-`/rest/v1`, `/auth/v1`, `/storage/v1` או מכל API שמחזיר מידע אישי. הבקשות האלה מוגדרות NetworkOnly.
- [גבוה] ב-Logout מנקים את Cache Storage (`caches.keys()` ואז `caches.delete`), את IndexedDB ואת localStorage / sessionStorage, כדי שמידע לא יישאר במכשיר משותף.
- [גבוה] לכל build יש גרסת קאש חדשה, קאשים ישנים נמחקים ב-activate, והמשתמש רואה הודעה "גרסה חדשה זמינה" במקום עדכון שקט.
- [בינוני] ב-Manifest מוגדרים name, short_name, start_url, `display: standalone`, theme_color, background_color, ואייקונים בגודל 192 ו-512 כולל maskable. ב-HTML יש `<link rel="apple-touch-icon">`, ו-`lang="he" dir="rtl"` אם האפליקציה בעברית.
- [בינוני] בקשת הרשאה ל-Push רק אחרי פעולה של המשתמש. הודעות שיווקיות רק בהסכמה מפורשת מראש (חוק הספאם, סעיף 30א לחוק התקשורת). באייפון Push עובד רק כשהאפליקציה מותקנת במסך הבית.

## 8. פרטיות וציות

רקע לבדיקה מחדש: תיקון 13 לחוק הגנת הפרטיות נכנס לתוקף ב-14.8.2025, וחל גם על מי ששומר מידע בסיסי כמו רשימת משתמשים או מיילים.

- [קריטי] יש מדיניות פרטיות שמקושרת בהרשמה ובפוטר. היא מפרטת מה נאסף ולמה, כמה זמן המידע נשמר, אילו ספקים מקבלים אותו ובאיזו מדינה (Supabase ואזור השרת, Vercel, אנליטיקס, Sentry, ספק מיילים), ואיך מבקשים עיון, תיקון או מחיקה.
- [גבוה] יש מחיקת חשבון מתוך האפליקציה, והיא מוחקת באמת: את המשתמש ב-auth.users (דרך Edge Function עם service role), את השורות בטבלאות (`ON DELETE CASCADE`) ואת הקבצים ב-Storage.
- [גבוה] אוספים רק מה שצריך. כל שדה בטופס נחוץ.
- [גבוה] יש הסכם עיבוד מידע (DPA) עם כל ספק חיצוני שנחשף למידע. אצל הספקים הגדולים לוודא שה-DPA שלהם חל.
- [גבוה] ב-Sentry ובלוגים `sendDefaultPii` כבוי, ומיילים וטוקנים מסוננים.
- [גבוה] יש תנאי שימוש: הגבלת אחריות, כללי תוכן ודרך ליצור קשר.
- [בינוני] אם יש משתמשים מאירופה ויש אנליטיקס או עוגיות לא הכרחיות, צריך באנר הסכמה לפי GDPR.
- [קריטי אם רלוונטי] אם נאסף מידע רגיש (בריאות, קטינים, מידע פיננסי), להמליץ על ייעוץ עם עורך דין לפרטיות לפני ההשקה.

## 9. נגישות

```bash
grep -rnE "user-scalable=no|maximum-scale=1" --exclude-dir=node_modules .
grep -rnP "<img(?![^>]*\balt=)[^>]*>" --exclude-dir=node_modules .
# אם יש Chrome זמין:
npx lighthouse https://YOUR-DOMAIN --only-categories=accessibility,best-practices
npx @axe-core/cli https://YOUR-DOMAIN
```

רקע לבדיקה מחדש: אתרים ואפליקציות שנותנים שירות לציבור בישראל חייבים בנגישות לפי ת"י 5568, שמבוסס על WCAG. פטורים: לעוסק פטור יש פטור מלא. במחזור שנתי ממוצע מתחת ל-120,000 ש"ח יש פטור זמני ל-3 שנים. תוכן שרק נרשמים יכולים לגשת אליו, כשרשומים עד 500 משתמשים בו-זמנית, פטור אלא אם מישהו ביקש התאמה, אבל התשתית של האתר לא פטורה.

- [גבוה] גם כשיש פטור, לטפל בבסיס: ניגודיות מספקת, alt לכל תמונה, ניווט מלא במקלדת עם focus שרואים, label לכל שדה, כפתורים אמיתיים ולא div, `lang` ו-`dir` נכונים, ואפשרות הגדלה (בלי `user-scalable=no`).
- [בינוני] יש הצהרת נגישות עם פרטי קשר. ווידג'ט נגישות לא מחליף נגישות אמיתית.

## 10. זכויות יוצרים וקניין רוחני

- [גבוה] רישיונות ספריות: ב-MIT, Apache ו-BSD צריך לשמור את הודעת הרישיון (קובץ THIRD_PARTY_NOTICES או דף רישיונות). ספריות ב-GPL, AGPL או SSPL מסמנים ובודקים עם המשתמש, כי AGPL עלול לחייב לפתוח את הקוד גם בשירות רשת.
- [גבוה] פונטים: לאתר כל `@font-face` וכל קובץ פונט. Google Fonts (OFL) בסדר. פונטים עבריים מסחריים דורשים רישיון webfont, אז לשאול את המשתמש אם יש לו.
- [גבוה] תמונות ואייקונים: לעבור על כל קובץ ב-public / assets ולשאול מאיפה הוא. מקורות בסדר: צילומים של המשתמש, Unsplash, Pexels, ספריות אייקונים עם רישיון (Lucide, Heroicons). לא מגוגל תמונות. לתת קרדיט כשנדרש (Font Awesome Free, OpenStreetMap, אייקונים ב-CC-BY).
- [גבוה אם משתמשים מעלים תוכן] תנאי השימוש נותנים לך רישיון להציג את התוכן, ויש כתובת לבקשות הסרה של תוכן מפר.
- [בינוני] תוכן שנוצר ב-AI: לבדוק את תנאי השימוש של הכלי.
- [בינוני] שם האפליקציה והלוגו: לחפש סימני מסחר (במאגר רשות הפטנטים בישראל וב-USPTO) ובחנויות האפליקציות.
- [בינוני] לעמוד בתנאי השימוש של כל API צד שלישי (מפות, AI, תשלומים): מגבלות קאש, קרדיט, שימוש מסחרי.
- [בינוני] יש הודעת © בפוטר.

## 11. חשבונות ועלויות (בדיקה ידנית מול המשתמש)

- [גבוה] אימות דו-שלבי ב-GitHub, Vercel, Supabase, אצל רשם הדומיין ובחשבון Google / Apple.
- [גבוה] התראות חיוב או תקרת הוצאה ב-Supabase, ב-Vercel ובכל API בתשלום.
- [בינוני] ניטור זמינות (למשל UptimeRobot) ו-Sentry בייצור.

## 12. בדיקת שני משתמשים (קריטי, תמיד בסוף)

ליצור שני משתמשי בדיקה, א' ו-ב', כשלשניהם יש נתונים וקבצים. להתחבר כמשתמש א' ולנסות לגעת בנתונים של ב'. אם הלקוח של Supabase חשוף בקונסול:

```js
// להחליף TABLE, BUCKET ו-OTHER_ID (המזהה של משתמש ב')
await supabase.from('TABLE').select('*'); // צריך להחזיר רק שורות של א'
await supabase.from('TABLE').update({ title: 'x' }).eq('user_id', 'OTHER_ID').select(); // צריך להחזיר []
await supabase.from('TABLE').delete().eq('user_id', 'OTHER_ID').select(); // צריך להחזיר []
await supabase.from('TABLE').insert({ user_id: 'OTHER_ID' }); // צריך להיכשל עם שגיאת RLS
await supabase.storage.from('BUCKET').list('OTHER_ID'); // צריך להחזיר רשימה ריקה או שגיאה
```

בלי משתמש מחובר (צריך להחזיר [] בכל טבלה פרטית):

```bash
curl "https://PROJECT.supabase.co/rest/v1/TABLE?select=*" -H "apikey: ANON_KEY" -H "Authorization: Bearer ANON_KEY"
```

כדי לבדוק כמשתמש מחובר, להחליף את ה-Bearer ב-access token של המשתמש (נמצא ב-localStorage, במפתח `sb-<ref>-auth-token`). אם אחת הבדיקות מצליחה לגעת בנתונים של משתמש אחר, האפליקציה לא מוכנה להשקה.

## הדוח

- כותבים בעברית.
- מתחילים בממצאים הקריטיים (חוסמי השקה), אחר כך גבוה, אחר כך בינוני.
- לכל ממצא: מה נמצא (קובץ ושורה, או תוצאת השאילתה), למה זה מסוכן במשפט אחד, ואיך מתקנים, עם קוד או SQL מדויק כשאפשר.
- מה שאי אפשר לבדוק מהקוד מסומן "בדיקה ידנית" עם הוראה קצרה.
- מסיימים במשפט אחד: מוכן להשקה או לא מוכן, ושלושת הדברים הראשונים לתקן.
- לא ממציאים עובדות משפטיות, ומציינים שזה לא ייעוץ משפטי.