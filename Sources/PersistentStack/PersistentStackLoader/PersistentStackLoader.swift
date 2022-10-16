//
//  Copyright ©︎ 2022 Tasuku Tozawa. All rights reserved.
//

import AsyncAlgorithms
import CloudKit
import Combine
import Foundation

public class PersistentStackLoader {
    public enum Event {
        case forceDisabled(CKAccountStatus?)
    }

    // MARK: - Properties

    public var events: AnyPublisher<Event, Never> { _events.eraseToAnyPublisher() }
    public var _events: PassthroughSubject<Event, Never> = .init()

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
            for await (isEnabled, status) in combineLatest(syncSettingStorage.isCloudKitSyncEnabled, CKAccountStatus.ps.stream) {
                guard !isEnabled else {
                    persistentStack.reconfigureIfNeeded(isCloudKitEnabled: false)
                    continue
                }

                switch status {
                case .available:
                    persistentStack.reconfigureIfNeeded(isCloudKitEnabled: true)

                default:
                    persistentStack.reconfigureIfNeeded(isCloudKitEnabled: false)
                    _events.send(.forceDisabled(status))
                }
            }
        }
    }
}
