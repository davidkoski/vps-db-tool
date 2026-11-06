import Foundation

/// Whether any of `texts` contains `query` -- case / diacritic insensitive.
/// An empty (or blank) query matches everything.
///
/// For filtering list rows by the toolbar search field (the text shown in
/// the row's columns).
func matchesQuery(_ query: String, _ texts: [String?]) -> Bool {
    let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !query.isEmpty else { return true }
    return texts.contains {
        $0?.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }
}
