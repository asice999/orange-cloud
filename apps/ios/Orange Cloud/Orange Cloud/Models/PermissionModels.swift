//
//  PermissionModels.swift
//  Orange Cloud
//
//  OAuth 授权范围的功能模块定义。
//  scope ID 来自 GET https://api.cloudflare.com/client/v4/oauth/scopes 的 id 字段。
//

import Foundation

/// 单个功能模块的权限状态
nonisolated struct FeaturePermission: Identifiable, Sendable {
    let id:          String
    let title:       String
    let description: String
    let icon:        String
    /// 只读所需的 OAuth scope ID 列表
    let readScopes:  [String]
    /// 编辑所需的 OAuth scope ID 列表（空 = 不支持编辑）
    let editScopes:  [String]
    let isRequired:  Bool

    var isEnabled:   Bool = true
    var canEdit:     Bool = false

    var hasEditOption: Bool { !editScopes.isEmpty }
}

extension FeaturePermission {

    // MARK: - 功能模块完整定义

    static let allFeatures: [FeaturePermission] = [
        .init(
            id: "account",
            title: String(localized: "账号信息"),
            description: String(localized: "查看账号基本信息和设置"),
            icon: "person.circle",
            readScopes: ["account-settings.read"],
            editScopes: [],
            isRequired: true
        ),
        .init(
            id: "zones",
            title: String(localized: "域名"),
            description: String(localized: "查看和管理你的域名"),
            icon: "globe",
            readScopes: ["zone.read"],
            editScopes: ["zone.write"],
            isRequired: true    // zone.read 是几乎所有操作的基础
        ),
        .init(
            id: "dns",
            title: String(localized: "DNS 记录"),
            description: String(localized: "查看和修改 DNS 解析记录"),
            icon: "network",
            readScopes: ["dns.read"],
            editScopes: ["dns.write"],
            isRequired: false
        ),
        .init(
            id: "workers",
            title: String(localized: "Workers 脚本"),
            description: String(localized: "查看和管理 Workers 无服务器函数"),
            icon: "bolt.circle",
            // workers-scripts.* 是 account 级（脚本/子域/自定义域）；workers-routes.* 是 zone 级
            // （/zones/{id}/workers/routes 单独的权限组），缺它会让路由查询 403 cf=10000。
            readScopes: ["workers-scripts.read", "workers-routes.read"],
            editScopes: ["workers-scripts.write", "workers-routes.write"],
            isRequired: false
        ),
        .init(
            id: "workers_tail",
            title: String(localized: "Workers 实时日志"),
            description: String(localized: "查看 Workers 的实时执行日志"),
            icon: "text.alignleft",
            readScopes: ["workers-tail.read"],
            editScopes: [],
            isRequired: false
        ),
        .init(
            id: "snippets",
            title: String(localized: "Snippets"),
            description: String(localized: "查看和编辑域名的边缘代码片段"),
            icon: "curlybraces",
            readScopes: ["snippets.read"],
            editScopes: ["snippets.write"],
            isRequired: false
        ),
        .init(
            id: "r2",
            title: String(localized: "R2 对象存储"),
            description: String(localized: "浏览和管理 R2 存储桶"),
            icon: "archivebox",
            readScopes: ["workers-r2.read"],
            editScopes: ["workers-r2.write"],
            isRequired: false
        ),
        .init(
            id: "d1",
            title: String(localized: "D1 数据库"),
            description: String(localized: "查询和管理 D1 SQLite 数据库"),
            icon: "cylinder",
            readScopes: ["d1.read"],
            editScopes: ["d1.write"],
            isRequired: false
        ),
        .init(
            id: "kv",
            title: String(localized: "KV 存储"),
            description: String(localized: "查看和管理 Workers KV 键值对"),
            icon: "square.grid.2x2",
            readScopes: ["workers-kv-storage.read"],
            editScopes: ["workers-kv-storage.write"],
            isRequired: false
        ),
        .init(
            id: "tunnels",
            title: String(localized: "Cloudflare Tunnel"),
            description: String(localized: "查看隧道与连接状态；读写可新建隧道、配置公共主机名路由"),
            icon: "arrow.triangle.2.circlepath",
            readScopes: ["argotunnel.read"],
            editScopes: ["argotunnel.write"],
            isRequired: false
        ),
        .init(
            id: "waf",
            title: String(localized: "WAF 防火墙"),
            description: String(localized: "查看和启停自定义防火墙规则"),
            icon: "shield",
            readScopes: ["zone-waf.read"],
            editScopes: ["zone-waf.write"],
            isRequired: false
        ),
        .init(
            id: "email_routing",
            title: "Email Routing",
            description: String(localized: "查看与管理邮件路由规则与目的地址"),
            icon: "envelope",
            // rules 是域名级，addresses 是账号级——两组 scope 都要才能完整使用
            readScopes: ["email-routing-rule.read", "email-routing-address.read"],
            editScopes: ["email-routing-rule.write", "email-routing-address.write"],
            isRequired: false
        ),
        .init(
            id: "zt_access",
            title: "Zero Trust Access",
            description: String(localized: "查看受 Access 保护的应用"),
            icon: "lock.shield",
            readScopes: ["access.read"],
            editScopes: ["access.write"],
            isRequired: false
        ),
        .init(
            id: "zt_gateway",
            title: "Zero Trust Gateway",
            description: String(localized: "查看 Gateway 过滤策略"),
            icon: "shield.lefthalf.filled",
            readScopes: ["teams.read"],
            editScopes: ["teams.write"],
            isRequired: false
        ),
        .init(
            id: "zone_settings",
            title: String(localized: "缓存与防护"),
            description: String(localized: "缓存清理、SSL/TLS、Under Attack / 开发模式"),
            icon: "speedometer",
            readScopes: ["zone-settings.read"],
            editScopes: ["zone-settings.write", "cache.purge"],
            isRequired: false
        ),
        .init(
            id: "cache_rules",
            title: String(localized: "缓存规则"),
            description: String(localized: "按 URL 覆盖边缘/浏览器缓存时长或绕过缓存"),
            icon: "bolt.horizontal",
            readScopes: ["cache-settings.read"],
            editScopes: ["cache-settings.write"],
            isRequired: false
        ),
        .init(
            id: "ssl_certs",
            title: String(localized: "SSL 证书"),
            description: String(localized: "查看证书、开关 Universal SSL、删除高级证书"),
            icon: "checkmark.seal",
            readScopes: ["ssl-and-certificates.read"],
            editScopes: ["ssl-and-certificates.write"],
            isRequired: false
        ),
        .init(
            id: "transform_rules",
            title: "Transform Rules",
            description: String(localized: "查看与编辑 URL 重写、请求/响应头规则"),
            icon: "arrow.triangle.branch",
            readScopes: ["zone-transform-rules.read"],
            editScopes: ["zone-transform-rules.write"],
            isRequired: false
        ),
        .init(
            id: "ip_access_rules",
            title: String(localized: "IP 访问规则"),
            description: String(localized: "查看与管理 IP / ASN / 国家或地区访问规则"),
            icon: "hand.raised",
            readScopes: ["firewall-services.read"],
            editScopes: ["firewall-services.write"],
            isRequired: false
        ),
        .init(
            id: "load_balancing",
            title: String(localized: "负载均衡"),
            description: String(localized: "负载均衡器、源站池与健康监测"),
            icon: "arrow.left.arrow.right",
            readScopes: ["load-balancers.read", "load-balancing-monitors-and-pools.read"],
            editScopes: ["load-balancers.write", "load-balancing-monitors-and-pools.write"],
            isRequired: false
        ),
        .init(
            id: "bulk_redirects",
            title: "Bulk Redirects",
            description: String(localized: "批量 URL 重定向列表与条目"),
            icon: "arrowshape.turn.up.right",
            readScopes: ["account-rule-lists.read", "mass-url-redirects.read"],
            editScopes: ["account-rule-lists.write", "mass-url-redirects.write"],
            isRequired: false
        ),
        // Pages（M3）：page.read / page.write 已在 OAuth client 注册并点亮（2026-06-26）。
        .init(
            id: "pages",
            title: String(localized: "Cloudflare Pages"),
            description: String(localized: "查看与管理 Pages 项目与部署"),
            icon: "doc.richtext",
            readScopes: ["page.read"],
            editScopes: ["page.write"],
            isRequired: false
        ),
        .init(
            id: "analytics",
            title: String(localized: "流量分析"),
            description: String(localized: "查看账号与域名的流量和安全分析"),
            icon: "chart.bar",
            // Zone 流量走 analytics.read；账号级用量（workersInvocationsAdaptive 等 adaptive 数据集）
            // 现需 workers-observability.read——只有 account-analytics.read 会被 GraphQL 拒
            // 「not authorized for that account」（Cloudflare 把账号级 Workers 分析挪到了 Observability 权限下）。
            readScopes: ["account-analytics.read", "analytics.read", "workers-observability.read"],
            editScopes: [],
            isRequired: false
        ),
        // 开发者平台（scope 均已在 OAuth client 注册，见 dash 实列）
        .init(
            id: "queues",
            title: String(localized: "Queues"),
            description: String(localized: "查看与管理消息队列"),
            icon: "tray.2",
            readScopes: ["queues.read"],
            editScopes: ["queues.write"],
            isRequired: false
        ),
        .init(
            id: "ai_gateway",
            title: String(localized: "AI Gateway"),
            description: String(localized: "查看与管理 AI Gateway 网关"),
            icon: "brain.head.profile",
            readScopes: ["aig.read"],
            editScopes: ["aig.write"],
            isRequired: false
        ),
        .init(
            id: "workers_ai",
            title: String(localized: "Workers AI"),
            description: String(localized: "浏览模型目录，并试运行文本生成模型"),
            icon: "brain",
            readScopes: ["ai.read"],
            editScopes: ["ai.write"],
            isRequired: false
        ),
        .init(
            id: "hyperdrive",
            title: "Hyperdrive",
            description: String(localized: "查看与管理数据库加速配置"),
            icon: "bolt.horizontal.circle",
            readScopes: ["query-cache.read"],
            editScopes: ["query-cache.write"],
            isRequired: false
        ),
        .init(
            id: "notifications",
            title: String(localized: "通知 / 告警"),
            description: String(localized: "管理 Cloudflare 告警策略，把告警推送到推送中心"),
            icon: "bell.badge",
            readScopes: ["notifications.read"],
            editScopes: ["notifications.write"],
            isRequired: false
        ),
    ]

    // MARK: - Scope 构建

    /// 根据当前选择，生成最小权限 scope 集合
    static func buildScopeSet(from permissions: [FeaturePermission]) -> Set<String> {
        var scopes = Set<String>()
        for feature in permissions {
            guard feature.isEnabled else { continue }
            if feature.canEdit && !feature.editScopes.isEmpty {
                feature.editScopes.forEach { scopes.insert($0) }
                feature.readScopes.forEach { scopes.insert($0) }
            } else {
                feature.readScopes.forEach { scopes.insert($0) }
            }
        }
        return scopes
    }

    /// 生成空格分隔的 scope 字符串，直接用于 OAuth 请求的 scope 参数
    static func buildScopeString(from permissions: [FeaturePermission]) -> String {
        buildScopeSet(from: permissions).sorted().joined(separator: " ")
    }
}
