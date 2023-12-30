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
    private let settingStorage: CloudKitSyncSettingStorage

    // MARK: - Initializers

    public init(persistentStack: PersistentStack,
                settingStorage: CloudKitSyncSettingStorage)
    {
        self.persistentStack = persistentStack
        self.settingStorage = settingStorage
    }

    // MARK: - Methods

    public func run() -> Task<Void, Never> {
        return Task {
            for await (isEnabled, status) in combineLatest(settingStorage.isCloudKitSyncEnabled.removeDuplicates(),
                                                           CKAccountStatus.stream.removeDuplicates())
            {
                defer {
                    isCKAccountAvailable = status?.isAvailable
                }

                guard isEnabled else {
                    persistentStack.reconfigureIfNeeded(isCloudKitSyncEnabled: false)
                    continue
                }

                switch status {
                case .available:
                    persistentStack.reconfigureIfNeeded(isCloudKitSyncEnabled: true)

                case .none:
                    // NOP
                    break

                default:
                    persistentStack.reconfigureIfNeeded(isCloudKitSyncEnabled: false)
                }
            }
        }
    }
}

private extension CKAccountStatus {
    var isAvailable: Bool { self == .available }
}
