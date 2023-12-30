//
//  Copyright ©︎ 2022 Tasuku Tozawa. All rights reserved.
//

public protocol CloudKitSyncSettingStorage {
    var isCloudKitSyncEnabled: AsyncStream<Bool> { get }
}
