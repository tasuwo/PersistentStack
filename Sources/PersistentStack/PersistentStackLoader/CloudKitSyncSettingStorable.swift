//
//  Copyright ©︎ 2022 Tasuku Tozawa. All rights reserved.
//

public protocol CloudKitSyncSettingStorable {
    var isCloudKitSyncEnabled: AsyncStream<Bool> { get }
    func set(isCloudKitSyncEnabled: Bool)
}
