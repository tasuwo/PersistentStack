//
//  Copyright ©︎ 2022 Tasuku Tozawa. All rights reserved.
//

import CloudKit

extension CKAccountStatus: PersistentStackExtended {}

public extension PersistentStackExtension where Base == CKAccountStatus {
    static var stream: AsyncStream<CKAccountStatus?> {
        AsyncStream { continuation in
            if #available(iOS 15, *) {
                let iteration = Task {
                    for await _ in NotificationCenter.default.notifications(named: .CKAccountChanged) {
                        let status = try? await CKContainer.default().accountStatus()
                        continuation.yield(status)
                    }
                }

                continuation.onTermination = { @Sendable _ in
                    iteration.cancel()
                }
            } else {
                let cancellable = NotificationCenter
                    .Publisher(center: .default, name: .CKAccountChanged)
                    .sink { _ in
                        Task {
                            let status = try? await CKContainer.default().accountStatus()
                            continuation.yield(status)
                        }
                    }

                continuation.onTermination = { @Sendable _ in
                    cancellable.cancel()
                }
            }

            Task {
                let status = try? await CKContainer.default().accountStatus()
                continuation.yield(status)
            }
        }
    }
}
