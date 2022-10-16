//
//  Copyright ©︎ 2022 Tasuku Tozawa. All rights reserved.
//

public enum CloudKitAvailability {
    public enum UnavailableReason {
        case couldNotDetermine
        case restricted
        case noAccount
        case temporarilyUnavailable
        case unknown
    }

    case available
    case unavailable(UnavailableReason)
}
