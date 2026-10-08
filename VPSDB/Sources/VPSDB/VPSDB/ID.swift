import Foundation

private let a = "useandom-26T198340PX75pxJACKVERYMINDBUSHWOLF_GQZbfghjklqvwyzrict"

/// Similar to nanoid: https://github.com/ai/nanoid/blob/main/nanoid.js
public func newId(_ count: Int = 10) -> String {
    (0 ..< count)
        .compactMap { _ in
            a.randomElement()
        }
        .map {
            String($0)
        }
        .joined()
}
