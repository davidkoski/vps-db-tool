import ArgumentParser
import Foundation
import VPSDB

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

extension TableFeature: ExpressibleByArgument {
}
