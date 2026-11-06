import Logging
import SwiftUI
import VPSDB

struct ContentView: View {
    @Bindable var document: VPSDBDocument
    @Binding var db: Database
    let ipdb: IPDB

    // per window, restored with the window across restarts
    @SceneStorage("selectedKind") private var selectedKind: GameResourceKind = .game
    @SceneStorage("innerTab") private var innerTab: ResourceKindView.InnerTab = .search

    @State private var query = ""

    var body: some View {
        TabView(selection: $selectedKind) {
            ForEach(GameResourceKind.allCases.sorted(), id: \.self) { kind in
                Tab(kind.displayName, systemImage: kind.systemImage, value: kind) {
                    ResourceKindView(
                        document: document, db: $db, ipdb: ipdb, kind: kind, query: query,
                        tab: $innerTab,
                        isSelected: selectedKind == kind)
                }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .searchable(text: $query)
        // DEBUG nav: kind / inner tab changes (ours or SwiftUI's)
        .onChange(of: selectedKind) { old, new in
            navLog.info("NAV selectedKind \(old) -> \(new)")
        }
        .onChange(of: innerTab) { old, new in
            navLog.info("NAV innerTab \(old) -> \(new)")
        }
    }
}

#Preview {
    ContentView(document: VPSDBDocument(), db: .constant(Database()), ipdb: IPDB())
}
