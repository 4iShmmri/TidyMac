// TidyMac — by M.Alshmmari
//
// All text shown to the user, in Arabic and English. To add a language,
// add a case to `pick` and a column to each line.

import SwiftUI

enum Strings {
    static var isArabic: Bool { Settings.language == "ar" }
    static var direction: LayoutDirection { isArabic ? .rightToLeft : .leftToRight }

    private static func pick(_ arabic: String, _ english: String) -> String {
        isArabic ? arabic : english
    }

    static var running: String { pick("يعمل", "Running") }
    static var paused: String { pick("متوقف", "Paused") }
    static var pause: String { pick("إيقاف مؤقت", "Pause") }
    static var resume: String { pick("تشغيل", "Resume") }
    static var recent: String { pick("آخر ما رتّبته", "Recently tidied") }
    static var nothingYet: String { pick("لا شيء بعد — نزّل ملفًا وسأرتّبه", "Nothing yet — download a file and I'll sort it") }
    static var dragHint: String { pick("اسحبه إلى أي مكان، أو اضغط مطولًا لمعرفة حجمه ومكانه", "Drag it anywhere, or hold to see its size and location") }
    static var size: String { pick("الحجم", "Size") }
    static var location: String { pick("المكان", "Location") }
    static var items: String { pick("عدد الملفات", "Files") }
    static var showInFinder: String { pick("إظهار في Finder", "Show in Finder") }
    static var tidyNow: String { pick("رتّب الآن", "Tidy now") }
    static var settings: String { pick("الإعدادات", "Settings") }
    static var openAtLogin: String { pick("يعمل مع تشغيل الماك", "Open at login") }
    static var screenshotsFolder: String { pick("لقطات الشاشة في مجلد", "Screenshots in a folder") }
    static var language: String { pick("اللغة", "Language") }
    static var downloads: String { pick("التنزيلات", "Downloads") }
    static var quit: String { pick("إنهاء TidyMac", "Quit TidyMac") }

    static func categoryTitle(_ id: String) -> String {
        switch id {
        case "Documents": pick("المستندات", "Documents")
        case "Videos": pick("الفيديو", "Videos")
        case "Images": pick("الصور", "Images")
        case "Audio": pick("الصوتيات", "Audio")
        case "Archives": pick("المضغوطة", "Archives")
        case "Installers": pick("ملفات التثبيت", "Installers")
        case "Screenshots": pick("لقطات الشاشة", "Screenshots")
        default: id
        }
    }
}
