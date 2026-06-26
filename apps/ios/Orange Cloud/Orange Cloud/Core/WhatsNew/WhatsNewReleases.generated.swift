//
//  WhatsNewReleases.generated.swift
//  Orange Cloud
//
//  ⚠️ 自动生成 —— 请勿手改。改 packages/changelog/ios.json 后运行 `pnpm changelog:gen`。
//  字符串走 WhatsNew.xcstrings（table: "WhatsNew"），与 Localizable.xcstrings 解耦。
//

import Foundation

nonisolated enum WhatsNewGenerated {
    static let releases: [WhatsNewRelease] = [
        WhatsNewRelease(version: "1.5.0", items: [
            WhatsNewItem(
                icon:   "bolt.horizontal",
                title:  String(localized: "缓存规则", table: "WhatsNew"),
                detail: String(localized: "按 URL 自定义边缘与浏览器缓存时长、绕过缓存，直接在手机上管理缓存规则。", table: "WhatsNew")
            ),
            WhatsNewItem(
                icon:   "arrow.left.arrow.right",
                title:  String(localized: "负载均衡", table: "WhatsNew"),
                detail: String(localized: "查看与管理负载均衡器、源站池和健康监测，掌握流量分发与源站健康。", table: "WhatsNew")
            ),
            WhatsNewItem(
                icon:   "doc.richtext",
                title:  String(localized: "Cloudflare Pages", table: "WhatsNew"),
                detail: String(localized: "浏览 Pages 项目与部署，一键重试 / 回滚 / 删除部署，并编辑构建配置。", table: "WhatsNew")
            ),
            WhatsNewItem(
                icon:   "arrowshape.turn.up.right",
                title:  String(localized: "批量重定向", table: "WhatsNew"),
                detail: String(localized: "管理批量 URL 重定向列表与条目，并一键启用，让重定向即刻生效。", table: "WhatsNew")
            ),
            WhatsNewItem(
                icon:   "lock.open",
                title:  String(localized: "一键重授权", table: "WhatsNew"),
                detail: String(localized: "缺少某项权限时，无需退出登录即可一键补齐授权，新功能即开即用。", table: "WhatsNew")
            )
        ]),
        WhatsNewRelease(version: "1.4.0", items: [
            WhatsNewItem(
                icon:   "checkmark.seal",
                title:  String(localized: "SSL 证书与加密设置", table: "WhatsNew"),
                detail: String(localized: "查看域名的边缘证书与到期时间，开关 Universal SSL，并调整 SSL/TLS 加密模式。", table: "WhatsNew")
            ),
            WhatsNewItem(
                icon:   "arrow.triangle.branch",
                title:  String(localized: "Transform Rules", table: "WhatsNew"),
                detail: String(localized: "查看并编辑 URL 重写、请求头与响应头规则，直接在手机上管理流量改写。", table: "WhatsNew")
            ),
            WhatsNewItem(
                icon:   "hand.raised",
                title:  String(localized: "IP 访问规则", table: "WhatsNew"),
                detail: String(localized: "按 IP、网段、ASN 或国家/地区拦截、质询或放行访问，随时增删规则。", table: "WhatsNew")
            ),
            WhatsNewItem(
                icon:   "shippingbox",
                title:  String(localized: "R2 存储升级", table: "WhatsNew"),
                detail: String(localized: "以文件夹方式浏览对象，复制或移动文件，查看各存储桶用量，并管理公开访问域名与 CORS。", table: "WhatsNew")
            ),
            WhatsNewItem(
                icon:   "link",
                title:  String(localized: "按 URL 精准清缓存", table: "WhatsNew"),
                detail: String(localized: "无需清空整站，指定单个或多个 URL 精准刷新缓存；并新增性能与缓存设置页。", table: "WhatsNew")
            ),
            WhatsNewItem(
                icon:   "globe",
                title:  String(localized: "更多语言与稳定性", table: "WhatsNew"),
                detail: String(localized: "新增德语、法语、阿拉伯语与土耳其语；并改进崩溃诊断，帮助更快定位疑难问题。", table: "WhatsNew")
            )
        ]),
        WhatsNewRelease(version: "1.3.2", items: [
            WhatsNewItem(
                icon:   "sparkles",
                title:  String(localized: "用自然语言写 WAF 规则", table: "WhatsNew"),
                detail: String(localized: "在支持 Apple 智能的设备上，用一句话描述需求即可生成 WAF 自定义规则，也能把现有规则翻译成大白话；全程在设备上离线完成。", table: "WhatsNew")
            ),
            WhatsNewItem(
                icon:   "wrench.and.screwdriver",
                title:  String(localized: "修复启动闪退", table: "WhatsNew"),
                detail: String(localized: "修复了 App 在部分 iOS 17 设备上一启动就闪退的问题。", table: "WhatsNew")
            ),
            WhatsNewItem(
                icon:   "key.fill",
                title:  String(localized: "登录更稳定", table: "WhatsNew"),
                detail: String(localized: "登录信息改为仅在本机安全保管，修复了偶尔被登出、需要重新登录的问题；登录状态不再通过 iCloud 在设备间同步。", table: "WhatsNew")
            )
        ]),
        WhatsNewRelease(version: "1.3.0", items: [
            WhatsNewItem(
                icon:   "globe.badge.chevron.right",
                title:  String(localized: "添加域名", table: "WhatsNew"),
                detail: String(localized: "在 App 里把已注册的域名加入账号，并拿到要去注册商处配置的名称服务器。", table: "WhatsNew")
            ),
            WhatsNewItem(
                icon:   "network",
                title:  String(localized: "Tunnel 管理", table: "WhatsNew"),
                detail: String(localized: "不再只是查看——新建隧道、获取连接令牌与命令、配置公共主机名路由。", table: "WhatsNew")
            ),
            WhatsNewItem(
                icon:   "cylinder.split.1x2",
                title:  String(localized: "D1 数据库管理", table: "WhatsNew"),
                detail: String(localized: "直接新建 D1 数据库，或在原样确认库名后安全删除。", table: "WhatsNew")
            ),
            WhatsNewItem(
                icon:   "key",
                title:  String(localized: "变量与密钥", table: "WhatsNew"),
                detail: String(localized: "管理 Worker 的环境变量与密钥，随手增删改。", table: "WhatsNew")
            ),
            WhatsNewItem(
                icon:   "clock",
                title:  String(localized: "定时触发器", table: "WhatsNew"),
                detail: String(localized: "查看与增删 Cron 触发器，让 Worker 按计划自动运行。", table: "WhatsNew")
            ),
            WhatsNewItem(
                icon:   "globe",
                title:  String(localized: "域名与路由", table: "WhatsNew"),
                detail: String(localized: "管理 workers.dev 子域、自定义域与路由，掌控 Worker 的访问入口。", table: "WhatsNew")
            )
        ]),
        WhatsNewRelease(version: "1.2.1", items: [
            WhatsNewItem(
                icon:   "applewatch",
                title:  String(localized: "Apple Watch App", table: "WhatsNew"),
                detail: String(localized: "把域名状态与流量概览带上手腕，还能添加到表盘复杂功能随时一瞥。", table: "WhatsNew")
            ),
            WhatsNewItem(
                icon:   "curlybraces",
                title:  String(localized: "Snippets", table: "WhatsNew"),
                detail: String(localized: "在域名详情查看、编辑、新建 Cloudflare 边缘代码片段，并管理触发规则——轻量版 Workers，Pro 解锁。", table: "WhatsNew")
            ),
            WhatsNewItem(
                icon:   "accessibility",
                title:  String(localized: "全面无障碍", table: "WhatsNew"),
                detail: String(localized: "VoiceOver、更大字体、不只靠颜色区分、足够对比度全面达标，配合系统辅助功能更顺手。", table: "WhatsNew")
            ),
            WhatsNewItem(
                icon:   "character.bubble",
                title:  String(localized: "更多语言", table: "WhatsNew"),
                detail: String(localized: "新增西班牙语、韩语、葡萄牙语，现已支持九种语言。", table: "WhatsNew")
            ),
            WhatsNewItem(
                icon:   "arrow.clockwise",
                title:  String(localized: "刷新更省心", table: "WhatsNew"),
                detail: String(localized: "刷新失败不再弹窗打断，下拉刷新更稳定可靠。", table: "WhatsNew")
            )
        ])
    ]
}
