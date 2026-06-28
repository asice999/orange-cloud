//
//  QueueService.swift
//  Orange Cloud
//
//  Cloudflare Queues（account 级）。读 queues.read，写 queues.write。
//

import Foundation

struct QueueService {

    private let client: CFAPIClient

    init(client: CFAPIClient) { self.client = client }

    func list(accountId: String) async throws -> [CFQueue] {
        let response: CFAPIResponseArray<CFQueue> = try await client.get("accounts/\(accountId)/queues")
        guard response.success else { throw response.toAPIError() }
        return response.result ?? []
    }

    func create(accountId: String, name: String) async throws -> CFQueue {
        let response: CFAPIResponse<CFQueue> = try await client.post(
            "accounts/\(accountId)/queues", body: CFQueueCreate(queueName: name)
        )
        guard response.success, let queue = response.result else { throw response.toAPIError() }
        return queue
    }

    func delete(accountId: String, queueId: String) async throws {
        try await client.delete("accounts/\(accountId)/queues/\(queueId)")
    }
}
