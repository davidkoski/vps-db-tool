import AppKit
import SwiftUI

extension View {
    /// Make the `NSTableView` backing this SwiftUI `Table` the first responder.
    ///
    /// SwiftUI's `.focused` / `@FocusState` doesn't reliably reach the
    /// underlying `NSTableView`, so this goes through AppKit directly.
    ///
    /// Focus is requested whenever the view is (re)attached to a window --
    /// e.g. first appearance, switching tabs, popping back in a
    /// `NavigationStack` -- and whenever `trigger` changes.
    func tableFocus<T: Equatable>(trigger: T) -> some View {
        background(TableFocuser(trigger: trigger))
    }
}

private struct TableFocuser<T: Equatable>: NSViewRepresentable {
    let trigger: T

    func makeNSView(context: Context) -> FocuserView {
        FocuserView()
    }

    func updateNSView(_ view: FocuserView, context: Context) {
        if context.coordinator.lastTrigger != trigger {
            context.coordinator.lastTrigger = trigger
            view.requestFocus()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(lastTrigger: trigger)
    }

    final class Coordinator {
        var lastTrigger: T
        init(lastTrigger: T) { self.lastTrigger = lastTrigger }
    }
}

final class FocuserView: NSView {

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            requestFocus()
        }
    }

    func requestFocus() {
        // let SwiftUI finish layout / transitions (and the toolbar search field
        // settle) before taking first responder
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self, let window = self.window,
                let tableView = self.nearestTableView()
            else { return }
            if window.firstResponder !== tableView {
                window.makeFirstResponder(tableView)
            }
        }
    }

    /// Walk up from this view, searching each ancestor's subtree for a visible
    /// `NSTableView` -- the first hit is the table this view is attached to.
    private func nearestTableView() -> NSTableView? {
        var ancestor = superview
        while let current = ancestor {
            if let found = Self.findTableView(in: current) {
                return found
            }
            ancestor = current.superview
        }
        return nil
    }

    private static func findTableView(in view: NSView) -> NSTableView? {
        if let table = view as? NSTableView, !table.isHiddenOrHasHiddenAncestor {
            return table
        }
        for subview in view.subviews {
            if let found = findTableView(in: subview) {
                return found
            }
        }
        return nil
    }
}
