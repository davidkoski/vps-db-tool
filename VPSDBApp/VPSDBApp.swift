import AppKit
import Logging
import SwiftUI
import VPSDB

private let log = Logger(label: "VPSDBApp")

let scanCache = ScanCache()

/// Write the scan cache (if changed) -- `reason` is for the log.
private func saveScanCache(_ reason: String) async {
    do {
        log.info("saving ScanCache: \(reason)")
        try await scanCache.save()
    } catch {
        log.error("unable to save ScanCache: \(error)")
    }
}

/// Saves the scan cache periodically while the app is active, and when the
/// app is hidden or quits.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    /// How often to save while the app is active.
    private static let saveInterval = Duration.seconds(30 * 60)

    private var periodicSave: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // a single loop that skips saving while inactive -- restarting a timer
        // on each activation would never fire if the app is switched often
        periodicSave = Task {
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: Self.saveInterval)
                } catch {
                    return
                }
                if NSApp.isActive {
                    await saveScanCache("periodic")
                }
            }
        }
    }

    func applicationDidHide(_ notification: Notification) {
        Task {
            await saveScanCache("hide")
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        periodicSave?.cancel()
        // save is async (an actor) -- terminate once it's written
        Task {
            await saveScanCache("quit")
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}

@main struct VPSDBApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    @State private var settings = AppSettings.shared

    @State private var db: Database
    @State private var ipdb: IPDB

    init() {
        _db = State(initialValue: try! Database.load(directory: AppSettings.shared.gamesURL))

        if let ipdbURL = AppSettings.shared.ipdbURL {
            _ipdb = State(initialValue: try! IPDB(html: ipdbURL))
        } else {
            _ipdb = State(initialValue: IPDB())
        }

        Task {
            do {
                try await scanCache.load(
                    url: AppSettings.shared.cacheURL.appending(path: "scanCache.json"))
            } catch {
                log.error("unable to load ScanCache: \(error)")
            }
        }
    }

    var body: some Scene {
        DocumentGroup { document in
            ContentView(document: document, db: $db, ipdb: ipdb)
                .environment(settings)
        } makeDocument: { _, _ in
            VPSDBDocument()
        }
        .onChange(of: settings.gamesURL) { oldValue, newValue in
            db = try! Database.load(directory: newValue)
        }

        Settings {
            SettingsView(settings: settings)
        }
    }
}
