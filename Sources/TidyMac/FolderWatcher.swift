// TidyMac — by M.Alshmmari

import Foundation

/// Calls `onChange` whenever something is added, removed or renamed inside a folder.
/// It only watches the folder itself, not what's inside its subfolders.
final class FolderWatcher {
    private let source: DispatchSourceFileSystemObject

    init?(folder: URL, onChange: @escaping () -> Void) {
        let descriptor = open(folder.path, O_EVTONLY)
        guard descriptor >= 0 else { return nil }

        source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: .write, queue: .main)
        source.setEventHandler(handler: onChange)
        source.setCancelHandler { close(descriptor) }
        source.resume()
    }

    deinit {
        source.cancel()
    }
}
