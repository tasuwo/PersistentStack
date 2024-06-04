//
//  Copyright © 2022 Tasuku Tozawa. All rights reserved.
//

import Combine
import CoreData

public class PersistentStack {
    public typealias RemoteChangeMergeHandler = (NSPersistentContainer, [NSPersistentHistoryTransaction]) -> Void

    // MARK: - Properties

    public var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }

    public var isLoaded: Bool { persistentContainer.isLoaded }
    @Published
    public private(set) var isCloudKitSyncEnabled: Bool
    @Published
    private(set) var persistentContainer: NSPersistentContainer

    private let _reloaded: PassthroughSubject<Void, Never> = .init()
    public var reloaded: AnyPublisher<Void, Never> { _reloaded.eraseToAnyPublisher() }

    private let configuration: Configuration
    private let managedObjectModel: NSManagedObjectModel
    private let historyTracker: PersistentHistoryTracker

    // MARK: - Initializers

    public init(configuration: Configuration, isCloudKitSyncEnabled: Bool) {
        self.configuration = configuration
        self.historyTracker = PersistentHistoryTracker(author: configuration.author,
                                                       persistentHistoryTokenSaveDirectory: configuration.persistentHistoryTokenSaveDirectory,
                                                       persistentHistoryTokenFileName: configuration.persistentHistoryTokenFileName)
        self.isCloudKitSyncEnabled = isCloudKitSyncEnabled

        // `Multiple NSEntityDescriptions claim the NSManagedObject subclass` を避けるため、
        // Managed Object Model は1度のみロードする
        guard let managedObjectModel = NSManagedObjectModel(contentsOf: configuration.managedObjectModelUrl) else {
            fatalError("Unable to load Core Data Model")
        }
        self.managedObjectModel = managedObjectModel

        self.persistentContainer = Self.makeContainer(managedObjectModel: managedObjectModel,
                                                      persistentContainerName: configuration.persistentContainerName,
                                                      persistentContainerUrl: configuration.persistentContainerUrl,
                                                      isCloudKitSyncEnabled: isCloudKitSyncEnabled)
        if configuration.shouldLoadPersistentContainerAtInitialized {
            Self.loadContainer(persistentContainer, with: configuration)
        }

        historyTracker.observe(self)
    }

    // MARK: - Methods

    public func newBackgroundContext(on queue: DispatchQueue) -> NSManagedObjectContext {
        return queue.sync {
            let context = persistentContainer.newBackgroundContext()
            context.mergePolicy = configuration.mergePolicy
            context.transactionAuthor = configuration.author
            return context
        }
    }

    public func registerRemoteChangeMergeHandler(_ handler: @escaping RemoteChangeMergeHandler) {
        historyTracker.registerRemoteChangeMergeHandler(handler)
    }

    public func reconfigureIfNeeded(isCloudKitSyncEnabled: Bool) {
        guard self.isCloudKitSyncEnabled != isCloudKitSyncEnabled || !self.persistentContainer.isLoaded else { return }
        historyTracker.dispatchContainerReload { [weak self] in
            guard let self else { return }

            let newContainer: NSPersistentContainer
            let oldContainer = self.persistentContainer
            if !oldContainer.isLoaded, self.isCloudKitSyncEnabled == isCloudKitSyncEnabled {
                newContainer = oldContainer
            } else {
                newContainer = Self.makeContainer(managedObjectModel: self.managedObjectModel,
                                                  persistentContainerName: self.configuration.persistentContainerName,
                                                  persistentContainerUrl: self.configuration.persistentContainerUrl,
                                                  isCloudKitSyncEnabled: isCloudKitSyncEnabled)
            }

            Self.loadContainer(newContainer, with: self.configuration)

            self.persistentContainer = newContainer
            self.isCloudKitSyncEnabled = isCloudKitSyncEnabled
            self._reloaded.send(())

            if newContainer !== oldContainer {
                // iCloud同期中のStoreが残っていると、次回新たにiCloud同期するStoreをロードしようとした際に、"CloudKit setup failed because there
                // is another instance of this persistent store actively syncing with CloudKit in this process." という警告とともに
                // ロードに失敗してしまうため、このタイミングで明示的に削除する
                oldContainer.persistentStoreCoordinator.persistentStores.forEach {
                    try? oldContainer.persistentStoreCoordinator.remove($0)
                }
            }
        }
    }

    private static func loadContainer(_ container: NSPersistentContainer, with configuration: Configuration) {
        container.loadPersistentStores { storeDescription, error in
            guard let error = error as NSError? else { return }
            assertionFailure("Persistent store '\(storeDescription)' failed loading: \(String(describing: error))")
        }
        container.viewContext.mergePolicy = configuration.mergePolicy
        container.viewContext.transactionAuthor = configuration.author
        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    private static func makeContainer(managedObjectModel: NSManagedObjectModel,
                                      persistentContainerName: String,
                                      persistentContainerUrl: URL?,
                                      isCloudKitSyncEnabled: Bool) -> NSPersistentContainer
    {
        let container = NSPersistentCloudKitContainer(name: persistentContainerName, managedObjectModel: managedObjectModel)

        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("Failed to retrieve a persistent store description.")
        }

        if let persistentContainerUrl {
            description.url = persistentContainerUrl
        }
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true

        if !isCloudKitSyncEnabled {
            description.cloudKitContainerOptions = nil
        }

        return container
    }
}

extension NSPersistentContainer {
    var isLoaded: Bool { persistentStoreCoordinator.persistentStores.count > 0 }
}
