import Logging
import SwiftUI
import VPSDB

// DEBUG nav
let navLog = Logger(label: "NAV")

/// A screen pushed on a kind's navigation stack -- the one route type for
/// Search, Updates and Checks, which share a single `NavigationStack` per kind
/// (see ``ResourceKindView``).
///
/// One stack per kind with plain pushes / pops: separate stacks for Search,
/// Updates and Checks (in a TabView inside the sidebar-adaptable TabView) got
/// confused by SwiftUI -- pops ignored, back writing another stack's path, and
/// a crash comparing paths of different types (`comparisonTypeMismatch`).
struct KindRoute: Hashable {
    enum Screen {
        /// A resource's detail view (with in-place Edit) or, if
        /// `editing`, its editor -- see ``ResourceDetailView``.
        case resource(ResourceRoute)

        /// A feature-specific screen (game picker, create editor, a check's
        /// proposal ...) built by the view that pushes it.  `tag` identifies
        /// the kind of screen, e.g. to pop back to it.
        case view(tag: String, content: () -> AnyView)
    }

    /// Identity -- each push is a distinct screen.
    let id = UUID()
    let screen: Screen

    static func resource(_ route: ResourceRoute) -> KindRoute {
        KindRoute(screen: .resource(route))
    }

    static func view<Content: View>(
        _ tag: String, @ViewBuilder content: @escaping () -> Content
    ) -> KindRoute {
        KindRoute(screen: .view(tag: tag, content: { AnyView(content()) }))
    }

    var resourceRoute: ResourceRoute? {
        if case .resource(let route) = screen { route } else { nil }
    }

    var tag: String? {
        if case .view(let tag, _) = screen { tag } else { nil }
    }

    // DEBUG nav
    var debugName: String {
        switch screen {
        case .resource(let route):
            "\(route.kind.rawValue):\(route.id)\(route.editing ? "(edit)" : "")"
        case .view(let tag, _): tag
        }
    }

    static func == (lhs: KindRoute, rhs: KindRoute) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
