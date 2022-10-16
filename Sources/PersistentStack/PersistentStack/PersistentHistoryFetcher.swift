//
//  Copyright © 2022 Tasuku Tozawa. All rights reserved.
//

import CoreData

enum PersistentHistoryFetcher {
    enum Error: Swift.Error {
        case failedToConvertHistoryTransaction
    }

    // MARK: - Methods

    static func fetchRemoteTransactions(after lastHistoryToken: NSPersistentHistoryToken?,
                                        for context: NSManagedObjectContext) throws -> [NSPersistentHistoryTransaction]
    {
        let request = fetchRemoteTransactionsRequest(after: lastHistoryToken, for: context)

        guard let result = try context.execute(request) as? NSPersistentHistoryResult,
              let transactions = result.result as? [NSPersistentHistoryTransaction]
        else {
            throw Error.failedToConvertHistoryTransaction
        }

        return transactions
    }

    private static func fetchRemoteTransactionsRequest(after lastHistoryToken: NSPersistentHistoryToken?,
                                                       for context: NSManagedObjectContext) -> NSPersistentHistoryChangeRequest
    {
        let request = NSPersistentHistoryChangeRequest.fetchHistory(after: lastHistoryToken)

        guard let fetchRequest = NSPersistentHistoryTransaction.fetchRequest else {
            return request
        }

        var predicates: [NSPredicate] = []
        if let author = context.transactionAuthor {
            predicates.append(NSPredicate(format: "%K != %@",
                                          #keyPath(NSPersistentHistoryTransaction.author),
                                          author))
        }
        fetchRequest.predicate = NSCompoundPredicate(type: .and, subpredicates: predicates)
        request.fetchRequest = fetchRequest

        return request
    }
}
