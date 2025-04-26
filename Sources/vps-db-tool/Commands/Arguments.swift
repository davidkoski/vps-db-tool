import Foundation
import ArgumentParser

extension URL: @retroactive ExpressibleByArgument {
    public init?(argument: String) {
        if argument.contains("://") {
            self.init(string: argument)
        } else {
            self.init(filePath: argument)
        }
    }
}

extension GameResourceKind: ExpressibleByArgument {
}
