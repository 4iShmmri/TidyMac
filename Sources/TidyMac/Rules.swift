// TidyMac — by M.Alshmmari
//
// Every sorting rule lives in this file. To teach TidyMac a new kind of file,
// add an extension to one of the categories below, or add a new category to `all`.

import Carbon.HIToolbox
import Foundation

/// The keyboard shortcut that runs "Tidy now" from anywhere: ⌃⌥T.
/// (⌘T is left alone: it's "new tab" in almost every app.)
enum Shortcut {
    static let keyCode = UInt32(kVK_ANSI_T)
    static let modifiers = UInt32(controlKey | optionKey)
    static let label = "⌃⌥T"
}

struct Category: Identifiable, Hashable {
    /// Also the name of the folder created inside Downloads.
    let id: String
    let symbol: String
    let extensions: Set<String>

    var folder: URL { Places.downloads.appending(path: id, directoryHint: .isDirectory) }
    var title: String { Strings.categoryTitle(id) }

    // Only the file types most people actually download. Anything else stays where it is.

    static let documents = Category(id: "Documents", symbol: "doc", extensions: [
        "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx",
        "pages", "numbers", "key", "txt", "rtf", "csv", "epub",
    ])

    static let videos = Category(id: "Videos", symbol: "film", extensions: [
        "mp4", "mov", "m4v", "mkv", "avi", "webm",
    ])

    static let images = Category(id: "Images", symbol: "photo", extensions: [
        "jpg", "jpeg", "png", "gif", "heic", "webp", "svg",
    ])

    static let audio = Category(id: "Audio", symbol: "music.note", extensions: [
        "mp3", "m4a", "wav", "aac", "flac",
    ])

    static let archives = Category(id: "Archives", symbol: "archivebox", extensions: [
        "zip", "rar", "7z", "tar", "gz",
    ])

    static let installers = Category(id: "Installers", symbol: "shippingbox", extensions: [
        "dmg", "pkg", "iso",
    ])

    /// The order the tiles appear in the menu.
    static let all: [Category] = [documents, videos, images, audio, archives, installers]

    static func matching(_ file: URL) -> Category? {
        let ext = file.pathExtension.lowercased()
        return all.first { $0.extensions.contains(ext) }
    }
}

enum Places {
    static let downloads = FileManager.default.homeDirectoryForCurrentUser.appending(path: "Downloads", directoryHint: .isDirectory)
    static let desktop = FileManager.default.homeDirectoryForCurrentUser.appending(path: "Desktop", directoryHint: .isDirectory)
    static let screenshots = desktop.appending(path: "Screenshots", directoryHint: .isDirectory)
}

enum Timing {
    /// A file has to sit untouched this long before it's moved, so we never grab a download mid-write.
    static let settleSeconds: TimeInterval = 3
    /// How many recent moves the menu remembers.
    static let recentLimit = 20
}

/// Browsers write to these while a download is still in progress. We leave them alone.
let partialDownloadExtensions: Set<String> = ["crdownload", "download", "part", "partial", "tmp", "opdownload"]

/// What macOS names screenshots and screen recordings, in English and Arabic.
let screenshotPrefixes = ["Screenshot", "Screen Shot", "Screen Recording", "لقطة شاشة", "تسجيل الشاشة"]
