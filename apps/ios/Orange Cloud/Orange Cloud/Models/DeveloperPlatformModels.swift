//
//  DeveloperPlatformModels.swift
//  Orange Cloud
//
//  开发者平台模块数据模型：Queues / AI Gateway / Durable Objects / Workers AI。
//  端点核对自 Cloudflare 官方 API 文档。
//

import Foundation

// MARK: - Queues（queues.read / .write）

/// GET /accounts/{id}/queues
nonisolated struct CFQueue: Codable, Identifiable, Sendable {
    let queueId:    String
    let queueName:  String?
    let createdOn:  String?
    let modifiedOn: String?
    let producers:  [CFQueueEndpoint]?
    let consumers:  [CFQueueEndpoint]?

    var id: String { queueId }
    var name: String { queueName ?? queueId }

    enum CodingKeys: String, CodingKey {
        case producers, consumers
        case queueId    = "queue_id"
        case queueName  = "queue_name"
        case createdOn  = "created_on"
        case modifiedOn = "modified_on"
    }
}

nonisolated struct CFQueueEndpoint: Codable, Sendable {
    let type:   String?
    let script: String?
}

/// POST /accounts/{id}/queues
nonisolated struct CFQueueCreate: Codable, Sendable {
    let queueName: String
    enum CodingKeys: String, CodingKey { case queueName = "queue_name" }
}

// MARK: - AI Gateway（aig.read / .write）

/// GET /accounts/{id}/ai-gateway/gateways
nonisolated struct AIGateway: Codable, Identifiable, Sendable {
    let id:                     String
    let cacheTtl:               Int?
    let collectLogs:            Bool?
    let rateLimitingInterval:   Int?
    let rateLimitingLimit:      Int?
    let cacheInvalidateOnUpdate: Bool?
    let createdOn:              String?
    let modifiedOn:             String?

    enum CodingKeys: String, CodingKey {
        case id
        case cacheTtl                = "cache_ttl"
        case collectLogs             = "collect_logs"
        case rateLimitingInterval    = "rate_limiting_interval"
        case rateLimitingLimit       = "rate_limiting_limit"
        case cacheInvalidateOnUpdate = "cache_invalidate_on_update"
        case createdOn               = "created_on"
        case modifiedOn              = "modified_on"
    }
}

/// POST /accounts/{id}/ai-gateway/gateways（全字段必填）
nonisolated struct AIGatewayCreate: Codable, Sendable {
    let id:                      String
    let cacheInvalidateOnUpdate: Bool
    let cacheTtl:                Int
    let collectLogs:             Bool
    let rateLimitingInterval:    Int
    let rateLimitingLimit:       Int

    enum CodingKeys: String, CodingKey {
        case id
        case cacheInvalidateOnUpdate = "cache_invalidate_on_update"
        case cacheTtl                = "cache_ttl"
        case collectLogs             = "collect_logs"
        case rateLimitingInterval    = "rate_limiting_interval"
        case rateLimitingLimit       = "rate_limiting_limit"
    }
}

// MARK: - Durable Objects（只读，workers-scripts.read）

/// GET /accounts/{id}/workers/durable_objects/namespaces
nonisolated struct DurableObjectNamespace: Codable, Identifiable, Sendable {
    let id:         String
    let name:       String?
    let className:  String?
    let script:     String?
    let useSqlite:  Bool?

    enum CodingKeys: String, CodingKey {
        case id, name, script
        case className = "class"
        case useSqlite = "use_sqlite"
    }
}

// MARK: - Workers AI（只读模型目录，ai.read）

/// GET /accounts/{id}/ai/models/search
nonisolated struct AIModel: Codable, Identifiable, Sendable {
    let id:          String
    let name:        String?
    let description: String?
    let task:        AITask?

    /// 模型短名（去掉 @cf/ 前缀的最后一段）
    var shortName: String { (name ?? id).split(separator: "/").last.map(String.init) ?? (name ?? id) }
    var taskName:  String { task?.name ?? "" }
}

nonisolated struct AITask: Codable, Sendable {
    let id:   String?
    let name: String?
}

// MARK: - Hyperdrive（query-cache.read / .write）

/// GET /accounts/{id}/hyperdrive/configs（password 为写专用，响应永不返回）
nonisolated struct HyperdriveConfig: Codable, Identifiable, Sendable {
    let id:     String
    let name:   String?
    let origin: HyperdriveOrigin?
    let caching: HyperdriveCaching?

    var displayName: String { name ?? id }
}

nonisolated struct HyperdriveOrigin: Codable, Sendable {
    let scheme:   String?
    let host:     String?
    let port:     Int?
    let database: String?
    let user:     String?

    var summary: String {
        let s = scheme ?? "postgres"
        let h = host ?? "—"
        let db = database.map { "/\($0)" } ?? ""
        return "\(s)://\(h)\(db)"
    }
}

nonisolated struct HyperdriveCaching: Codable, Sendable {
    let disabled: Bool?
}

/// POST /accounts/{id}/hyperdrive/configs
nonisolated struct HyperdriveCreate: Codable, Sendable {
    let name:   String
    let origin: Origin

    nonisolated struct Origin: Codable, Sendable {
        let scheme:   String
        let host:     String
        let port:     Int
        let database: String
        let user:     String
        let password: String
    }
}

nonisolated enum HyperdriveScheme: String, CaseIterable, Identifiable, Sendable {
    case postgres, mysql
    var id: String { rawValue }
    var label: String { self == .postgres ? "PostgreSQL" : "MySQL" }
    var defaultPort: Int { self == .postgres ? 5432 : 3306 }
}
