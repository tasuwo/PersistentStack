//
//  Copyright © 2022 Tasuku Tozawa. All rights reserved.
//

import Combine
import CoreData
import os.log

private let log = OSLog(subsystem: "net.tasuwo.PersistentStack", category: "CoreData&CloudKit Event Tracking")

public class PersistentStackMonitor {
    private let notificationCenter: NotificationCenter
    private var cancellable: AnyCancellable?

    // MARK: - Initializers

    public init(notificationCenter: NotificationCenter = .default) {
        self.notificationCenter = notificationCenter
    }

    // MARK: - Methods

    public func startMonitoring() {
        cancellable = notificationCenter
            .publisher(for: NSPersistentCloudKitContainer.eventChangedNotification)
            .sink { notification in
                guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey] as? NSPersistentCloudKitContainer.Event else {
                    return
                }

                let logger = Logger(log)
                switch event.type {
                case .setup:
                    logger.log(level: .debug, "Setup \(event.isStarted ? "started" : "ended", privacy: .public)")

                case .import:
                    logger.log(level: .debug, "Import \(event.isStarted ? "started" : "ended", privacy: .public)")

                case .export:
                    logger.log(level: .debug, "Export \(event.isStarted ? "started" : "ended", privacy: .public)")

                @unknown default:
                    logger.log(level: .debug, "Unknown NSPersistentCloudKitContainer.Event: \(event.type.rawValue, privacy: .public)")
                }

                if let error = event.error {
                    logger.log(level: .error, "Failed to iCloud Sync: \(error.localizedDescription)")
                }
            }
    }
}

private extension NSPersistentCloudKitContainer.Event {
    var isStarted: Bool {
        return self.endDate == nil
    }
}
