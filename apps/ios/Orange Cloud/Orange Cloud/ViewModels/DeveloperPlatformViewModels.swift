//
//  DeveloperPlatformViewModels.swift
//  Orange Cloud
//
//  Queues / AI Gateway / Durable Objects / Workers AI 的 ViewModel。
//

import Foundation
import Observation

// MARK: - Queues

@Observable
@MainActor
final class QueuesViewModel {

    private(set) var queues: [CFQueue] = []
    var isLoading = false
    var loaded = false
    var isSaving = false
    var error: String?
    var didChange = false

    private let service: QueueService
    let accountId: String?

    init(service: QueueService, accountId: String?) {
        self.service = service
        self.accountId = accountId
    }

    func load() async {
        guard let accountId, !isLoading else { return }
        isLoading = true
        error = nil
        do {
            queues = try await service.list(accountId: accountId)
            loaded = true
        } catch is CancellationError {
        } catch let urlError as URLError where urlError.code == .cancelled {
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func create(name: String) async -> Bool {
        guard let accountId, !isSaving else { return false }
        isSaving = true
        error = nil
        defer { isSaving = false }
        do {
            let created = try await service.create(accountId: accountId, name: name)
            queues.insert(created, at: 0)
            didChange.toggle()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func delete(_ queue: CFQueue) async {
        guard let accountId, !isSaving else { return }
        isSaving = true
        error = nil
        defer { isSaving = false }
        do {
            try await service.delete(accountId: accountId, queueId: queue.queueId)
            queues.removeAll { $0.queueId == queue.queueId }
            didChange.toggle()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - AI Gateway

@Observable
@MainActor
final class AIGatewayViewModel {

    private(set) var gateways: [AIGateway] = []
    var isLoading = false
    var loaded = false
    var isSaving = false
    var error: String?
    var didChange = false

    private let service: AIGatewayService
    let accountId: String?

    init(service: AIGatewayService, accountId: String?) {
        self.service = service
        self.accountId = accountId
    }

    func load() async {
        guard let accountId, !isLoading else { return }
        isLoading = true
        error = nil
        do {
            gateways = try await service.list(accountId: accountId)
            loaded = true
        } catch is CancellationError {
        } catch let urlError as URLError where urlError.code == .cancelled {
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func create(_ body: AIGatewayCreate) async -> Bool {
        guard let accountId, !isSaving else { return false }
        isSaving = true
        error = nil
        defer { isSaving = false }
        do {
            let created = try await service.create(accountId: accountId, body: body)
            gateways.insert(created, at: 0)
            didChange.toggle()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func delete(_ gateway: AIGateway) async {
        guard let accountId, !isSaving else { return }
        isSaving = true
        error = nil
        defer { isSaving = false }
        do {
            try await service.delete(accountId: accountId, gatewayId: gateway.id)
            gateways.removeAll { $0.id == gateway.id }
            didChange.toggle()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - Durable Objects（只读）

@Observable
@MainActor
final class DurableObjectsViewModel {

    private(set) var namespaces: [DurableObjectNamespace] = []
    var isLoading = false
    var loaded = false
    var error: String?

    private let service: DurableObjectService
    let accountId: String?

    init(service: DurableObjectService, accountId: String?) {
        self.service = service
        self.accountId = accountId
    }

    func load() async {
        guard let accountId, !isLoading else { return }
        isLoading = true
        error = nil
        do {
            namespaces = try await service.listNamespaces(accountId: accountId)
            loaded = true
        } catch is CancellationError {
        } catch let urlError as URLError where urlError.code == .cancelled {
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Workers AI（只读模型目录）

@Observable
@MainActor
final class WorkersAIViewModel {

    private(set) var models: [AIModel] = []
    var isLoading = false
    var loaded = false
    var error: String?

    private let service: WorkersAIService
    let accountId: String?

    init(service: WorkersAIService, accountId: String?) {
        self.service = service
        self.accountId = accountId
    }

    /// 按任务类型分组（Text Generation / Text-to-Image 等）
    var grouped: [(task: String, models: [AIModel])] {
        let groups = Dictionary(grouping: models) { $0.taskName.isEmpty ? String(localized: "其它") : $0.taskName }
        return groups.map { (task: $0.key, models: $0.value.sorted { $0.shortName < $1.shortName }) }
            .sorted { $0.task < $1.task }
    }

    func load() async {
        guard let accountId, !isLoading else { return }
        isLoading = true
        error = nil
        do {
            models = try await service.listModels(accountId: accountId)
            loaded = true
        } catch is CancellationError {
        } catch let urlError as URLError where urlError.code == .cancelled {
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Hyperdrive

@Observable
@MainActor
final class HyperdriveViewModel {

    private(set) var configs: [HyperdriveConfig] = []
    var isLoading = false
    var loaded = false
    var isSaving = false
    var error: String?
    var didChange = false

    private let service: HyperdriveService
    let accountId: String?

    init(service: HyperdriveService, accountId: String?) {
        self.service = service
        self.accountId = accountId
    }

    func load() async {
        guard let accountId, !isLoading else { return }
        isLoading = true
        error = nil
        do {
            configs = try await service.list(accountId: accountId)
            loaded = true
        } catch is CancellationError {
        } catch let urlError as URLError where urlError.code == .cancelled {
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func create(_ body: HyperdriveCreate) async -> Bool {
        guard let accountId, !isSaving else { return false }
        isSaving = true
        error = nil
        defer { isSaving = false }
        do {
            let created = try await service.create(accountId: accountId, body: body)
            configs.insert(created, at: 0)
            didChange.toggle()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func delete(_ config: HyperdriveConfig) async {
        guard let accountId, !isSaving else { return }
        isSaving = true
        error = nil
        defer { isSaving = false }
        do {
            try await service.delete(accountId: accountId, configId: config.id)
            configs.removeAll { $0.id == config.id }
            didChange.toggle()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
