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
    private let syncSettingStorage: CloudKitSyncSettingStorable

    // MARK: - Initializers

    public init(persistentStack: PersistentStack,
                syncSettingStorage: CloudKitSyncSettingStorable)
    {
        self.persistentStack = persistentStack
        self.syncSettingStorage = syncSettingStorage
    }

    // MARK: - Methods

    public func run() -> Task<Void, Never> {
        return Task {
            for await (isEnabled, status) in combineLatest(syncSettingStorage.isCloudKitSyncEnabled.removeDuplicates(),
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
