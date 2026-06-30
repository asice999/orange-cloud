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

    /// 命名空间内的对象实例（只读，游标分页）。返回 (本页对象, 下一页游标)；游标为空即无更多。
    func listObjects(
        accountId: String, namespaceId: String, cursor: String? = nil, limit: Int = 100
    ) async throws -> (items: [DurableObjectInstance], cursor: String?) {
        var query = [URLQueryItem(name: "limit", value: String(limit))]
        if let cursor, !cursor.isEmpty { query.append(URLQueryItem(name: "cursor", value: cursor)) }
        let response: CFAPIResponseArray<DurableObjectInstance> = try await client.get(
            "accounts/\(accountId)/workers/durable_objects/namespaces/\(namespaceId)/objects",
            queryItems: query
        )
        guard response.success else { throw response.toAPIError() }
        let next = response.resultInfo?.cursor
        return (response.result ?? [], (next?.isEmpty == false) ? next : nil)
    }
}
