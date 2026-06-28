//
//  HyperdriveService.swift
//  Orange Cloud
//
//  Cloudflare Hyperdrive（account 级）。读 query-cache.read，写 query-cache.write。
//

import Foundation

struct HyperdriveService {

    private let client: CFAPIClient

    init(client: CFAPIClient) { self.client = client }

    func list(accountId: String) async throws -> [HyperdriveConfig] {
        let response: CFAPIResponseArray<HyperdriveConfig> = try await client.get(
            "accounts/\(accountId)/hyperdrive/configs"
        )
        guard response.success else { throw response.toAPIError() }
        return response.result ?? []
    }

    func create(accountId: String, body: HyperdriveCreate) async throws -> HyperdriveConfig {
        let response: CFAPIResponse<HyperdriveConfig> = try await client.post(
            "accounts/\(accountId)/hyperdrive/configs", body: body
        )
        guard response.success, let config = response.result else { throw response.toAPIError() }
        return config
    }

    func delete(accountId: String, configId: String) async throws {
        try await client.delete("accounts/\(accountId)/hyperdrive/configs/\(configId)")
    }
}
