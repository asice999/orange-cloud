//
//  AuditLogService.swift
//  Orange Cloud
//
//  账号审计日志（Audit Logs v2）只读查询，游标分页。
//  since / before 为必填时间窗；direction=desc 取最近在前。
//

import Foundation

struct AuditLogService {

    private let client: CFAPIClient

    init(client: CFAPIClient) {
        self.client = client
    }

    /// 拉取一页审计日志。cursor 为空取首页，非空续接下一页。
    func list(
        accountId: String,
        since: Date,
        before: Date,
        cursor: String?,
        limit: Int = 50
    ) async throws -> AuditLogPage {
        var query: [URLQueryItem] = [
            .init(name: "since",     value: since.ISO8601Format()),
            .init(name: "before",    value: before.ISO8601Format()),
            .init(name: "limit",     value: String(limit)),
            .init(name: "direction", value: "desc"),
        ]
        if let cursor, !cursor.isEmpty {
            query.append(.init(name: "cursor", value: cursor))
        }
        let page: AuditLogPage = try await client.get(
            "accounts/\(accountId)/logs/audit",
            queryItems: query
        )
        guard page.success else {
            throw page.toAPIError()
        }
        return page
    }
}
