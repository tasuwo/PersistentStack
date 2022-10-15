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

    @Published
    public private(set) var isCloudKitEnabled: Bool
    @Published
    private(set) var persistentContainer: NSPersistentContainer

    private let _reloaded: PassthroughSubject<Void, Never> = .init()
    public var reloaded: AnyPublisher<Void, Never> { _reloaded.eraseToAnyPublisher() }

    private let configuration: Configuration
    private let historyTracker: PersistentHistoryTracker

    // MARK: - Initializers

    public init(configuration: Configuration, isCloudKitEnabled: Bool, mergeHandler: RemoteChangeMergeHandler?) {
        self.configuration = configuration
        self.historyTracker = PersistentHistoryTracker(author: configuration.author,
                                                       persistentHistoryTokenSaveDirectory: configuration.persistentHistoryTokenSaveDirectory,
                                                       persistentHistoryTokenFileName: configuration.persistentHistoryTokenFileName,
                                                       onMergeRemoteChanges: mergeHandler ?? PersistentHistoryTracker.defaultMergeHandler)
        self.isCloudKitEnabled = isCloudKitEnabled
        self.persistentContainer = Self.makeContainer(managedObjectModelUrl: configuration.managedObjectModelUrl,
                                                      persistentContainerName: configuration.persistentContainerName,
                                                      persistentContainerUrl: configuration.persistentContainerUrl,
                                                      isCloudKitEnabled: isCloudKitEnabled)

        historyTracker.observe(self)
        loadContainer()
    }

    // MARK: - Methods

    public func newBackgroundContext(on queue: DispatchQueue) -> NSManagedObjectContext {
        return queue.sync {
            let context = persistentContainer.newBackgroundContext()
            context.mergePolicy = configuration.mergePoicy
            context.transactionAuthor = configuration.author
            return context
        }
    }

    public func reconfigure(isCloudKitEnabled: Bool) {
        guard self.isCloudKitEnabled != isCloudKitEnabled else { return }
        historyTracker.dispatchContainerReload { [weak self] in
            guard let self else { return }

            let container = Self.makeContainer(managedObjectModelUrl: self.configuration.managedObjectModelUrl,
                                               persistentContainerName: self.configuration.persistentContainerName,
                                               persistentContainerUrl: self.configuration.persistentContainerUrl,
                                               isCloudKitEnabled: isCloudKitEnabled)

            // iCloud同期中のStoreが残っていると新たなiCloud同期Storeをロードしようとした際に失敗してしまうので、
            // このタイミングで明示的に削除する
            self.persistentContainer.persistentStoreCoordinator.persistentStores.forEach {
                try? self.persistentContainer.persistentStoreCoordinator.remove($0)
            }

            self.loadContainer()

            self.persistentContainer = container
            self.isCloudKitEnabled = isCloudKitEnabled
            self._reloaded.send(())
        }
    }

    private func loadContainer() {
        persistentContainer.loadPersistentStores { storeDescription, error in
            guard let error = error as NSError? else { return }
            assertionFailure("Persistent store '\(storeDescription)' failed loading: \(String(describing: error))")
        }
        persistentContainer.viewContext.mergePolicy = configuration.mergePoicy
        persistentContainer.viewContext.automaticallyMergesChangesFromParent = true
    }

    private static func makeContainer(managedObjectModelUrl: URL,
                                      persistentContainerName: String,
                                      persistentContainerUrl: URL?,
                                      isCloudKitEnabled: Bool) -> NSPersistentContainer
    {
        guard let model = NSManagedObjectModel(contentsOf: managedObjectModelUrl) else {
            fatalError("Unable to load Core Data Model")
        }
        let container = NSPersistentCloudKitContainer(name: persistentContainerName, managedObjectModel: model)

        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("Failed to retrieve a persistent store description.")
        }

        #if os(iOS)
        description.url = persistentContainerUrl
        #endif
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true

        if !isCloudKitEnabled {
            description.cloudKitContainerOptions = nil
        }

        return container
    }
}
