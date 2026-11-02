// TidyMac — by M.Alshmmari
//
// The engine: watches Downloads, moves each finished download into its category
// folder, and remembers recent moves for the menu.

import AppKit
import Observation

struct Move: Identifiable {
    let id = UUID()
    let from: URL
    let to: URL
    let symbol: String
    let date = Date()

    var fileName: String { to.lastPathComponent }
    var folderName: String { to.deletingLastPathComponent().lastPathComponent }
}

/// Where "Tidy now" is up to, for the progress ring on its button.
enum TidyState: Equatable {
    case idle
    case working(progress: Double)
    case done
}

@Observable
final class Organizer {
    private(set) var recent: [Move] = []
    private(set) var counts: [String: Int] = [:]
    private(set) var tidyState: TidyState = .idle

    var isPaused: Bool {
        didSet {
            Settings.isPaused = isPaused
            if !isPaused { tidyNewDownloads() }
        }
    }

    @ObservationIgnored private var watcher: FolderWatcher?
    @ObservationIgnored private var pendingCheck: DispatchWorkItem?
    private let fileManager = FileManager.default

    /// Names of files TidyMac has already looked at and decided to leave alone,
    /// starting with everything that was in Downloads when it launched.
    @ObservationIgnored private var leaveAlone: Set<String> = []
    private let launchedAt = Date()

    init() {
        isPaused = Settings.isPaused
    }

    func start() {
        // Whatever is already in Downloads is the user's business. Only "Tidy now" touches it.
        leaveAlone = Set(looseFiles(in: Places.downloads).map(\.lastPathComponent))
        watcher = FolderWatcher(folder: Places.downloads) { [weak self] in
            self?.scheduleCheck()
        }
        refreshCounts()
    }

    // MARK: - Sorting

    /// Sorts files that turned up in Downloads while TidyMac was running.
    func tidyNewDownloads() {
        guard !isPaused else { return }
        var stillDownloading = false

        for file in looseFiles(in: Places.downloads) where !leaveAlone.contains(file.lastPathComponent) {
            // Two checks, so an old file can never be mistaken for a new download:
            // its name is new to us, and macOS says it arrived after we started.
            guard let category = Category.matching(file),
                  let added = dateAdded(file), added > launchedAt else {
                leaveAlone.insert(file.lastPathComponent)
                continue
            }
            guard hasSettled(file) else {
                stillDownloading = true
                continue
            }
            if !move(file, into: category.folder, symbol: category.symbol) {
                leaveAlone.insert(file.lastPathComponent)
            }
        }

        refreshCounts()
        // Something was still being written: look again once it has had time to finish.
        if stillDownloading { scheduleCheck(after: Timing.settleSeconds) }
    }

    /// "Tidy now": sorts everything loose in Downloads, plus old screenshots on the Desktop.
    /// Moves files one by one so the button's ring can show real progress, then a tick.
    /// Works even while paused, since the user asked for it.
    @MainActor
    func tidyEverything() async {
        guard tidyState == .idle else { return }
        let jobs = everythingToTidy()
        var moved = 0
        tidyState = .working(progress: 0)

        // Spread the work over at least ~0.6s, so a quick tidy still shows the ring filling up.
        let pause = Duration.milliseconds(max(5, 600 / max(jobs.count, 1)))
        for (index, job) in jobs.enumerated() {
            if move(job.file, into: job.folder, symbol: job.symbol) { moved += 1 }
            tidyState = .working(progress: Double(index + 1) / Double(jobs.count))
            try? await Task.sleep(for: pause)
        }

        tidyState = .working(progress: 1)
        refreshCounts()
        NSSound(named: moved > 0 ? "Glass" : "Tink")?.play()

        try? await Task.sleep(for: .milliseconds(350))
        tidyState = .done
        try? await Task.sleep(for: .seconds(1.2))
        tidyState = .idle
    }

    private struct Job {
        let file: URL
        let folder: URL
        let symbol: String
    }

    private func everythingToTidy() -> [Job] {
        var jobs: [Job] = looseFiles(in: Places.downloads).compactMap { file in
            guard let category = Category.matching(file), hasSettled(file) else { return nil }
            return Job(file: file, folder: category.folder, symbol: category.symbol)
        }
        if Settings.screenshotsToFolder {
            jobs += looseFiles(in: Places.desktop).filter(isScreenshot).map {
                Job(file: $0, folder: Places.screenshots, symbol: "camera.viewfinder")
            }
        }
        return jobs
    }

    private func scheduleCheck(after delay: TimeInterval = 1) {
        pendingCheck?.cancel()
        let check = DispatchWorkItem { [weak self] in self?.tidyNewDownloads() }
        pendingCheck = check
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: check)
    }

    // MARK: - Moving

    @discardableResult
    private func move(_ file: URL, into folder: URL, symbol: String) -> Bool {
        do {
            try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
            let destination = freeName(for: file.lastPathComponent, in: folder)
            try fileManager.moveItem(at: file, to: destination)
            remember(Move(from: file, to: destination, symbol: symbol))
            NSLog("TidyMac moved \(file.lastPathComponent) to \(folder.lastPathComponent)")
            return true
        } catch {
            NSLog("TidyMac couldn't move \(file.lastPathComponent): \(error.localizedDescription)")
            return false
        }
    }

    private func remember(_ move: Move) {
        recent.insert(move, at: 0)
        if recent.count > Timing.recentLimit { recent.removeLast() }
    }

    func refreshCounts() {
        var counts: [String: Int] = [:]
        for category in Category.all {
            counts[category.id] = itemCount(in: category.folder)
        }
        counts["Screenshots"] = itemCount(in: Places.screenshots)
        self.counts = counts
    }

    // MARK: - File checks

    /// Regular, visible files directly inside a folder. Subfolders are never touched.
    private func looseFiles(in folder: URL) -> [URL] {
        let keys: [URLResourceKey] = [.isRegularFileKey, .addedToDirectoryDateKey, .contentModificationDateKey]
        let items = (try? fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles])) ?? []

        return items.filter { item in
            let isFile = (try? item.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) ?? false
            return isFile && !partialDownloadExtensions.contains(item.pathExtension.lowercased())
        }
    }

    private func hasSettled(_ file: URL) -> Bool {
        guard let modified = try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate else { return true }
        return Date().timeIntervalSince(modified) >= Timing.settleSeconds
    }

    private func dateAdded(_ file: URL) -> Date? {
        try? file.resourceValues(forKeys: [.addedToDirectoryDateKey]).addedToDirectoryDate
    }

    private func isScreenshot(_ file: URL) -> Bool {
        let name = file.lastPathComponent
        return screenshotPrefixes.contains { name.hasPrefix($0) }
    }

    /// "report.pdf", or "report (2).pdf" if that name is already taken.
    private func freeName(for name: String, in folder: URL) -> URL {
        let base = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension
        var candidate = folder.appending(path: name)
        var number = 2

        while fileManager.fileExists(atPath: candidate.path) {
            let numbered = ext.isEmpty ? "\(base) (\(number))" : "\(base) (\(number)).\(ext)"
            candidate = folder.appending(path: numbered)
            number += 1
        }
        return candidate
    }

    private func itemCount(in folder: URL) -> Int {
        (try? fileManager.contentsOfDirectory(atPath: folder.path).filter { !$0.hasPrefix(".") }.count) ?? 0
    }
}
