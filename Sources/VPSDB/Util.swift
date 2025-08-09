import Foundation

extension Collection {
    public func set<T: Hashable>() -> Set<T> where Element == T {
        Set(self)
    }
    
    public func array<T: Hashable>() -> Array<T> where Element == T {
        Array(self)
    }
    
    public func dictionary<K: Hashable, V>() -> Dictionary<K, V> where Element == (K, V) {
        Dictionary(self) { a, b in a }
    }
    
    public func grouping<K: Hashable>(by extract: (Element) -> K) -> Dictionary<K, [Element]> {
        Dictionary(grouping: self, by: extract)
    }
    
    public func grouping<K: Hashable>(by extract: (Element) -> K?) -> Dictionary<K, [Element]> {
        var result = Dictionary<K, [Element]>()
        for item in self {
            if let k = extract(item) {
                result[k, default: []].append(item)
            }
        }
        return result
    }

    public func grouping<K: Hashable, V>(by extract: (Element) -> K?, transform: (Element) -> V?) -> Dictionary<K, [V]> {
        var result = Dictionary<K, [V]>()
        for item in self {
            if let k = extract(item), let v = transform(item) {
                result[k, default: []].append(v)
            }
        }
        return result
    }
}
