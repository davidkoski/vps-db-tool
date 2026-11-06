import Foundation
import Observation
import SwiftUI
import UniformTypeIdentifiers

/// App-wide settings.  URLs are persisted as security-scoped bookmarks so the
/// sandboxed app keeps access to them across launches.  When nothing has been
/// chosen they fall back to a per-setting default.
@Observable
final class AppSettings {

    static let shared = AppSettings()

    private enum Key {
        static let games = "gamesURLBookmark"
        static let images = "imagesURLBookmark"
        static let cache = "cacheURLBookmark"
        static let ipdb = "ipdbURLBookmark"
    }

    /// Default location used when a directory hasn't been chosen (the app's temporary directory).
    static let defaultURL = FileManager.default.temporaryDirectory

    /// Default HTTP cache directory.  The sandbox doesn't allow writing to `/tmp` itself,
    /// so this lives in the app's temporary directory.
    static let defaultCacheURL = FileManager.default.temporaryDirectory
        .appending(path: "vpsdb-cache", directoryHint: .isDirectory)

    /// Directory containing the games (tables).
    var gamesURL: URL {
        didSet { store(gamesURL, oldValue: oldValue, key: Key.games) }
    }

    /// Directory containing images (e.g. wheel art).
    var imagesURL: URL {
        didSet { store(imagesURL, oldValue: oldValue, key: Key.images) }
    }

    /// Directory for the HTTP cache.  Created if it doesn't exist.
    var cacheURL: URL {
        didSet {
            store(cacheURL, oldValue: oldValue, key: Key.cache, defaultURL: Self.defaultCacheURL)
            Self.createDirectory(cacheURL)
        }
    }

    /// The IPDB html file (optional) -- nothing is loaded if not set.
    var ipdbURL: URL? {
        didSet { storeOptional(ipdbURL, oldValue: oldValue, key: Key.ipdb) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.gamesURL = Self.resolve(key: Key.games, defaults: defaults) ?? Self.defaultURL
        self.imagesURL = Self.resolve(key: Key.images, defaults: defaults) ?? Self.defaultURL
        self.cacheURL = Self.resolve(key: Key.cache, defaults: defaults) ?? Self.defaultCacheURL
        self.ipdbURL = Self.resolve(key: Key.ipdb, defaults: defaults)
        Self.createDirectory(cacheURL)
    }

    private static func createDirectory(_ url: URL) {
        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        } catch {
            print("unable to create directory \(url): \(error)")
        }
    }

    private func store(
        _ url: URL, oldValue: URL, key: String, defaultURL: URL = AppSettings.defaultURL
    ) {
        guard url != oldValue else { return }
        if oldValue != defaultURL {
            oldValue.stopAccessingSecurityScopedResource()
        }

        // the default needs no bookmark -- the app always has access to it
        guard url != defaultURL else {
            defaults.removeObject(forKey: key)
            return
        }
        do {
            let data = try url.bookmarkData(
                options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            defaults.set(data, forKey: key)
            _ = url.startAccessingSecurityScopedResource()
        } catch {
            print("unable to create bookmark for \(url): \(error)")
        }
    }

    /// Store an optional url: `nil` removes the bookmark.
    private func storeOptional(_ url: URL?, oldValue: URL?, key: String) {
        guard url != oldValue else { return }
        oldValue?.stopAccessingSecurityScopedResource()

        guard let url else {
            defaults.removeObject(forKey: key)
            return
        }
        do {
            let data = try url.bookmarkData(
                options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            defaults.set(data, forKey: key)
            _ = url.startAccessingSecurityScopedResource()
        } catch {
            print("unable to create bookmark for \(url): \(error)")
        }
    }

    private static func resolve(key: String, defaults: UserDefaults) -> URL? {
        guard let data = defaults.data(forKey: key) else { return nil }
        do {
            var stale = false
            let url = try URL(
                resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil,
                bookmarkDataIsStale: &stale)
            _ = url.startAccessingSecurityScopedResource()
            if stale, let fresh = try? url.bookmarkData(options: .withSecurityScope) {
                defaults.set(fresh, forKey: key)
            }
            return url
        } catch {
            print("unable to resolve bookmark \(key): \(error)")
            return nil
        }
    }
}

struct SettingsView: View {
    @Bindable var settings: AppSettings

    var body: some View {
        Form {
            URLPickerRow(
                title: "Games", prompt: "Choose the games folder",
                url: $settings.gamesURL, contentTypes: [.folder])

            URLPickerRow(
                title: "Images", prompt: "Choose the images folder",
                url: $settings.imagesURL, contentTypes: [.folder])

            URLPickerRow(
                title: "Cache", prompt: "Choose the HTTP cache folder",
                url: $settings.cacheURL, contentTypes: [.folder],
                defaultURL: AppSettings.defaultCacheURL)

            OptionalURLPickerRow(
                title: "IPDB", prompt: "Choose the IPDB html file",
                url: $settings.ipdbURL, contentTypes: [.html])
        }
        .formStyle(.grouped)
        .frame(width: 500)
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct URLPickerRow: View {
    let title: LocalizedStringKey
    let prompt: LocalizedStringKey
    @Binding var url: URL
    let contentTypes: [UTType]
    var defaultURL = AppSettings.defaultURL

    @State private var isPresented = false

    private var isDefault: Bool { url == defaultURL }

    var body: some View {
        LabeledContent(title) {
            HStack {
                Text(url.path(percentEncoded: false))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(url.path(percentEncoded: false))
                    .textSelection(.enabled)
                    .foregroundStyle(isDefault ? .secondary : .primary)

                Spacer()

                Button("Choose…") { isPresented = true }
                if !isDefault {
                    Button("Reset to Default", systemImage: "xmark.circle.fill") {
                        url = defaultURL
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                }
            }
        }
        .fileImporter(isPresented: $isPresented, allowedContentTypes: contentTypes) { result in
            if case .success(let selected) = result {
                // keep access long enough for AppSettings to create the bookmark
                let accessing = selected.startAccessingSecurityScopedResource()
                url = selected
                if accessing { selected.stopAccessingSecurityScopedResource() }
            }
        }
        .fileDialogMessage(prompt)
    }
}

/// Picker for an optional file / folder -- can be cleared.
private struct OptionalURLPickerRow: View {
    let title: LocalizedStringKey
    let prompt: LocalizedStringKey
    @Binding var url: URL?
    let contentTypes: [UTType]

    @State private var isPresented = false

    var body: some View {
        LabeledContent(title) {
            HStack {
                if let url {
                    Text(url.path(percentEncoded: false))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(url.path(percentEncoded: false))
                        .textSelection(.enabled)
                } else {
                    Text("Not set")
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Choose…") { isPresented = true }
                if url != nil {
                    Button("Clear", systemImage: "xmark.circle.fill") {
                        url = nil
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                }
            }
        }
        .fileImporter(isPresented: $isPresented, allowedContentTypes: contentTypes) { result in
            if case .success(let selected) = result {
                // keep access long enough for AppSettings to create the bookmark
                let accessing = selected.startAccessingSecurityScopedResource()
                url = selected
                if accessing { selected.stopAccessingSecurityScopedResource() }
            }
        }
        .fileDialogMessage(prompt)
    }
}

#Preview {
    SettingsView(settings: AppSettings(defaults: UserDefaults(suiteName: "preview")!))
}
