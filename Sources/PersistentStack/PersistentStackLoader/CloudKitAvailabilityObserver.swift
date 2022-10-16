//
//  Copyright ©︎ 2022 Tasuku Tozawa. All rights reserved.
//

import CloudKit

enum CloudKitAvailabilityObserver {
    static var stream: AsyncThrowingStream<CloudKitAvailability, Error> {
        AsyncThrowingStream { continuation in
            let iteration = Task {
                for try await status in Self.accountStatus {
                    switch status {
                    case .available:
                        continuation.yield(.available)

                    case .couldNotDetermine:
                        continuation.yield(.unavailable(.couldNotDetermine))

                    case .restricted:
                        continuation.yield(.unavailable(.restricted))

                    case .noAccount:
                        continuation.yield(.unavailable(.noAccount))

                    case .temporarilyUnavailable:
                        continuation.yield(.unavailable(.temporarilyUnavailable))

                    @unknown default:
                        continuation.yield(.unavailable(.unknown))
                    }
                }
            }

            continuation.onTermination = { @Sendable _ in
                iteration.cancel()
            }
        }
    }

    private static var accountStatus: AsyncThrowingStream<CKAccountStatus, Error> {
        AsyncThrowingStream(CKAccountStatus.self) { continuation in
            if #available(iOS 15, *) {
                let iteration = Task {
                    for await _ in NotificationCenter.default.notifications(named: .CKAccountChanged) {
                        let status = try await CKContainer.default().accountStatus()
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
                            let status = try await CKContainer.default().accountStatus()
                            continuation.yield(status)
                        }
                    }

                continuation.onTermination = { @Sendable _ in
                    cancellable.cancel()
                }
            }

            Task {
                let status = try await CKContainer.default().accountStatus()
                continuation.yield(status)
            }
        }
    }
}
