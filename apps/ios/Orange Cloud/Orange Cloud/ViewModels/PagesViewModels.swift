//
//  PagesViewModels.swift
//  Orange Cloud
//
//  Cloudflare Pages：项目列表 + 项目详情（部署列表 + 重试/回滚/删除部署、改构建配置、删项目）。
//

import Foundation
import Observation

@Observable
@MainActor
final class PagesProjectListViewModel {

    private(set) var projects: [PagesProject] = []
    var isLoading = false
    var loaded = false
    var error: String?

    private let service: PagesService

    init(service: PagesService) {
        self.service = service
    }

    func load(accountId: String) async {
        isLoading = true
        error = nil
        do {
            projects = try await service.listProjects(accountId: accountId)
            loaded = true
        } catch is CancellationError {
            // 下拉刷新 / searchable 取消，不算加载失败
        } catch let urlError as URLError where urlError.code == .cancelled {
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}

@Observable
@MainActor
final class PagesProjectDetailViewModel {

    var project: PagesProject
    private(set) var deployments: [PagesDeployment] = []
    var isLoadingDeployments = false
    var deploymentsLoaded = false
    var isMutating = false
    var error: String?
    var didMutate = false      // sensoryFeedback 触发器

    private let service: PagesService
    let accountId: String

    var projectName: String { project.name }

    init(project: PagesProject, accountId: String, service: PagesService) {
        self.project = project
        self.accountId = accountId
        self.service = service
    }

    func loadDeployments() async {
        isLoadingDeployments = true
        error = nil
        do {
            deployments = try await service.listDeployments(accountId: accountId, projectName: project.name)
            deploymentsLoaded = true
        } catch is CancellationError {
        } catch let urlError as URLError where urlError.code == .cancelled {
        } catch {
            self.error = error.localizedDescription
        }
        isLoadingDeployments = false
    }

    func refreshProject() async {
        if let updated = try? await service.getProject(accountId: accountId, projectName: project.name) {
            project = updated
        }
    }

    func retry(_ deployment: PagesDeployment) async -> Bool {
        guard !isMutating else { return false }
        isMutating = true
        error = nil
        defer { isMutating = false }
        do {
            _ = try await service.retryDeployment(accountId: accountId, projectName: project.name, deploymentId: deployment.id)
            await loadDeployments()
            didMutate.toggle()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func rollback(_ deployment: PagesDeployment) async -> Bool {
        guard !isMutating else { return false }
        isMutating = true
        error = nil
        defer { isMutating = false }
        do {
            _ = try await service.rollbackDeployment(accountId: accountId, projectName: project.name, deploymentId: deployment.id)
            await loadDeployments()
            await refreshProject()
            didMutate.toggle()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func deleteDeployment(_ deployment: PagesDeployment) async -> Bool {
        guard !isMutating else { return false }
        isMutating = true
        error = nil
        defer { isMutating = false }
        do {
            try await service.deleteDeployment(accountId: accountId, projectName: project.name, deploymentId: deployment.id)
            deployments.removeAll { $0.id == deployment.id }
            didMutate.toggle()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    /// 改构建配置 / 生产分支（PATCH 顶层合并）
    func updateBuildConfig(_ build: PagesBuildConfig, productionBranch: String?) async -> Bool {
        guard !isMutating else { return false }
        isMutating = true
        error = nil
        defer { isMutating = false }
        do {
            project = try await service.updateProject(
                accountId: accountId, projectName: project.name,
                update: PagesProjectUpdate(buildConfig: build, productionBranch: productionBranch)
            )
            didMutate.toggle()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func deleteProject() async -> Bool {
        guard !isMutating else { return false }
        isMutating = true
        error = nil
        defer { isMutating = false }
        do {
            try await service.deleteProject(accountId: accountId, projectName: project.name)
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }
}
