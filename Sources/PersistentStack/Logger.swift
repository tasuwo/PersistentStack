//
//  Copyright ©︎ 2024 Tasuku Tozawa. All rights reserved.
//

import Foundation
import os.log

extension Logger {
    static func make() -> Logger {
        let log = OSLog(subsystem: "net.tasuwo.PersistentStack", category: "CoreData & CloudKit Event Tracking")
        return Logger(log)
    }
}
