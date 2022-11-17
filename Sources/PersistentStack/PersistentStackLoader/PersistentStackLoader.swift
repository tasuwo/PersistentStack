//
//  Copyright ©︎ 2022 Tasuku Tozawa. All rights reserved.
//

import AsyncAlgorithms
import CloudKit
import Combine
import Foundation

public class PersistentStackLoader {
    // MARK: - Properties

    @Published public private(set) var isCKAccountAvailable: Bool?
    private let persistentStack: PersistentStack
    private let availabilityProvider: CloudKitSyncAvailabilityProviding

    // MARK: - Initializers

    public init(persistentStack: PersistentStack,
                availabilityProvider: CloudKitSyncAvailabilityProviding)
    {
        self.persistentStack = persistentStack
        self.availabilityProvider = availabilityProvider
    }

    // MARK: - Methods

    public func run() -> Task<Void, Never> {
        return Task {
            for await (isEnabled, status) in combineLatest(availabilityProvider.isCloudKitSyncAvailable.removeDuplicates(),
                                                           CKAccountStatus.ps.stream.removeDuplicates())
            {
                defer {
                    isCKAccountAvailable = status?.isAvailable
                }

                guard isEnabled else {
                    persistentStack.reconfigureIfNeeded(isCloudKitEnabled: false)
                    continue
                }

                switch status {
                case .available:
                    persistentStack.reconfigureIfNeeded(isCloudKitEnabled: true)

                case .none:
                    // NOP
                    break

                default:
                    persistentStack.reconfigureIfNeeded(isCloudKitEnabled: false)
                }
            }
        }
    }
}

private extension CKAccountStatus {
    var isAvailable: Bool { self == .available }
}
