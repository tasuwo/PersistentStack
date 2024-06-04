//
//  Copyright ©︎ 2022 Tasuku Tozawa. All rights reserved.
//

import CoreData

public extension PersistentStack {
    struct Configuration {
        public var author: String
        public var persistentContainerName: String = "PersistentStack"
        public var persistentContainerUrl: URL?
        public var managedObjectModelUrl: URL
        public var mergePolicy: NSMergePolicy = .mergeByPropertyObjectTrump
        public var persistentHistoryTokenSaveDirectory = NSPersistentContainer
            .defaultDirectoryURL()
            .appendingPathComponent("PersistentHistoryTokens", isDirectory: true)
        public var persistentHistoryTokenFileName: String
        public var shouldLoadPersistentContainerAtInitialized = false
        public var initializeCloudKitContainer = false

        public init(author: String,
                    persistentContainerName: String,
                    managedObjectModelUrl: URL)
        {
            self.author = author
            self.persistentHistoryTokenFileName = "\(author)-last-token.data"
            self.persistentContainerName = persistentContainerName
            self.managedObjectModelUrl = managedObjectModelUrl
        }
    }
}
