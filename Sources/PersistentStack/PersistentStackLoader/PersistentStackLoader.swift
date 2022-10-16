//
//  Copyright ©︎ 2022 Tasuku Tozawa. All rights reserved.
//

import AsyncAlgorithms
import Combine
import Foundation

public class PersistentStackLoader {
    public enum Event {
        case forceDisabled(CloudKitAvailability.UnavailableReason)
    }

    // MARK: - Properties

    public var events: AnyPublisher<Event, Never> { _events.eraseToAnyPublisher() }
    public var _events: PassthroughSubject<Event, Never> = .init()

    private let persistentStack: PersistentStack
    private let syncSettingStorage: CloudKitSyncSettingStorable

    // MARK: - Initializers

    init(persistentStack: PersistentStack,
         syncSettingStorage: CloudKitSyncSettingStorable)
    {
        self.persistentStack = persistentStack
        self.syncSettingStorage = syncSettingStorage
    }

    // MARK: - Methods

    public func run() async throws {
        for try await (isEnabled, availability) in combineLatest(syncSettingStorage.isCloudKitSyncEnabled, CloudKitAvailabilityObserver.stream) {
            guard !isEnabled else {
                persistentStack.reconfigureIfNeeded(isCloudKitEnabled: false)
                continue
            }

            switch availability {
            case .available:
                persistentStack.reconfigureIfNeeded(isCloudKitEnabled: true)

            case let .unavailable(reason):
                persistentStack.reconfigureIfNeeded(isCloudKitEnabled: false)
                _events.send(.forceDisabled(reason))
            }
        }
    }
}
