# ثبت وضعیت رابط پیش از مهاجرت موبایل — مرحلهٔ ۱

ممیزی ساختار و چیدمان فعلی انجام شد. وابستگی‌های اصلی عبارت‌اند از بوم مشترک محیط/UI، مختصات ثابت، مقیاس دستی پنل‌ها، اتصال بعضی رابط‌ها به تصویر زوم‌شده و نبود سرویس ناحیهٔ امن واقعی دستگاه.

- تاریخ ثبت: `2026-10-11`.
- نسخهٔ مبنای کد: `5959c4b9a5820d22cf67715437c2f940f4e3cc35`.
- مرجع هدف: [قواعد طراحی رابط موبایل](ui-layout-and-rtl.md).
- روش: بررسی فایل‌های پروژه، صحنه‌ها و بخش‌های سازندهٔ رابط در اسکریپت‌ها؛ شمارهٔ خط‌ها مربوط به همین مبنا هستند.
- این گزارش وضعیت کد را ثبت می‌کند. آزمون تصویری چند نسبت، اجرای APK و تأیید لمس روی گوشی انجام نشده‌اند؛ علت دقیق دیده‌نشدن کنترل‌ها روی گوشی هنوز تأیید نشده است.

## ۱. تنظیمات و مبنای مختصات

| مورد | وضعیت فعلی | شاهد |
| --- | --- | --- |
| صحنهٔ شروع | `main.tscn`؛ Splash کوتاه و سپس `map.tscn` | [main.gd](../SourceProject/scripts/main.gd)، خط‌های ۳ و ۹ |
| بوم طراحی | `1280×720` | [project.godot](../SourceProject/project.godot)، خط‌های ۳۰ و ۳۱ |
| Stretch | `canvas_items` و `keep`؛ هدف جدید `expand` است | همان فایل، خط‌های ۳۵ و ۳۹ |
| پنجرهٔ دسکتاپ | `960×540` و `resizable=false` | همان فایل، خط‌های ۳۲ تا ۳۴ |
| Renderer | دسکتاپ و موبایل هر دو `gl_compatibility` | همان فایل، خط‌های ۴۳ و ۴۴ |
| helper مشترک | `DESIGN_SIZE=1280×720` برای محیط و UI | [responsive_layout.gd](../SourceProject/components/responsive_layout.gd)، خط ۵ |
| Safe Area | `safe_rect()` حاصل `contain_scale()` و مرکزکردن قاب طراحی است؛ Insets گوشی را نمی‌خواند | همان فایل، خط‌های ۲۰ و ۲۴ |
| خروجی Android | پریست `Android`؛ `Immersive=true`، `Edge-to-edge=false` | [export_presets.cfg](../SourceProject/export_presets.cfg)، خط‌های ۷، ۶۳ و ۶۴ |
| جهت موبایل | تنظیم صریح Orientation در `project.godot` یافت نشد؛ باید در زیرساخت/تست خروجی تثبیت شود | تنظیمات فعلی پروژه |
| هویت خروجی | `version/code=1` و `version/name` خالی؛ نام بستهٔ پریست `com.example.$genname` | همان پریست، خط‌های ۴۴ تا ۴۶ |
| مسیر APK | پریست: `HooshUp1.0.4.apk`؛ اسکریپت نصب: `HooshUp-debug-install.apk` با بستهٔ مورد انتظار `com.example.hooshup` | پریست، خط ۱۴؛ [اسکریپت نصب](build-and-install-android.ps1)، خط‌های ۹ و ۱۰ |

در جست‌وجوی سورس، استفاده‌ای از `get_display_safe_area`، `get_display_cutouts` یا مدیریت صریح صفحه‌کلید نرم یافت نشد. فایل فونت پروژه با پسوندهای `ttf`، `otf`، `woff` و `fnt`، فایل Theme مستقل `tres` و اتصال صریح FontFile/FontVariation نیز یافت نشد. StyleBoxها و اندازهٔ فونت عمدتاً Override محلی‌اند؛ این یافته دربارهٔ منابع پروژه است و تفاوت واقعی رندر فونت در APK را ثابت نمی‌کند.

## ۲. درخت فعلی لایه‌ها

```text
SceneTree / root
├── GlobalMenu (autoload، CanvasLayer، layer=20)
│   ├── GlobalMenuOverlay (Control، Full Rect)
│   │   ├── MenuPanel (TextureRect → MenuContent)
│   │   ├── GameToolbar (Control؛ ساخته‌شده در زمان اجرا)
│   │   ├── ExitConfirmation
│   │   └── HintConfirmation (ساخته‌شده در زمان اجرا)
│   ├── SettingsPanel
│   ├── StageProgressPanel
│   ├── BadgesPanel
│   └── DevelopmentMissionSelector (فقط Debug، z=-1)
│       ├── Toggle
│       ├── Panel → StagePicker / MissionPicker / Launch
│       └── Diagnostics Label
└── current_scene
    ├── Map (Control؛ در زمان نمایش مپ)
    │   ├── SafeViewport → MapContent → MapImage + Stage Buttons
    │   └── MapMenuButton
    └── Level1 (Control؛ در زمان نمایش مرحله)
        ├── PanZoomViewport → World (Control) → LevelImage
        │   ├── Hotspots
        │   └── Effects → بعضی رابط‌های لپ‌تاپ/مینی‌گیم
        ├── StretchToFitViewport → SceneImage → Effects
        │   └── بعضی رابط‌های چت/مینی‌گیم
        ├── DialoguePanel
        ├── PhoneMessageOverlay
        └── StageProgressPanel (نسخهٔ دوم، z=20)
```

`Map` و `Level1` جایگزین یکدیگرند. درخت، محل مالکیت اجزا را نشان می‌دهد؛ همهٔ پنل‌ها هم‌زمان باز نیستند. Splash فقط هنگام شروع، CanvasLayer موقت `100` دارد.

شاهدها: [global_menu.gd](../SourceProject/components/global_menu.gd)، خط ۲۲ و ساخت فرزندان در `_ready()`؛ [global_menu_overlay.gd](../SourceProject/components/global_menu_overlay.gd)، خط ۴۱؛ [level1.tscn](../SourceProject/scenes/level1.tscn)؛ [map_scene.gd](../SourceProject/scripts/map_scene.gd)، خط ۳۰.

| محدودهٔ رسم | وضعیت فعلی | نتیجه برای مهاجرت |
| --- | --- | --- |
| Canvas معمولی `0` | مپ، محیط مرحله، دیالوگ، تلفن و بسیاری از بازی‌ها | رابط مرحله هنوز Overlay مستقل ندارد |
| CanvasLayer `20` | منوی عمومی، تولبار و پنل‌های عمومی | HUD و Overlay در یک لایه و بدون Root مشترک SafeArea ساخته شده‌اند |
| `z=-1` در لایهٔ عمومی | انتخاب‌گر تستی و برچسب تشخیص آن | لایهٔ Diagnostics مستقل وجود ندارد؛ بازشدن منو می‌تواند آن را بپوشاند |
| `z=20` در Canvas مرحله | پنل پیشرفت محلی مرحله | این مقدار، CanvasLayer نیست و هم‌ارز پنل عمومی در لایهٔ `20` نیست |
| CanvasLayer `100` | Splash موقت | پوشاندن صفحه مستقل از رابط عمومی انجام می‌شود |

## ۳. فهرست رابط‌ها و وابستگی‌های چیدمان

| رابط | محل فعلی و چیدمان | مختصات/Scale/تصویر | محل شاهد |
| --- | --- | --- | --- |
| مپ اصلی | Root تمام‌صفحه؛ `SafeViewport` دارای Clip؛ دکمهٔ منو فرزند مستقیم مپ | محتوا `1280×720`؛ Scale برابر `contain_scale × zoom`؛ Zoom داده `1.3`؛ منو در `(24,20)`؛ نام مراحل با Rectهای ثابت روی هنر مپ | [map_scene.gd](../SourceProject/scripts/map_scene.gd)، خط‌های ۱۱، ۱۱۱ و ۱۲۲؛ [main_map.json](../SourceProject/data/views/main_map.json) |
| تولبار | زیر `GlobalMenuOverlay`؛ اندازهٔ ثابت `1050×273` | جای آواتار، امتیاز، مأموریت‌ها و کلیدها از مختصات تصویر با `SOURCE_SCALE`؛ کل تولبار با `safe_scale × 0.44` در `(18,14)` کوچک می‌شود | [game_toolbar.gd](../SourceProject/components/game_toolbar.gd)، خط‌های ۱۰، ۶۰ و ۹۸؛ [global_menu_overlay.gd](../SourceProject/components/global_menu_overlay.gd)، خط‌های ۷۳ تا ۸۲ |
| انتخاب‌گر تستی | Root تمام‌صفحه؛ Panel و دو OptionButton؛ بدون Container داخلی | پنل `580×330` در `(20,300)`؛ Toggle در `(20,650)`؛ مختصات داخلی ثابت؛ Scale دستی پنل و Toggle | [development_mission_selector.gd](../SourceProject/components/development_mission_selector.gd)، خط‌های ۳۰ و ۱۱۶ |
| منوی عمومی | `TextureRect/MenuContent` و کنترل‌های دارای Offset صحنه | قاب `1280×720` با `contain_scale`؛ انیمیشن Position از بالای صفحه؛ کنترل‌ها با نقاط هنر پس‌زمینه هم‌مختصات‌اند | [global_menu.tscn](../SourceProject/components/global_menu.tscn)، خط ۲۸؛ [global_menu_overlay.gd](../SourceProject/components/global_menu_overlay.gd)، خط‌های ۷۲ و ۲۲۷ |
| تأیید Hint | PanelContainer، اما فرزند داخلی `Control` با جای‌گذاری دستی | پنل `640×300` در `(320,210)` و Scale دستی؛ دکمه/متن با Position ثابت | همان اسکریپت، خط‌های ۸ و ۹۸ |
| تأیید خروج | پنل مرکزی با Anchor `0.5`؛ Margin/VBox/HBox | اندازهٔ اولیه `500×200` با Offset؛ ساختار داخلی Container دارد؛ SafeArea واقعی ندارد | [global_menu.tscn](../SourceProject/components/global_menu.tscn)، خط ۱۹۴ |
| تنظیمات | Root تمام‌صفحه؛ فرم فرزند TextureRect هنری | قاب `1200×675` در `(40,22)` با `contain_scale`؛ ورودی، آواتار، موسیقی و ذخیره در نقاط ثابت تصویر | [settings_panel.gd](../SourceProject/components/settings_panel.gd)، خط‌های ۴۴، ۷۴ و ۱۲۲ |
| پیشرفت مرحله | دو نمونه از یک کامپوننت؛ تصویر و Content جدا ولی هم‌مکان | هنر `1672×941`؛ اندازه‌ها و فونت‌ها با `panel_scale` دستی تبدیل می‌شوند؛ عناوین مرحله Y منفی دارند | [stage_progress_panel.gd](../SourceProject/components/stage_progress_panel.gd)، خط‌های ۱۲، ۶۹ و ۹۵ |
| نشان‌ها | Root تمام‌صفحه؛ Background و Content مستقل؛ ScrollContainer موجود | هنر `1672×941`؛ Scale دستی روی هر دو؛ چهار ستون دستی و اندازهٔ ثابت سلول؛ Scroll در Rect ثابت | [badges_panel.gd](../SourceProject/components/badges_panel.gd)، خط‌های ۹، ۶۸ و ۱۲۵ |
| دیالوگ فکر/Hint/گفتگو | فرزند مستقیم `Level1`؛ PanelContainer و Containerهای داخلی | قاب بیرونی همچنان با Position/Size داده و `contain_scale`؛ بابل در `(257,140)` با اندازهٔ اسمی ثابت | [dialogue_panel.gd](../SourceProject/components/dialogue_panel.gd)، خط‌های ۹، ۸۸ و ۱۰۳؛ [dialogue_panel.tscn](../SourceProject/components/dialogue_panel.tscn) |
| تلفن پیام | فرزند مستقیم `Level1`؛ متن و دکمه فرزند تصویر تلفن | اندازه از نسبت Parent؛ مرکز X برابر `0.75 × width`؛ چیدمان نسبی داخل تصویر و فونت با ارتفاع؛ ناحیهٔ امن واقعی ندارد | [phone_message_overlay.gd](../SourceProject/components/phone_message_overlay.gd)، خط ۷۴ |
| چت و کارت‌های لپ‌تاپ | زیر `Effects` تصویر مرحله | Rect چت/کارت از اندازهٔ تصویر؛ فونت تابع ارتفاع تصویر؛ مسیر چت پرسپکتیو از Node2D، SubViewport و Polygon2D استفاده می‌کند | [level_scene.gd](../SourceProject/scripts/level_scene.gd)، خط‌های ۲۵۵، ۶۸۵ و ۷۸۲ |
| مینی‌گیم تطبیق ابزار | فرزند `StretchToFitViewport`، مستقل از `SceneImage` ولی در Canvas مرحله | `SafeCanvas` ثابت `1280×720` با `contain_scale`؛ عنوان و گزینه‌ها دستی | همان فایل، خط‌های ۴۰۶ و ۴۸۳ |
| سایر بازی‌ها و محتوای جانبی | بیشتر زیر `Effects`؛ بازی اتصال سرنخ فرزند مستقیم مرحله است | انتخاب، مقایسهٔ پاسخ، کاغذها و محتوای جانبی با مختصات دستی؛ بازی مسیر ارائه Board ثابت `1096×592` دارد و فقط مرکز می‌شود | همان فایل، خط‌های ۱۱۴۱، ۱۲۵۸، ۱۴۷۱، ۱۷۲۹ و ۱۸۷۵؛ [presentation_path_game.gd](../SourceProject/components/presentation_path_game.gd)، خط‌های ۴۶ و ۱۶۰ |
| شمارش‌معکوس | Control مستقل با تصویر و Label تمام‌صفحه | اندازهٔ اسمی `72×72`؛ مکان پایین-راست با تفریق از `parent_size`، بدون Anchor | [countdown.gd](../SourceProject/components/countdown.gd)، خط‌های ۸ و ۶۳ |

این جدول بین «مختصات متصل به هنر محیط» و «مختصات مطلق رابط» فرق می‌گذارد. Scale محیط و محل سرنخ وابسته به تصویر، ذاتاً خطای HUD نیستند. Scale دستی UI هم در وضعیت فعلی به‌تنهایی اثبات مقیاس دوگانه نیست؛ هنگام تغییر رزولوشن/Stretch باید با مقیاس موتور هماهنگ یا حذف شود.

## ۴. یافته‌های اولویت‌دار

| شناسه | یافته و وضعیت اثبات | پیامد/اقدام در مهاجرت |
| --- | --- | --- |
| UI-01 | قطعی در کد: یک `DESIGN_SIZE` برای World و UI و یک قاب هندسی با نام Safe | مبنای هنری محیط از اندازهٔ UI و SafeArea واقعی جدا شود؛ تغییر یک ثابت به `1920×1080` همهٔ مصرف‌کننده‌ها را تحت‌تأثیر قرار می‌دهد |
| UI-02 | قطعی در ساختار: HUD/Overlay عمومی در یک CanvasLayer؛ Overlayهای مرحله خارج از آن | زیرساخت مشترک و مالکیت پنل‌ها پیش از جابه‌جایی اجزا تعیین شود |
| UI-03 | قطعی در کد: انتخاب‌گر تستی با Position/Scale و OptionButton بدون مدیریت صریح Popup | نخستین نمونهٔ مهاجرت؛ نمایش و لمس Popup هنوز نیازمند تست APK است |
| UI-04 | قطعی در کد: عنوان و نام مرحله در پنل پیشرفت، Y منفی دارند | محاسبهٔ زیر نشان می‌دهد در وضعیت باز نهایی روی بوم مرجع خارج صفحه می‌افتند؛ اصلاح در مرحلهٔ مهاجرت پنل انجام شود |
| UI-05 | قطعی در ساختار: دو نمونهٔ StageProgressPanel با Canvas متفاوت | مسیرهای «بازکردن از منو» و «پایان مأموریت» باید مالک و قواعد نمایش مشترک داشته باشند |
| UI-06 | قطعی در کد: رابط‌های چت/بازی زیر Effects تصویر و یک مسیر Node2D/SubViewport | نمایش هنری متصل به مانیتور از کنترل‌های تعاملی Overlay تفکیک شود؛ همهٔ Positionها کورکورانه حذف نشوند |
| UI-07 | قطعی در منابع بررسی‌شده: فونت بسته‌بندی‌شده و Theme مشترک یافت نشد | فونت و اندازه‌ها در زیرساخت مشترک تثبیت شوند؛ اختلاف فونت گوشی هنوز مشاهده/اندازه‌گیری نشده است |
| UI-08 | قطعی در تنظیمات: پنجرهٔ تست غیرقابل Resize و اطلاعات نسخهٔ APK ناکافی | امکان تست چند نسبت و ثبت Build مشخص فراهم شود؛ نام فایل APK به‌تنهایی شناسهٔ نسخه نیست |
| UI-09 | نیازمند آزمون: هم‌پوشانی، Clip، لمس پشت Modal و اثر زبان سیستم | از وجود Position ثابت یا LTR در کد نمی‌توان وقوع/رفع مشکل روی گوشی را نتیجه گرفت |
| UI-10 | رفتار عمدی: انتخاب‌گر فقط در `OS.is_debug_build()` ساخته می‌شود | نبود آن در Release خطای Layout نیست؛ مقایسه باید با APK Debug انجام شود |

### محاسبهٔ هندسهٔ پنل تستی در بوم فعلی

برای Root برابر `1280×720` و بدون تبدیل اضافی Parent، `safe_scale=1` است:

| عنصر | محل پیش‌بینی‌شدهٔ نهایی | اندازهٔ اسمی |
| --- | --- | --- |
| Toggle | `(20,650)` | `150×48` |
| Panel | `(20,300)` | `580×330` |
| StagePicker | `(198,388)` | `366×42` |
| MissionPicker | `(198,444)` | `366×42` |
| Launch | `(198,568)` | `366×44` |
| Diagnostics | `(720,16)` | `540×54` |

این اعداد از فرمول کد محاسبه شده‌اند؛ اندازهٔ نهایی می‌تواند با حداقل اندازهٔ Theme تغییر کند. پنل در شروع مخفی است و با Toggle باز می‌شود. جاگیری اسمی کنترل‌ها داخل بوم است؛ بنابراین ممیزی ثابت، بیرون‌زدگی این کنترل‌ها روی گوشی را اثبات نمی‌کند. برچسب تشخیص اکنون Control قابل‌رسم است، اما در همان لایهٔ انتخاب‌گر قرار دارد. گزارش آن مختصات منطقی است، نه پیکسل فیزیکی اسکرین‌شات.

### خروج عنوان‌های پنل پیشرفت از محدوده

بر اساس `refresh_layout()`، `get_visible_panel_position()` و `scale_position()` در بوم `1280×720`:

```text
panel_scale = 1200 / 1672 ≈ 0.7177
content.position.y = 22
StageTitle.y = 22 + (-260 × 0.7177) ≈ -164.6
StageName.y  = 22 + (-235 × 0.7177) ≈ -146.7
```

ارتفاع اسمی این دو Label نیز آن‌ها را به داخل بوم برنمی‌گرداند. این محاسبه برای حالت باز نهایی است، نه خروج عمدی پنل هنگام انیمیشن بسته‌شدن. محل شاهد: [stage_progress_panel.gd](../SourceProject/components/stage_progress_panel.gd)، خط‌های ۸۱، ۹۵، ۹۶، ۱۴۱ و ۱۵۶. اندازه‌گیری با اجرای صحنه و بررسی تصویر، هنگام مهاجرت لازم است؛ این یافته علت اختصاصی مشکل گوشی اعلام نمی‌شود.

## ۵. بخش‌های قابل‌حفظ و موارد نیازمند احتیاط

- Rootهای مپ، مرحله و بیشتر پنل‌ها Full Rect هستند؛ در بسیاری از کنترل‌ها LTR و RTL متن صریح تنظیم شده و باید حفظ شوند.
- تأیید خروج و محتوای دیالوگ، Container دارند؛ این ساختارها مبنای مناسبی برای توسعه‌اند، هرچند قاب بیرونی هنوز SafeArea واقعی ندارد.
- نشان‌ها ScrollContainer دارند؛ وجود Scroll حفظ شود و شبکهٔ دستی با چیدمان سازگار با فضای Parent جایگزین شود.
- هات‌اسپات فعلی فرزند `Hotspots` تصویر است و پس از Parenting با مختصات نرمال‌شده جای‌گذاری می‌شود. در سورس فعلی `top_level` یا `global_position` برای آن یافت نشد؛ اشارهٔ راهنمای قدیمی به هات‌اسپات‌های `top_level` شرح این نسخه نیست. شاهد: [level_scene.gd](../SourceProject/scripts/level_scene.gd)، خط ۹۸۱.
- CanvasLayer مستقل و پس‌زمینهٔ Aspect Cover در Splash موجود است؛ این قسمت با World زوم‌شده مشترک نیست.
- مخفی‌شدن تولبار هنگام Modal در `GlobalMenu` پیاده‌سازی شده است؛ مسدودشدن همهٔ ورودی‌های پشت پنل باید جداگانه در آزمون تعامل بررسی شود.
- اولین بند [sourceproject-setup.md](sourceproject-setup.md) هنوز از `test.tscn` به‌عنوان سطح شروع نام می‌برد، در حالی که `main.gd` مپ را باز می‌کند و آن فایل تست در فهرست فعلی صحنه‌ها نیست. در تصمیم مهاجرت، درخت واقعی کد مبناست.

## ۶. شواهد تصویری و آزمون‌های باز

تصویر موجود [phone-current.png](../phone-current.png) یک شاهد تاریخی است. فایل در Git با شناسهٔ `538ab9c290efc525663e050bf467d724d4142d6b` ثبت شده، اما شناسهٔ APK، وضعیت انتخاب‌گر و زمان تهیهٔ آن همراه فایل ثبت نشده‌اند؛ تصویر مبنای قطعی مقایسهٔ نسخهٔ فعلی نیست.

| بررسی | وضعیت این مرحله |
| --- | --- |
| فهرست رابط‌ها، Parentها و لایه‌ها | انجام شد |
| مختصات ثابت، Scale دستی و وابستگی به تصویر | بررسی و ثبت شد |
| تنظیمات پروژه، SafeArea، منابع فونت و اطلاعات خروجی | بررسی و ثبت شد |
| محاسبهٔ هندسهٔ اسمی پنل تستی و عنوان‌های پیشرفت | انجام شد؛ اجرای موتور نیست |
| اسکرین‌شات اجرای همان Build در ماتریس نسبت‌ها | انجام نشده |
| نمایش Popup، متن بلند، صفحه‌کلید، Locale و لمس واقعی | تأیید نشده |
| تغییر GDScript یا تنظیم اجرایی | انجام نشده؛ آزمون headless ناشی از تغییر کد لازم نبود |
| ساخت یا نصب APK در این مرحله | انجام نشده |

## ۷. ورودی مرحلهٔ بعد

مرحلهٔ ۲ باید سرویس مشترک SafeArea، Rootهای Full Rect/LTR، تفکیک HUD/Overlay و Theme با فونت فارسی را آماده کند. مصرف‌کننده‌های `ResponsiveLayout` نباید هم‌زمان و بدون تفکیک World/UI به اندازهٔ جدید منتقل شوند.

مرحلهٔ ۳، پنل انتخاب مأموریت تستی را به‌عنوان نمونهٔ نخست روی زیرساخت جدید منتقل می‌کند. معیار مقایسه، حفظ انتخاب مرحله/مأموریت و اجرای مأموریت، همراه با نمایش/لمس صحیح Popup و نبود پوشانندهٔ ناخواسته است. UI-04 و UI-05 هنگام مهاجرت پنل پیشرفت باید حل و هر دو مسیر بازشدن پنل بررسی شوند.
