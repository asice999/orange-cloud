//
//  StorageViewModels.swift
//  Orange Cloud
//
//  P2 存储模块的 ViewModel 集合。存储数据实时拉取，不进 SwiftData
//  （低频浏览场景，缓存收益低）。
//

import Foundation
import Observation

// MARK: - R2

@Observable
@MainActor
final class R2BucketListViewModel {

    var buckets: [R2Bucket] = []
    var usageByBucket: [String: R2BucketUsage] = [:]
    var isLoading = false
    var error: String?
    var isCreating = false
    var didCreate = false      // sensoryFeedback 触发器
    var isDeleting = false
    var didDelete = false      // sensoryFeedback 触发器

    private let service: R2Service
    private let analyticsService: AnalyticsService

    init(service: R2Service, analyticsService: AnalyticsService) {
        self.service = service
        self.analyticsService = analyticsService
    }

    /// 创建桶：成功后插到列表顶端，返回 true。
    func create(accountId: String, name: String, locationHint: String?, storageClass: String?) async -> Bool {
        guard !isCreating else { return false }
        isCreating = true
        error = nil
        defer { isCreating = false }
        do {
            let created = try await service.createBucket(
                accountId: accountId, name: name,
                locationHint: locationHint, storageClass: storageClass
            )
            buckets.insert(created, at: 0)
            didCreate.toggle()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    /// 删除桶：成功后从列表移除，返回 true。Cloudflare 要求桶为空，删除前须经二次确认。
    func delete(accountId: String, bucket: R2Bucket) async -> Bool {
        guard !isDeleting else { return false }
        isDeleting = true
        error = nil
        defer { isDeleting = false }
        do {
            try await service.deleteBucket(accountId: accountId, name: bucket.name)
            buckets.removeAll { $0.name == bucket.name }
            usageByBucket[bucket.name] = nil
            didDelete.toggle()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func load(accountId: String) async {
        isLoading = true
        error = nil
        do {
            buckets = try await service.listBuckets(accountId: accountId)
            isLoading = false
            // 用量 best-effort：免费账号账户级 GraphQL 常被 authz 挡，失败不影响桶列表
            usageByBucket = (try? await analyticsService.r2UsageByBucket(accountId: accountId)) ?? [:]
        } catch {
            self.error = error.localizedDescription
            isLoading = false
        }
    }
}

@Observable
@MainActor
final class R2ObjectListViewModel {

    var objects: [R2Object] = []
    var folders: [R2Folder] = []
    var currentPrefix = ""
    var isLoading = false
    var isLoadingMore = false
    var error: String?
    private(set) var nextCursor: String?

    var hasMore: Bool { nextCursor != nil }
    var isContentEmpty: Bool { folders.isEmpty && objects.isEmpty }
    /// 导航标题：根层显示桶名，进文件夹后显示「桶名/当前前缀」
    var displayTitle: String {
        guard !currentPrefix.isEmpty else { return bucketName }
        return "\(bucketName)/\(currentPrefix.trimmingCharacters(in: CharacterSet(charactersIn: "/")))"
    }

    private let service: R2Service
    private let accountId: String
    let bucketName: String

    init(service: R2Service, accountId: String, bucketName: String) {
        self.service = service
        self.accountId = accountId
        self.bucketName = bucketName
    }

    func load() async {
        isLoading = true
        error = nil
        do {
            let page = try await service.listObjects(listOptions())
            apply(page, reset: true)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func loadMore() async {
        guard let cursor = nextCursor, !isLoadingMore else { return }
        isLoadingMore = true
        do {
            let page = try await service.listObjects(listOptions(cursor: cursor))
            apply(page, reset: false)
        } catch {
            self.error = error.localizedDescription
        }
        isLoadingMore = false
    }

    // MARK: - 文件夹导航

    func open(folder: R2Folder) async {
        guard currentPrefix != folder.prefix else { return }
        currentPrefix = folder.prefix
        await load()
    }

    func openParentFolder() async {
        guard !currentPrefix.isEmpty else { return }
        currentPrefix = R2Folder.parentPrefix(of: currentPrefix)
        await load()
    }

    private func listOptions(cursor: String? = nil) -> R2ObjectListOptions {
        R2ObjectListOptions(
            accountId: accountId,
            bucketName: bucketName,
            prefix: currentPrefix,
            cursor: cursor
        )
    }

    private func apply(_ page: R2ObjectPage, reset: Bool) {
        let pageFolders = R2Folder.makeList(from: page.folderPrefixes, parentPrefix: currentPrefix)
        folders = reset ? pageFolders : Self.mergedFolders(folders, pageFolders)
        objects = reset ? page.objects : objects + page.objects
        nextCursor = page.nextCursor
    }

    private static func mergedFolders(_ current: [R2Folder], _ incoming: [R2Folder]) -> [R2Folder] {
        Array(Set(current + incoming)).sorted { $0.prefix < $1.prefix }
    }

    // MARK: - 对象读写

    var isUploading = false
    var isDownloading = false
    var didUpload = false      // sensoryFeedback 触发器

    /// 下载对象到临时文件（QuickLook 预览用），文件名保留原始扩展名
    func downloadToTemp(object: R2Object) async -> URL? {
        guard !isDownloading else { return nil }
        isDownloading = true
        defer { isDownloading = false }
        do {
            let data = try await service.getObjectData(
                accountId: accountId, bucketName: bucketName, key: object.key
            )
            var filename = (object.key as NSString).lastPathComponent
            if filename.isEmpty { filename = "file" }
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
                .appendingPathComponent(filename)
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            try data.write(to: url)
            return url
        } catch {
            self.error = error.localizedDescription
            return nil
        }
    }

    /// 上传成功后刷新首页列表。文件落到当前所在文件夹（currentPrefix）。
    func upload(data: Data, filename: String, contentType: String) async -> Bool {
        guard !isUploading else { return false }
        isUploading = true
        error = nil
        defer { isUploading = false }
        do {
            try await service.putObject(
                accountId: accountId, bucketName: bucketName,
                key: currentPrefix + filename, data: data, contentType: contentType
            )
            didUpload.toggle()
            await load()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    /// 删除成功后从列表移除
    func delete(key: String) async -> Bool {
        do {
            try await service.deleteObject(accountId: accountId, bucketName: bucketName, key: key)
            objects.removeAll { $0.key == key }
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    // MARK: - 复制 / 移动（流式 + iOS 26 连续后台任务）

    var isTransferring = false
    var transferProgress: Double = 0
    var transferLabel: String?
    var didTransfer = false     // sensoryFeedback 触发器

    /// 是否可复制/移动：受 client/v4 单次 PUT ~300MB 上限约束
    func canTransfer(_ object: R2Object) -> Bool {
        (object.size ?? 0) <= R2Service.maxUploadBytes
    }

    /// 复制对象到 destinationKey（同桶，可含 / 表示文件夹）
    func copyObject(_ object: R2Object, to destinationKey: String) async -> Bool {
        let contentType = object.httpMetadata?.contentType ?? "application/octet-stream"
        return await runTransfer(object: object, label: String(localized: "复制中…")) { [service, accountId, bucketName] progress in
            try await service.copyObject(
                accountId: accountId, bucketName: bucketName,
                sourceKey: object.key, destinationKey: destinationKey,
                contentType: contentType, onProgress: progress
            )
        }
    }

    /// 移动 / 重命名对象到 destinationKey（同桶）
    func moveObject(_ object: R2Object, to destinationKey: String) async -> Bool {
        let contentType = object.httpMetadata?.contentType ?? "application/octet-stream"
        return await runTransfer(object: object, label: String(localized: "移动中…")) { [service, accountId, bucketName] progress in
            try await service.moveObject(
                accountId: accountId, bucketName: bucketName,
                sourceKey: object.key, destinationKey: destinationKey,
                contentType: contentType, onProgress: progress
            )
        }
    }

    /// 统一执行：iOS 26 且对象较大走系统连续后台任务（系统进度条 + 可取消），
    /// 否则前台执行并回报 transferProgress。提交失败自动回退前台。
    private func runTransfer(
        object: R2Object,
        label: String,
        operation: @escaping @Sendable (@escaping @Sendable (Double) -> Void) async throws -> Void
    ) async -> Bool {
        guard !isTransferring else { return false }
        guard canTransfer(object) else {
            error = String(localized: "对象超过 300 MB，受 Cloudflare API 限制无法在 App 内复制或移动")
            return false
        }
        isTransferring = true
        transferProgress = 0
        transferLabel = label
        error = nil
        defer { isTransferring = false; transferLabel = nil; transferProgress = 0 }

        let foreground: @Sendable (Double) -> Void = { fraction in
            Task { @MainActor in self.transferProgress = fraction }
        }
        do {
            if #available(iOS 26.0, *), (object.size ?? 0) > 8 * 1024 * 1024 {
                do {
                    try await ContinuedTaskRunner.run(title: label, subtitle: bucketName) { progress, _ in
                        try await operation(progress)
                    }
                } catch is ContinuedTaskRunner.SubmitFailed {
                    try await operation(foreground)     // 不支持 / 已有任务在跑 → 前台执行
                }
            } else {
                try await operation(foreground)
            }
            didTransfer.toggle()
            await load()
            return true
        } catch is CancellationError {
            return false
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }
}

// MARK: - R2 桶设置（公开访问 / CORS）

@Observable
@MainActor
final class R2BucketSettingsViewModel {

    var managedDomain: R2ManagedDomain?
    var customDomains: [R2CustomDomain] = []
    var corsRules: [R2CorsRule] = []
    var isLoading = false
    var isSaving = false
    var error: String?
    var didChange = false      // sensoryFeedback 触发器

    private let service: R2Service
    private let accountId: String
    let bucketName: String

    init(service: R2Service, accountId: String, bucketName: String) {
        self.service = service
        self.accountId = accountId
        self.bucketName = bucketName
    }

    func load() async {
        isLoading = true
        error = nil
        // 三块各自 best-effort：某块不可用（如桶从未设过 CORS 回 404）不连累其余
        managedDomain = try? await service.managedDomain(accountId: accountId, bucketName: bucketName)
        customDomains = (try? await service.customDomains(accountId: accountId, bucketName: bucketName)) ?? []
        corsRules = ((try? await service.corsPolicy(accountId: accountId, bucketName: bucketName))?.rules) ?? []
        isLoading = false
    }

    func setManagedEnabled(_ enabled: Bool) async {
        await mutate {
            try await service.setManagedDomainEnabled(accountId: accountId, bucketName: bucketName, enabled: enabled)
            managedDomain = try? await service.managedDomain(accountId: accountId, bucketName: bucketName)
        }
    }

    func removeCustomDomain(_ domain: String) async {
        await mutate {
            try await service.removeCustomDomain(accountId: accountId, bucketName: bucketName, domain: domain)
            customDomains.removeAll { $0.domain == domain }
        }
    }

    /// 追加一条 CORS 规则（R2 是整组 PUT，回写现有 + 新规则）
    func addCorsRule(origins: [String], methods: [String], maxAgeSeconds: Int?) async {
        let rule = R2CorsRule(
            id: nil,
            allowed: R2CorsAllowed(methods: methods, origins: origins, headers: nil),
            exposeHeaders: nil,
            maxAgeSeconds: maxAgeSeconds
        )
        await mutate {
            let next = corsRules + [rule]
            try await service.putCorsPolicy(accountId: accountId, bucketName: bucketName, policy: R2CorsPolicy(rules: next))
            corsRules = next
        }
    }

    func deleteCorsRule(at index: Int) async {
        guard corsRules.indices.contains(index) else { return }
        var next = corsRules
        next.remove(at: index)
        await mutate {
            if next.isEmpty {
                try await service.deleteCorsPolicy(accountId: accountId, bucketName: bucketName)
            } else {
                try await service.putCorsPolicy(accountId: accountId, bucketName: bucketName, policy: R2CorsPolicy(rules: next))
            }
            corsRules = next
        }
    }

    func clearCors() async {
        await mutate {
            try await service.deleteCorsPolicy(accountId: accountId, bucketName: bucketName)
            corsRules = []
        }
    }

    private func mutate(_ body: () async throws -> Void) async {
        guard !isSaving else { return }
        isSaving = true
        error = nil
        defer { isSaving = false }
        do {
            try await body()
            didChange.toggle()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - D1

@Observable
@MainActor
final class D1DatabaseListViewModel {

    var databases: [D1Database] = []
    var isLoading = false
    var error: String?
    var isCreating = false
    var didCreate = false      // sensoryFeedback 触发器
    var isDeleting = false
    var didDelete = false      // sensoryFeedback 触发器

    private let service: D1Service

    init(service: D1Service) {
        self.service = service
    }

    /// 创建数据库：成功后把新库插到列表顶端（新库为空，无需回填详情），返回 true。
    func create(accountId: String, name: String, locationHint: String?) async -> Bool {
        guard !isCreating else { return false }
        isCreating = true
        error = nil
        defer { isCreating = false }
        do {
            let created = try await service.createDatabase(
                accountId: accountId, name: name, locationHint: locationHint
            )
            databases.insert(created, at: 0)
            didCreate.toggle()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    /// 删除数据库：成功后从列表移除，返回 true。不可恢复，调用前须经二次确认。
    func delete(accountId: String, database: D1Database) async -> Bool {
        guard !isDeleting else { return false }
        isDeleting = true
        error = nil
        defer { isDeleting = false }
        do {
            try await service.deleteDatabase(accountId: accountId, databaseId: database.uuid)
            databases.removeAll { $0.uuid == database.uuid }
            didDelete.toggle()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func load(accountId: String) async {
        isLoading = true
        error = nil
        do {
            let list = try await service.listDatabases(accountId: accountId)
            // 先上列表让行立即可见，再并发拉详情回填表数量与体积
            databases = list
            isLoading = false

            let service = self.service
            let details = await withTaskGroup(of: D1Database?.self) { group in
                for database in list {
                    group.addTask {
                        try? await service.getDatabase(accountId: accountId, databaseId: database.uuid)
                    }
                }
                var byId: [String: D1Database] = [:]
                for await detail in group {
                    if let detail { byId[detail.uuid] = detail }
                }
                return byId
            }
            if !details.isEmpty {
                databases = list.map { details[$0.uuid] ?? $0 }
            }
        } catch {
            self.error = error.localizedDescription
            isLoading = false
        }
    }
}

@Observable
@MainActor
final class D1QueryViewModel {

    var sql = "SELECT name FROM sqlite_master WHERE type='table';"
    var results: [D1QueryResult] = []
    var isRunning = false
    var error: String?
    var didRun = false      // sensoryFeedback 触发器

    /// 数据库内的用户表（排除 sqlite_* 与 D1 内部表）
    private(set) var tables: [String] = []
    private(set) var tablesLoaded = false

    private let service: D1Service
    private let accountId: String
    private let databaseId: String

    init(service: D1Service, accountId: String, databaseId: String) {
        self.service = service
        self.accountId = accountId
        self.databaseId = databaseId
    }

    func loadTables() async {
        guard !tablesLoaded else { return }
        let sql = """
        SELECT name FROM sqlite_master \
        WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE '_cf_%' \
        ORDER BY name
        """
        guard let results = try? await service.query(accountId: accountId, databaseId: databaseId, sql: sql) else { return }
        tables = (results.first?.results ?? []).compactMap { row in
            if case .string(let name) = row["name"] { return name }
            return nil
        }
        tablesLoaded = true
    }

    func run() async {
        let statement = sql.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !statement.isEmpty, !isRunning else { return }
        isRunning = true
        error = nil
        do {
            results = try await service.query(accountId: accountId, databaseId: databaseId, sql: statement)
            didRun.toggle()
        } catch {
            self.error = error.localizedDescription
            results = []
        }
        isRunning = false
    }
}

@Observable
@MainActor
final class D1TableViewModel {

    private(set) var columns: [D1Column] = []
    private(set) var rows: [[String: JSONValue]] = []
    private(set) var hasMore = false
    var isLoading = false
    var isSaving = false
    var error: String?
    var didSave = false

    /// 行编辑用的 rowid 键（别名避免与同名列冲突）
    static let rowidKey = "_oc_rowid_"

    private var offset = 0
    private let pageSize = 50
    private let service: D1Service
    private let accountId: String
    private let databaseId: String
    let tableName: String

    init(service: D1Service, accountId: String, databaseId: String, tableName: String) {
        self.service = service
        self.accountId = accountId
        self.databaseId = databaseId
        self.tableName = tableName
    }

    private var quotedTable: String {
        "\"" + tableName.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    private func quoted(_ identifier: String) -> String {
        "\"" + identifier.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    func load() async {
        isLoading = true
        error = nil
        do {
            if columns.isEmpty {
                let info = try await service.query(
                    accountId: accountId, databaseId: databaseId,
                    sql: "PRAGMA table_info(\(quotedTable))"
                )
                columns = (info.first?.results ?? []).compactMap { row in
                    guard case .string(let name) = row["name"] else { return nil }
                    let type = row["type"]?.displayText ?? ""
                    let pk = (row["pk"]?.displayText ?? "0") != "0"
                    return D1Column(name: name, type: type, isPrimaryKey: pk)
                }
            }
            offset = 0
            rows = try await fetchPage(offset: 0)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func loadMore() async {
        guard hasMore, !isLoading else { return }
        isLoading = true
        do {
            // 先取下一页，成功后再推进 offset；否则瞬时失败会永久跳过这一页
            let next = try await fetchPage(offset: offset + pageSize)
            offset += pageSize
            rows.append(contentsOf: next)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private func fetchPage(offset: Int) async throws -> [[String: JSONValue]] {
        // 多取 1 行用于判断是否还有下一页
        let sql = "SELECT rowid AS \(Self.rowidKey), * FROM \(quotedTable) LIMIT \(pageSize + 1) OFFSET \(offset)"
        let results = try await service.query(accountId: accountId, databaseId: databaseId, sql: sql)
        var page = results.first?.results ?? []
        hasMore = page.count > pageSize
        if hasMore { page.removeLast() }
        return page
    }

    /// 仅更新变更列（参数化，rowid 定位）。成功返回 true 并重载当前数据。
    func updateRow(rowid: String, changes: [String: String]) async -> Bool {
        guard !changes.isEmpty, !isSaving else { return changes.isEmpty }
        isSaving = true
        error = nil
        defer { isSaving = false }
        do {
            let assignments = changes.keys.map { "\(quoted($0)) = ?" }.joined(separator: ", ")
            let sql = "UPDATE \(quotedTable) SET \(assignments) WHERE rowid = ?"
            let params = changes.keys.map { changes[$0]! } + [rowid]
            _ = try await service.query(accountId: accountId, databaseId: databaseId, sql: sql, params: params)
            didSave.toggle()
            await load()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func deleteRow(rowid: String) async -> Bool {
        error = nil
        do {
            _ = try await service.query(
                accountId: accountId, databaseId: databaseId,
                sql: "DELETE FROM \(quotedTable) WHERE rowid = ?",
                params: [rowid]
            )
            await load()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }
}

// MARK: - KV

@Observable
@MainActor
final class KVNamespaceListViewModel {

    var namespaces: [KVNamespace] = []
    var isLoading = false
    var error: String?
    var isCreating = false
    var didCreate = false      // sensoryFeedback 触发器
    var isDeleting = false
    var didDelete = false      // sensoryFeedback 触发器

    private let service: KVService

    init(service: KVService) {
        self.service = service
    }

    /// 创建命名空间：成功后插到列表顶端，返回 true。
    func create(accountId: String, title: String) async -> Bool {
        guard !isCreating else { return false }
        isCreating = true
        error = nil
        defer { isCreating = false }
        do {
            let created = try await service.createNamespace(accountId: accountId, title: title)
            namespaces.insert(created, at: 0)
            didCreate.toggle()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    /// 删除命名空间：成功后从列表移除，返回 true。连同全部键值不可恢复，删除前须经二次确认。
    func delete(accountId: String, namespace: KVNamespace) async -> Bool {
        guard !isDeleting else { return false }
        isDeleting = true
        error = nil
        defer { isDeleting = false }
        do {
            try await service.deleteNamespace(accountId: accountId, namespaceId: namespace.id)
            namespaces.removeAll { $0.id == namespace.id }
            didDelete.toggle()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func load(accountId: String) async {
        isLoading = true
        error = nil
        do {
            namespaces = try await service.listNamespaces(accountId: accountId)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}

@Observable
@MainActor
final class KVKeyListViewModel {

    var keys: [KVKey] = []
    var isLoading = false
    var isLoadingMore = false
    var error: String?
    private(set) var nextCursor: String?

    var hasMore: Bool { nextCursor != nil }

    private let service: KVService
    private let accountId: String
    private let namespaceId: String
    /// 进行中的加载任务（见 ZoneListViewModel：独立 Task 承载加载，避免下拉手势取消导致 .cancelled 误报）
    private var loadTask: Task<Void, Never>?

    init(service: KVService, accountId: String, namespaceId: String) {
        self.service = service
        self.accountId = accountId
        self.namespaceId = namespaceId
    }

    func load() async {
        // 复用进行中的加载，并把网络加载放进独立 Task：下拉手势 / searchable 取消
        // .refreshable 子任务时不波及加载，避免 URLError.cancelled 误报为加载失败
        if let loadTask {
            await loadTask.value
            return
        }
        let task = Task { [weak self] in
            guard let self else { return }
            await self.fetchKeys()
        }
        loadTask = task
        defer { loadTask = nil }
        await task.value
    }

    private func fetchKeys() async {
        isLoading = true
        error = nil
        do {
            let page = try await service.listKeys(accountId: accountId, namespaceId: namespaceId)
            keys = page.keys
            nextCursor = page.nextCursor
        } catch is CancellationError {
            // 任务取消属正常生命周期，不算加载失败
        } catch let urlError as URLError where urlError.code == .cancelled {
            // URLSession 把任务取消转成 .cancelled，同样不展示为错误
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func loadMore() async {
        guard let cursor = nextCursor, !isLoadingMore else { return }
        isLoadingMore = true
        do {
            let page = try await service.listKeys(accountId: accountId, namespaceId: namespaceId, cursor: cursor)
            keys.append(contentsOf: page.keys)
            nextCursor = page.nextCursor
        } catch {
            self.error = error.localizedDescription
        }
        isLoadingMore = false
    }

    /// 删除成功返回 true 并从列表移除
    func delete(key: String) async -> Bool {
        do {
            try await service.deleteKey(accountId: accountId, namespaceId: namespaceId, key: key)
            keys.removeAll { $0.name == key }
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }
}

@Observable
@MainActor
final class KVValueViewModel {

    var valueText = ""
    var isBinary = false
    var byteCount = 0
    var isLoading = false
    var isSaving = false
    var error: String?
    var didSave = false     // sensoryFeedback 触发器

    private let service: KVService
    private let accountId: String
    private let namespaceId: String
    let key: String

    init(service: KVService, accountId: String, namespaceId: String, key: String) {
        self.service = service
        self.accountId = accountId
        self.namespaceId = namespaceId
        self.key = key
    }

    func load() async {
        isLoading = true
        error = nil
        do {
            let data = try await service.getValue(accountId: accountId, namespaceId: namespaceId, key: key)
            byteCount = data.count
            if let text = String(data: data, encoding: .utf8) {
                valueText = text
                isBinary = false
            } else {
                valueText = ""
                isBinary = true
            }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    /// 保存成功返回 true
    func save() async -> Bool {
        guard !isBinary, !isSaving else { return false }
        isSaving = true
        error = nil
        do {
            try await service.putValue(accountId: accountId, namespaceId: namespaceId, key: key, value: valueText)
            byteCount = valueText.utf8.count
            didSave.toggle()
            isSaving = false
            return true
        } catch {
            self.error = error.localizedDescription
            isSaving = false
            return false
        }
    }
}
