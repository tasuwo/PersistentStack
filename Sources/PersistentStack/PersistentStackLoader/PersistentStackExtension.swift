//
//  Copyright ©︎ 2022 Tasuku Tozawa. All rights reserved.
//

import Foundation

public struct PersistentStackExtension<Base> {
    public let base: Base

    public init(_ base: Base) {
        self.base = base
    }
}

public protocol PersistentStackExtended {
    associatedtype Base

    static var ps: PersistentStackExtension<Base>.Type { get set }
    var ps: PersistentStackExtension<Base> { get set }
}

public extension PersistentStackExtended {
    static var ps: PersistentStackExtension<Self>.Type {
        get { PersistentStackExtension<Self>.self }
        // swiftlint:disable:next unused_setter_value
        set {}
    }

    var ps: PersistentStackExtension<Self> {
        get { PersistentStackExtension(self) }
        // swiftlint:disable:next unused_setter_value
        set {}
    }
}
