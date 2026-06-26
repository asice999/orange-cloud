//
//  ProGate.swift
//  Orange Cloud
//
//  Pro 付费闸门组件：触发场景枚举（ProFeature）、PRO 徽章、
//  行级闸门（ProGatedNavigationLink，先验 Pro 再走 scope 门控）、整页锁定态（ProLockedView）。
//  免费层 = 单账号 + 域名/DNS 全功能 + 24h 分析；其余场景由 ProFeature 枚举闸门。
//

import SwiftUI

/// 触发付费墙的场景，决定付费墙头部与锁定态文案
nonisolated enum ProFeature: String, Identifiable, Sendable {
    case multiAccount, storage, workerTail, waf, tunnel, analyticsRange, snippets
    case workerSecrets, workerTriggers, workerRoutes, cacheRules, pages, loadBalancing, bulkRedirects

    var id: String { rawValue }

    var headline: String {
        switch self {
        case .multiAccount:   String(localized: "多账号需要 Pro")
        case .storage:        String(localized: "存储管理需要 Pro")
        case .workerTail:     String(localized: "实时日志需要 Pro")
        case .waf:            String(localized: "WAF 管理需要 Pro")
        case .tunnel:         String(localized: "Tunnel 需要 Pro")
        case .analyticsRange: String(localized: "更长时间范围需要 Pro")
        case .snippets:       String(localized: "Snippets 需要 Pro")
        case .workerSecrets:  String(localized: "变量与密钥需要 Pro")
        case .workerTriggers: String(localized: "触发器管理需要 Pro")
        case .workerRoutes:   String(localized: "域名管理需要 Pro")
        case .cacheRules:     String(localized: "缓存规则需要 Pro")
        case .pages:          String(localized: "Cloudflare Pages 需要 Pro")
        case .loadBalancing:  String(localized: "负载均衡需要 Pro")
        case .bulkRedirects:  String(localized: "Bulk Redirects 需要 Pro")
        }
    }

    var blurb: String {
        switch self {
        case .multiAccount:   String(localized: "免费版可登录一个 Cloudflare 账号；Pro 可添加多个账号并快速切换。")
        case .storage:        String(localized: "R2 对象存储、D1 数据库与 KV 键值管理属于 Orange Cloud Pro。")
        case .workerTail:     String(localized: "Workers 实时日志与灵动岛 Live Activity 属于 Orange Cloud Pro。")
        case .waf:            String(localized: "查看与启停 WAF 自定义规则属于 Orange Cloud Pro。")
        case .tunnel:         String(localized: "Cloudflare Tunnel 的查看与管理（新建隧道、公共主机名路由）属于 Orange Cloud Pro。")
        case .analyticsRange: String(localized: "7 天与 30 天流量分析属于 Pro；24 小时视图永久免费。")
        case .snippets:       String(localized: "查看与管理域名的边缘 Snippets（JS 代码片段）属于 Orange Cloud Pro。")
        case .workerSecrets:  String(localized: "管理 Workers 的环境变量与密钥属于 Orange Cloud Pro。")
        case .workerTriggers: String(localized: "管理 Workers 的 Cron 定时触发器属于 Orange Cloud Pro。")
        case .workerRoutes:   String(localized: "管理 Workers 的子域、自定义域与路由属于 Orange Cloud Pro。")
        case .cacheRules:     String(localized: "按 URL 自定义边缘/浏览器缓存 TTL、绕过缓存等缓存规则属于 Orange Cloud Pro。")
        case .pages:          String(localized: "查看与管理 Cloudflare Pages 项目和部署（重试 / 回滚 / 删除、构建配置）属于 Orange Cloud Pro。")
        case .loadBalancing:  String(localized: "负载均衡器、源站池与健康监测的查看与管理属于 Orange Cloud Pro。")
        case .bulkRedirects:  String(localized: "批量 URL 重定向列表与条目的查看与管理属于 Orange Cloud Pro。")
        }
    }

    var systemImage: String {
        switch self {
        case .multiAccount:   "person.2"
        case .storage:        "externaldrive"
        case .workerTail:     "text.alignleft"
        case .waf:            "shield"
        case .tunnel:         "arrow.triangle.2.circlepath"
        case .analyticsRange: "chart.xyaxis.line"
        case .snippets:       "curlybraces"
        case .workerSecrets:  "key"
        case .workerTriggers: "clock"
        case .workerRoutes:   "globe"
        case .cacheRules:     "bolt.horizontal"
        case .pages:          "doc.richtext"
        case .loadBalancing:  "arrow.left.arrow.right"
        case .bulkRedirects:  "arrowshape.turn.up.right"
        }
    }
}

/// 橙色 PRO 胶囊徽章
struct ProBadge: View {
    var body: some View {
        Text(verbatim: "PRO")
            .font(.caption2.weight(.heavy))
            .foregroundStyle(Color.ocOrangeText)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.ocOrange.opacity(0.14), in: Capsule())
    }
}

/// 行级 Pro 闸门：已解锁则退化为既有的 scope 门控导航行；未解锁显示 PRO 徽章并弹付费墙。
struct ProGatedNavigationLink<Destination: View>: View {

    let label:         String
    let systemImage:   String
    let requiredScope: String
    let feature:       ProFeature
    var tint: Color = .ocOrange
    var showsChevron: Bool = false
    @ViewBuilder let destination: () -> Destination

    @Environment(EntitlementStore.self) private var entitlements
    @State private var paywallPresented = false

    var body: some View {
        if entitlements.isPro {
            PermissionGatedNavigationLink(
                label: label,
                systemImage: systemImage,
                requiredScope: requiredScope,
                tint: tint,
                showsChevron: showsChevron,
                destination: destination
            )
        } else {
            Button {
                paywallPresented = true
            } label: {
                HStack(spacing: 12) {
                    TintIcon(systemImage: systemImage, color: tint)
                    Text(label)
                        .foregroundStyle(.primary)
                    Spacer()
                    ProBadge()
                }
            }
            .foregroundStyle(.primary)
            .sheet(isPresented: $paywallPresented) {
                PaywallView(feature: feature)
            }
        }
    }
}

/// 整页锁定态（如存储 Tab）：占满内容区的 Pro 介绍 + 付费墙入口
struct ProLockedView: View {

    let feature: ProFeature

    @State private var paywallPresented = false

    var body: some View {
        ContentUnavailableView {
            Label(feature.headline, systemImage: feature.systemImage)
        } description: {
            Text(feature.blurb)
        } actions: {
            Button {
                paywallPresented = true
            } label: {
                Label(String(localized: "了解 Orange Cloud Pro"), systemImage: "sparkles")
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.ocOrangePressed)
            .fontWeight(.bold)
        }
        .sheet(isPresented: $paywallPresented) {
            PaywallView(feature: feature)
        }
    }
}

#Preview("锁定态") {
    ProLockedView(feature: .storage)
        .environment(EntitlementStore.shared)
}
