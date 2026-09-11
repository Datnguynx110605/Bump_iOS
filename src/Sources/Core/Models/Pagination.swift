import Foundation

struct CursorPage<Item: Decodable>: Decodable {
    let items: [Item]
    let nextCursor: String?
    let hasMore: Bool
}

extension Array where Element: Identifiable {
    /// Whether `item` sits close enough to the end of this list to start fetching the
    /// next page.
    ///
    /// Deliberately a window rather than an exact tail match. Exact matching couples
    /// paging to one specific element, which breaks the moment a list is *displayed*
    /// filtered: hide the last row — a blocked author's post, say — and the only element
    /// that could ever trigger paging never appears, so the list silently stops at one
    /// page with no error and no spinner. A window is also better on its own terms,
    /// starting the fetch just before the user reaches the bottom instead of at it.
    ///
    /// `suffix` slices rather than copies, so this stays O(within) per row no matter how
    /// many pages have accumulated.
    func isNearEnd(_ item: Element, within: Int = 3) -> Bool {
        suffix(within).contains { $0.id == item.id }
    }
}
