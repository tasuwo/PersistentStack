//
//  Copyright © 2022 Tasuku Tozawa. All rights reserved.
//

import Combine
import CoreData

class PersistentHistoryTracker {
    // MARK: - Properties

    private var lastHistoryToken: NSPersistentHistoryToken? {
        didSet {
            guard let token = lastHistoryToken,
                  let data = try? NSKeyedArchiver.archivedData(withRootObject: token,
                                                               requiringSecureCoding: true)
            else {
                return
            }

            try? data.write(to: tokenFile)
        }
    }

    private lazy var tokenFile: URL = {
        if !FileManager.default.fileExists(atPath: persistentHistoryTokenSaveDirectory.path) {
            // swiftlint:disable:next force_try
            try! FileManager.default.createDirectory(at: persistentHistoryTokenSaveDirectory,
                                                     withIntermediateDirectories: true,
                                                     attributes: nil)
        }
        return persistentHistoryTokenSaveDirectory
            .appendingPathComponent(persistentHistoryTokenFileName, isDirectory: false)
    }()

    private lazy var historyQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        return queue
    }()

    private let author: String
    private let notificationCenter: NotificationCenter
    private let persistentHistoryTokenSaveDirectory: URL
    private let persistentHistoryTokenFileName: String

    private var onMergeRemoteChanges: PersistentStack.RemoteChangeMergeHandler?
    private var persistentContainerObservationCancellable: AnyCancellable?
    private var remoteChangeObservationCancellable: AnyCancellable?

    // MARK: - Initializers

    init(author: String,
         persistentHistoryTokenSaveDirectory: URL,
         persistentHistoryTokenFileName: String,
         notificationCenter: NotificationCenter = .default)
    {
        self.author = author
        self.persistentHistoryTokenSaveDirectory = persistentHistoryTokenSaveDirectory
        self.persistentHistoryTokenFileName = persistentHistoryTokenFileName
        self.notificationCenter = notificationCenter

        if let tokenData = try? Data(contentsOf: tokenFile) {
            lastHistoryToken = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSPersistentHistoryToken.self,
                                                                       from: tokenData)
        }
    }

    // MARK: - Methods

    func observe(_ container: PersistentStack) {
        persistentContainerObservationCancellable = container.$persistentContainer
            .sink { [weak self] persistentContainer in
                guard let self else { return }
                self.remoteChangeObservationCancellable = self.notificationCenter
                    .publisher(for: .NSPersistentStoreRemoteChange,
                               object: persistentContainer.persistentStoreCoordinator)
                    .sink { _ in self.mergeRemoteChanges(to: persistentContainer) }
            }
    }

    func dispatchContainerReload(_ block: @escaping () -> Void) {
        remoteChangeObservationCancellable = nil
        historyQueue.addOperation { block() }
    }

    func registerRemoteChangeMergeHandler(_ handler: @escaping PersistentStack.RemoteChangeMergeHandler) {
        historyQueue.addOperation { [weak self] in
            self?.onMergeRemoteChanges = handler
        }
    }

    private func mergeRemoteChanges(to persistentContainer: NSPersistentContainer) {
        historyQueue.addOperation { [weak self, weak persistentContainer] in
            guard let self, let persistentContainer else { return }

            let context = persistentContainer.newBackgroundContext()
            context.performAndWait {
                guard let transactions = try? PersistentHistoryFetcher.fetchRemoteTransactions(after: self.lastHistoryToken, for: context),
                      !transactions.isEmpty
                else {
                    return
                }

                self.onMergeRemoteChanges?(persistentContainer, transactions)

                persistentContainer.viewContext.perform {
                    transactions.merge(into: persistentContainer.viewContext)
                }

                self.lastHistoryToken = transactions.last?.token
            }
        }
    }
}

private extension Collection<NSPersistentHistoryTransaction> {
    func merge(into context: NSManagedObjectContext) {
        forEach { transaction in
            guard let userInfo = transaction.objectIDNotification().userInfo else { return }
            NSManagedObjectContext.mergeChanges(fromRemoteContextSave: userInfo, into: [context])
        }
    }
}
