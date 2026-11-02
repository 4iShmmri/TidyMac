// TidyMac — by M.Alshmmari
//
// The panel that drops down from the menu bar.

import SwiftUI

struct MenuView: View {
    @Bindable var organizer: Organizer

    @AppStorage("language") private var language = Settings.language
    @State private var opensAtLogin = LoginItem.isOn
    @State private var screenshotsInFolder = Settings.screenshotsToFolder

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            folders
            recentMoves
            footer
        }
        .padding(14)
        .frame(width: 300)
        .environment(\.layoutDirection, Strings.direction)
        .id(language) // redraw every label when the language changes
        .onAppear {
            organizer.refreshCounts()
            opensAtLogin = LoginItem.isOn
        }
    }

    // MARK: - Sections

    private var header: some View {
        HStack {
            StatusDot(isRunning: !organizer.isPaused)

            Spacer()

            // The same on/off switch macOS uses in System Settings.
            Toggle("", isOn: Binding(
                get: { !organizer.isPaused },
                set: { organizer.isPaused = !$0 }
            ))
            .toggleStyle(.switch)
            .controlSize(.small)
            .tint(.green)
            .labelsHidden()
            .help(organizer.isPaused ? Strings.resume : Strings.pause)
        }
    }

    private var folders: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(Category.all) { category in
                FolderTile(title: category.title, symbol: category.symbol, count: organizer.counts[category.id] ?? 0, folder: category.folder) {
                    open(category.folder)
                }
            }
            FolderTile(title: Strings.categoryTitle("Screenshots"), symbol: "camera.viewfinder", count: organizer.counts["Screenshots"] ?? 0, folder: Places.screenshots) {
                open(Places.screenshots)
            }
            FolderTile(title: Strings.downloads, symbol: "arrow.down.circle", count: nil, folder: Places.downloads) {
                open(Places.downloads)
            }
        }
    }

    private var recentMoves: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(Strings.recent)
                .font(.caption)
                .foregroundStyle(.secondary)

            if organizer.recent.isEmpty {
                Text(Strings.nothingYet)
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .glass()
            } else {
                VStack(spacing: 2) {
                    ForEach(organizer.recent.prefix(4)) { move in
                        RecentRow(move: move)
                    }
                }
                .padding(4)
                .glass()
            }
        }
    }

    private var footer: some View {
        HStack {
            TidyButton(state: organizer.tidyState) {
                Task { await organizer.tidyEverything() }
            }

            Spacer()

            Menu {
                Toggle(Strings.openAtLogin, isOn: $opensAtLogin)
                Toggle(Strings.screenshotsFolder, isOn: $screenshotsInFolder)
                Picker(Strings.language, selection: $language) {
                    Text("العربية").tag("ar")
                    Text("English").tag("en")
                }
                Divider()
                Button(Strings.quit) { NSApp.terminate(nil) }
            } label: {
                Image(systemName: "gearshape.fill")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help(Strings.settings)
        }
        .onChange(of: opensAtLogin) { _, on in
            LoginItem.set(on)
        }
        .onChange(of: screenshotsInFolder) { _, on in
            Settings.screenshotsToFolder = on
            on ? ScreenshotLocation.useFolder() : ScreenshotLocation.useDesktop()
        }
    }

    private func open(_ folder: URL) {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        NSWorkspace.shared.open(folder)
    }
}
