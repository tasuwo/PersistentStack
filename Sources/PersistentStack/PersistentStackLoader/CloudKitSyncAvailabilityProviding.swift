//
//  Copyright ©︎ 2022 Tasuku Tozawa. All rights reserved.
//

public protocol CloudKitSyncAvailabilityProviding {
    var isCloudKitSyncAvailable: AsyncStream<Bool> { get }
}
