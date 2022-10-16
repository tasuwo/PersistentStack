//
//  Copyright ©︎ 2022 Tasuku Tozawa. All rights reserved.
//

import Combine
import Foundation

public class CloudKitSyncSettingStorage {
    enum Key: String {
        case isCloudKitSyncEnabled
    }

    // MARK: - Properties

    private let userDefaults: UserDefaults

    // MARK: - Initializers

    public init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
    }

    public convenience init?() {
        guard let userDefaults = UserDefaults(suiteName: "net.tasuwo.PersistentStack") else { return nil }
        self.init(userDefaults: userDefaults)
    }
}

extension UserDefaults {
    @objc dynamic var isCloudKitSyncEnabled: Bool {
        return bool(forKey: CloudKitSyncSettingStorage.Key.isCloudKitSyncEnabled.rawValue)
    }
}

extension CloudKitSyncSettingStorage: CloudKitSyncSettingStorable {
    // MARK: - CloudKitSyncSettingStorable

    public var isCloudKitSyncEnabled: AsyncStream<Bool> {
        AsyncStream { continuation in
            let cancellable = userDefaults.publisher(for: \.isCloudKitSyncEnabled)
                .sink { continuation.yield($0) }

            continuation.onTermination = { @Sendable _ in
                cancellable.cancel()
            }

            continuation.yield(userDefaults.isCloudKitSyncEnabled)
        }
    }

    public func set(isCloudKitSyncEnabled: Bool) {
        userDefaults.set(isCloudKitSyncEnabled, forKey: Key.isCloudKitSyncEnabled.rawValue)
    }
}
