//
//  Copyright ©︎ 2022 Tasuku Tozawa. All rights reserved.
//

import AsyncAlgorithms
import CloudKit
import Combine
import Foundation

public class PersistentStackLoader {
    // MARK: - Properties

    public var isCloudKitSyncAvailable: Bool? { _isCloudKitSyncAvailable.value }

    private let _isCloudKitSyncAvailable = CurrentValueSubject<Bool?, Never>(nil)
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
                    _isCloudKitSyncAvailable.send(status?.isAvailable)
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

    public func isCloudKitSyncAvailables() -> AsyncStream<Bool?> {
        AsyncStream { continuation in
            let cancellable = _isCloudKitSyncAvailable
                .sink { continuation.yield($0) }

            continuation.onTermination = { _ in
                cancellable.cancel()
            }
        }
    }
}

private extension CKAccountStatus {
    var isAvailable: Bool { self == .available }
}
