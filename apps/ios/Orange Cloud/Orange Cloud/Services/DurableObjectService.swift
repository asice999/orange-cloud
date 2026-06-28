//
//  DurableObjectService.swift
//  Orange Cloud
//
//  Durable Objects（account 级，只读）。命名空间由 Worker 迁移定义，API 无创建/删除，
//  仅列出。沿用 workers-scripts.read（与 Workers 同权限组）。
//

import Foundation

struct DurableObjectService {

    private let client: CFAPIClient

    init(client: CFAPIClient) { self.client = client }

    func listNamespaces(accountId: String) async throws -> [DurableObjectNamespace] {
        let response: CFAPIResponseArray<DurableObjectNamespace> = try await client.get(
            "accounts/\(accountId)/workers/durable_objects/namespaces"
        )
        guard response.success else { throw response.toAPIError() }
        return response.result ?? []
    }
}
