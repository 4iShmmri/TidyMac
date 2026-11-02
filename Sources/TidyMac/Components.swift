// TidyMac — by M.Alshmmari
//
// Small building blocks for the menu, and the glass look they share.

import SwiftUI

extension View {
    /// The frosted-glass surface used everywhere in TidyMac. Uses macOS 26's
    /// Liquid Glass when available, and a translucent material before that.
    @ViewBuilder
    func glass(cornerRadius: CGFloat = 12) -> some View {
        if #available(macOS 26, *) {
            glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
        } else {
            background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
        }
    }
}

/// A folder in the menu: click to open it in Finder, hold to see its size and path.
struct FolderTile: View {
    let title: String
    let symbol: String
    let count: Int?
    let folder: URL
    let open: () -> Void

    @State private var isHovered = false
    @State private var showsInfo = false
    @State private var pressedAt: Date?
    @State private var wasHeld = false

    private let holdTime = 0.4

    var body: some View {
        VStack(spacing: 3) {
            // Plain outline icons in the system text colour, like Finder's sidebar.
            // `.primary` turns white in dark mode on its own.
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(.primary)

            Text(title)
                .font(.system(size: 10))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(count.map(String.init) ?? " ")
                .font(.system(size: 9).monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
        .glass(cornerRadius: 10)
        .contentShape(Rectangle())
        .scaleEffect(isHovered ? 1.05 : 1)
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .onHover { isHovered = $0 }
        // One gesture for both, timed by hand: on macOS a separate tap gesture would also
        // fire when a long press is released. A short press opens; holding shows details.
        .onLongPressGesture(minimumDuration: holdTime) {
            wasHeld = true
            showsInfo = true
        } onPressingChanged: { pressing in
            if pressing {
                pressedAt = Date()
                wasHeld = false
            } else if !wasHeld, let pressedAt, Date().timeIntervalSince(pressedAt) < holdTime - 0.1 {
                // The margin matters: SwiftUI can report the release a hair before the hold
                // completes, and that must not count as a click.
                open()
            }
        }
        .popover(isPresented: $showsInfo, arrowEdge: .bottom) {
            FileInfo(file: folder)
        }
    }
}

struct RecentRow: View {
    let move: Move

    @State private var showsInfo = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: move.symbol)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 0) {
                Text(move.fileName)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(Strings.categoryTitle(move.folderName))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        // Drag the file anywhere: Finder, the Desktop, Mail, a chat window…
        .draggable(move.to)
        // Hold to see its size and where it lives.
        .onLongPressGesture(minimumDuration: 0.4) { showsInfo = true }
        .popover(isPresented: $showsInfo, arrowEdge: .trailing) {
            FileInfo(file: move.to)
        }
        .help(Strings.dragHint)
    }
}

/// Size and location of a file or folder. A folder's size is added up in the
/// background, so a big folder never freezes the menu.
struct FileInfo: View {
    let file: URL

    @State private var size: String?
    @State private var items: Int?
    @State private var copied = false

    private var isFolder: Bool { file.hasDirectoryPath }

    /// Where it lives, with the home folder shortened to "~". For a folder that's
    /// the folder itself; for a file, the folder it's in.
    private var location: String {
        let place = isFolder ? file : file.deletingLastPathComponent()
        return (place.path as NSString).abbreviatingWithTildeInPath
    }

    /// Copies the full path of the file or folder itself, ready to paste anywhere.
    private func copyPath() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(file.path, forType: .string)
        copied = true
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            copied = false
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(file.lastPathComponent)
                .font(.headline)
                .lineLimit(2)

            LabeledContent(Strings.size) {
                if let size { Text(size) } else { ProgressView().controlSize(.mini) }
            }
            if isFolder, let items {
                LabeledContent(Strings.items, value: "\(items)")
            }
            LabeledContent(Strings.location) {
                HStack(spacing: 6) {
                    Text(location)
                        .textSelection(.enabled)
                        .lineLimit(3)
                        .multilineTextAlignment(.trailing)

                    Button(action: copyPath) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .buttonStyle(.borderless)
                    .help(Strings.copyPath)
                }
            }

            Button(Strings.showInFinder) {
                NSWorkspace.shared.activateFileViewerSelecting([file])
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .font(.callout)
        .padding(14)
        .frame(width: 260)
        .environment(\.layoutDirection, Strings.direction)
        .task {
            let file = file
            let (bytes, count) = await Task.detached(priority: .userInitiated) { measure(file) }.value
            size = ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
            items = count
        }
    }
}

/// Total size in bytes, and for a folder how many files it holds (counting everything inside).
/// A folder that doesn't exist yet is simply empty.
private func measure(_ url: URL) -> (bytes: Int, files: Int) {
    guard url.hasDirectoryPath else {
        return ((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0, 1)
    }
    guard let contents = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey]) else {
        return (0, 0)
    }

    var bytes = 0, files = 0
    for case let item as URL in contents {
        let values = try? item.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
        guard values?.isRegularFile == true else { continue }
        bytes += values?.fileSize ?? 0
        files += 1
    }
    return (bytes, files)
}

/// The app's mark, which turns into a progress ring while "Tidy now" runs,
/// shows a tick when it's done, then turns back into the mark.
struct TidyButton: View {
    let state: TidyState
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                switch state {
                case .idle:
                    Image(nsImage: AppMark.template)
                        .resizable()
                        .frame(width: 18, height: 18)
                        .transition(.scale.combined(with: .opacity))
                case .working(let progress):
                    ProgressRing(progress: progress, isDone: false)
                        .transition(.scale.combined(with: .opacity))
                case .done:
                    ProgressRing(progress: 1, isDone: true)
                }
            }
            .frame(width: 24, height: 24)
            .foregroundStyle(.primary)
            .contentShape(Rectangle())
            .animation(.smooth(duration: 0.3), value: state)
        }
        .buttonStyle(.plain)
        .disabled(state != .idle)
        .help("\(Strings.tidyNow)  \(Shortcut.label)")
        .accessibilityLabel(Strings.tidyNow)
    }
}

struct ProgressRing: View {
    let progress: Double
    let isDone: Bool

    var body: some View {
        ZStack {
            Circle()
                .stroke(.quaternary, lineWidth: 2)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(.primary, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.15), value: progress)

            if isDone {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .transition(.scale.combined(with: .opacity))
            } else {
                Text("\(Int(progress * 100))")
                    .font(.system(size: 7, weight: .semibold).monospacedDigit())
                    .contentTransition(.numericText())
            }
        }
    }
}

/// Green while TidyMac is sorting, red while it's paused.
struct StatusDot: View {
    let isRunning: Bool

    private var color: Color { isRunning ? .green : .red }

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .shadow(color: color.opacity(0.6), radius: 3) // a soft glow, like a status light
            .animation(.easeInOut(duration: 0.2), value: isRunning)
            .help(isRunning ? Strings.running : Strings.paused)
            .accessibilityLabel(isRunning ? Strings.running : Strings.paused)
    }
}
