import SwiftUI

/// The two interface languages. Persian is the source language of every string in the code;
/// English is looked up in `english` below.
enum AppLanguage: String, CaseIterable, Identifiable {
    case fa, en
    var id: String { rawValue }
    var label: String { self == .fa ? "فارسی" : "English" }
    var locale: Locale { Locale(identifier: rawValue) }
    var layoutDirection: LayoutDirection { self == .fa ? .rightToLeft : .leftToRight }

    /// First launch: the device's language if we have it, otherwise Persian.
    static var deviceDefault: AppLanguage {
        Locale.preferredLanguages.first?.hasPrefix("en") == true ? .en : .fa
    }
}

enum Lang {
    /// Read by `tr` from anywhere; `SettingsStore` keeps it current and rebuilds the UI on change.
    nonisolated(unsafe) static var current: AppLanguage = .fa
}

/// Translates a Persian source string into the current language.
func tr(_ fa: String) -> String {
    Lang.current == .en ? (english[fa] ?? fa) : fa
}

/// With `%@` / `%d` placeholders.
func tr(_ fa: String, _ args: CVarArg...) -> String {
    String(format: tr(fa), arguments: args)
}

private let english: [String: String] = [
    // tabs and titles
    "خانه": "Home",
    "جستجو": "Search",
    "دسته‌بندی": "Browse",
    "دسته‌بندی‌ها": "Categories",
    "لیست من": "My List",
    "اعلان‌ها": "Notifications",
    "حساب": "Account",
    "حساب و تنظیمات": "Account & Settings",
    "سی‌نما": "30nama",

    // home rows
    "ادامه تماشا": "Continue Watching",
    "پیشنهاد ویژه": "Featured",
    "پیشنهادی": "Suggested",
    "فیلم": "Movies",
    "سریال": "Series",
    "انیمه": "Anime",

    // title page
    "پخش": "Play",
    "ادامه %@": "Resume %@",
    "جزئیات": "Details",
    "به‌زودی": "Coming soon",
    "پخش آنلاین ندارد": "Not available to stream",
    "لیست تماشا": "Watchlist",
    "در لیست تماشا": "In Watchlist",
    "علاقه‌مندی": "Favorite",
    "بازیگران و سازندگان": "Cast & Crew",
    "کارگردان: %@": "Director: %@",
    "قسمت‌ها": "Episodes",
    "فصل %@": "Season %@",
    "%d دقیقه": "%d min",
    "سی‌نما %@": "30nama %@",
    "زیرنویس فارسی": "Persian subtitles",
    "آثار بازیگر": "Actor's titles",
    "آثار کارگردان": "Director's titles",

    // search, browse, filters
    "نام فیلم، سریال یا انیمه": "Movie, series or anime",
    "دست‌کم سه حرف بنویسید.": "Type at least three letters.",
    "نتیجه‌ای برای «%@» پیدا نشد": "No results for “%@”",
    "چیزی پیدا نشد": "Nothing found",
    "مرتبط‌ترین": "Most relevant",
    "جدیدترین": "Newest",
    "جستجوی پیشرفته": "Advanced Search",
    "نتایج جستجوی پیشرفته": "Advanced Search Results",
    "نمایش نتایج": "Show Results",
    "پاک کردن": "Clear",
    "نوع": "Type",
    "ژانر": "Genre",
    "امتیاز IMDb": "IMDb Rating",
    "سال ساخت": "Year",
    "کشور": "Country",
    "دهه ۲۰۲۰": "2020s",
    "دهه ۲۰۱۰": "2010s",
    "دهه ۲۰۰۰": "2000s",
    "دهه ۱۹۹۰": "1990s",
    "قدیمی‌تر": "Older",

    // my list, notifications
    "لیست تماشا خالی است. در صفحه هر فیلم «+ لیست تماشا» را بزنید.": "Your watchlist is empty. Tap “+ Watchlist” on a title page.",
    "علاقه‌مندی‌ها": "Favorites",
    "هنوز چیزی به علاقه‌مندی‌ها اضافه نکرده‌اید.": "You haven't added any favorites yet.",
    "چیزی در حال تماشا نیست.": "Nothing in progress.",
    "ادامه پخش": "Resume",
    "حذف از ادامه تماشا": "Remove from Continue Watching",
    "اعلان تازه‌ای ندارید.": "No new notifications.",

    // account
    "زیرنویس پیش‌فرض": "Default subtitles",
    "اندازه زیرنویس": "Subtitle size",
    "صدا": "Audio",
    "کیفیت تصویر": "Video quality",
    "زبان": "Language",
    "فارسی": "Persian",
    "انگلیسی": "English",
    "خاموش": "Off",
    "کوچک": "Small",
    "متوسط": "Medium",
    "بزرگ": "Large",
    "استریو (۲ کاناله)": "Stereo (2 channels)",
    "فراگیر ۵.۱ (۶ کاناله)": "Surround 5.1 (6 channels)",
    "خودکار": "Automatic",
    "خروج از حساب": "Sign Out",
    "خروج": "Sign Out",
    "انصراف": "Cancel",
    "از حساب سی‌نما در این دستگاه خارج شوید؟": "Sign out of 30nama on this device?",
    "برنامهٔ غیررسمی سی‌نما": "Unofficial 30nama app",
    "اشتراک %@": "%@ plan",
    "%d روز باقی‌مانده": "%d days left",
    "تا %@": "until %@",
    "طلایی": "Gold",
    "نقره‌ای": "Silver",
    "برنزی": "Bronze",
    "رایگان": "Free",
    "پخش آنلاین برای این حساب فعال نیست": "Streaming isn't enabled for this account",

    // sign in
    "ورود به حساب": "Sign In",
    "ورود با سی‌نما": "Sign in with 30nama",
    "با گوشی یا کامپیوتری که در سی‌نما وارد حساب‌تان شده‌اید، کد QR را اسکن کنید.": "Scan the QR code with a phone or computer that is signed in to 30nama.",
    "در صفحه‌ای که باز می‌شود، ورود این تلویزیون را تأیید کنید.": "On the page that opens, approve this TV.",
    "صفحهٔ سی‌نما را باز کنید، وارد حساب‌تان شوید و ورود این دستگاه را تأیید کنید.": "Open the 30nama page, sign in and approve this device.",
    "کد جدید": "New Code",
    "تغییر کلید API": "Change API Key",
    "کلید API": "API Key",
    "ذخیره": "Save",
    "درخواست‌ها به یک c-api-key نیاز دارند؛ همان کلیدی که کلاینت وب رسمی تلویزیون سی‌نما (tv.30app.store) می‌فرستد. آن را از درخواست‌های شبکهٔ مرورگر بخوانید و اینجا وارد کنید. پیشنهاد می‌شود به‌جای تایپ روی دستگاه، آن را هنگام ساخت برنامه در Config/Secrets.xcconfig بگذارید.": "Requests need a c-api-key: the same key the official 30nama TV web client (tv.30app.store) sends. Read it from the browser's network requests and enter it here. Instead of typing it on the device, it is better to put it in Config/Secrets.xcconfig when building the app.",
    "۱": "1",
    "۲": "2",
    "تلاش دوباره": "Try Again",

    // player
    "در حال بارگذاری…": "Loading…",
    "فایلی برای پخش پیدا نشد": "No file to play",
    "لینک پخش پیدا نشد": "Playback link not found",
    "خطای پخش: %@": "Playback error: %@",
    "قسمت بعد": "Next Episode",
    "رد کردن تیتراژ": "Skip Intro",
    "ماندن": "Stay",
    "قسمت %@": "Episode %@",
    "زیرنویس": "Subtitles",
    "کیفیت": "Quality",

    // errors
    "اتصال برقرار نشد": "Couldn't connect",
    "نشانی نامعتبر": "Invalid address",
    "خطای ناشناخته": "Unknown error",
    "دسترسی ندارید": "No access",
    "عنوان پیدا نشد": "Title not found",
    "کد QR دریافت نشد": "Couldn't get a QR code",
    "سرور سی‌نما درخواست را مسدود کرد": "The 30nama server blocked the request",
]
