import Logging
import SwiftUI
import VPSDB

/// Content for a single ``GameResourceKind`` tab.
///
/// Holds functionality shared by every kind (the inner tabs, starting with
/// search), with ``kindSpecificContent`` providing a place for per-kind behavior.
struct ResourceKindView: View {
    @Bindable var document: VPSDBDocument
    @Binding var db: Database
    let ipdb: IPDB
    let kind: GameResourceKind
    let query: String

    /// Selected inner tab -- owned by ContentView so it is shared across kinds.
    @Binding var tab: InnerTab

    /// Whether this kind's tab is the selected one -- TabView keeps the
    /// other tabs' views (and their state) alive.
    var isSelected = true

    enum InnerTab: String, Hashable {
        case search
        case updates
        case checks
    }

    /// The kind's navigation path -- Search, Updates and Checks all push here.
    @State private var path = [KindRoute]()

    var body: some View {
        // one stack for the kind, with the inner tabs as its root -- see KindRoute
        // DEBUG nav: log writes made by the NavigationStack itself (back button)
        NavigationStack(
            path: Binding {
                path
            } set: { new in
                navLog.info(
                    "NAV [\(kind)] STACK wrote path: \(path.map(\.debugName)) -> \(new.map(\.debugName))"
                )
                path = new
            }
        ) {
            VStack(alignment: .leading, spacing: 12) {
                TabView(selection: $tab) {
                    Tab("Search", systemImage: "magnifyingglass", value: .search) {
                        SearchResultsView(db: db, kind: kind, query: query) { result in
                            path.append(.resource(ResourceRoute(result)))
                        }
                    }

                    Tab("Updates", systemImage: "arrow.triangle.2.circlepath", value: .updates) {
                        UpdatesView(
                            document: document, db: $db, ipdb: ipdb, kind: kind,
                            isActive: isSelected, query: query, path: $path
                        )
                    }

                    Tab("Checks", systemImage: "checklist", value: .checks) {
                        ChecksView(
                            document: document, db: $db, kind: kind, query: query, path: $path)
                    }
                }
                // otherwise inherits .sidebarAdaptable from ContentView's TabView
                .tabViewStyle(.tabBarOnly)

                kindSpecificContent
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .navigationTitle(kind.displayName)
            // DEBUG nav: all path changes (ours and the stack's)
            .onChange(of: path) { old, new in
                navLog.info(
                    "NAV [\(kind)] path \(old.map(\.debugName)) -> \(new.map(\.debugName))")
            }
            // DEBUG nav: which kind's root is on screen
            .onAppear { navLog.info("NAV [\(kind)] appear root, path \(path.map(\.debugName))") }
            .onDisappear {
                navLog.info("NAV [\(kind)] disappear root, path \(path.map(\.debugName))")
            }
            .navigationDestination(for: KindRoute.self) { route in
                Group {
                    switch route.screen {
                    case .resource(let resource):
                        ResourceDetailView(db: $db, route: resource, path: $path)
                    case .view(_, let content):
                        content()
                    }
                }
                // DEBUG nav: which kind's pushed screens are on screen
                .onAppear { navLog.info("NAV [\(kind)] appear \(route.debugName)") }
                .onDisappear { navLog.info("NAV [\(kind)] disappear \(route.debugName)") }
            }
        }
        // for pushed screens too (e.g. splitting a resource into a new game)
        .environment(\.ipdb, ipdb)
    }

    @ViewBuilder
    private var kindSpecificContent: some View {
        switch kind {
        case .game:
            EmptyView()
        case .table:
            EmptyView()
        case .b2s:
            EmptyView()
        case .tutorial:
            EmptyView()
        case .rom:
            EmptyView()
        case .pupPack:
            EmptyView()
        case .altColor:
            EmptyView()
        case .altSound:
            EmptyView()
        case .pov:
            EmptyView()
        case .wheelArt:
            EmptyView()
        case .topper:
            EmptyView()
        case .mediaPack:
            EmptyView()
        case .rule:
            EmptyView()
        case .sound:
            EmptyView()
        }
    }
}

extension GameResourceKind {
    var displayName: LocalizedStringKey {
        switch self {
        case .game: "Games"
        case .table: "Tables"
        case .b2s: "Backglasses"
        case .tutorial: "Tutorials"
        case .rom: "ROMs"
        case .pupPack: "PuP Packs"
        case .altColor: "Alt Color"
        case .altSound: "Alt Sound"
        case .pov: "POV"
        case .wheelArt: "Wheel Art"
        case .topper: "Toppers"
        case .mediaPack: "Media Packs"
        case .rule: "Rules"
        case .sound: "Sounds"
        }
    }

    var systemImage: String {
        switch self {
        case .game: "gamecontroller"
        case .table: "tablecells"
        case .b2s: "photo.on.rectangle"
        case .tutorial: "play.rectangle"
        case .rom: "memorychip"
        case .pupPack: "film.stack"
        case .altColor: "paintpalette"
        case .altSound: "speaker.wave.2"
        case .pov: "eye"
        case .wheelArt: "circle.circle"
        case .topper: "rectangle.topthird.inset.filled"
        case .mediaPack: "shippingbox"
        case .rule: "list.bullet.rectangle"
        case .sound: "music.note"
        }
    }
}

#Preview {
    ResourceKindView(
        document: VPSDBDocument(), db: .constant(Database()), ipdb: IPDB(), kind: .table,
        query: "",
        tab: .constant(.search))
}
