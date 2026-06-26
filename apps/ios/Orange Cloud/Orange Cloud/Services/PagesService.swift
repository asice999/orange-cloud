//
//  PagesService.swift
//  Orange Cloud
//
//  Cloudflare Pages（account 级）：项目与部署 CRUD。读 page.read，写 page.write。
//  端点核对自 Cloudflare 官方 SDK（cloudflare-python resources/pages）。
//

import Foundation

struct PagesService {

    private let client: CFAPIClient

    init(client: CFAPIClient) {
        self.client = client
    }

    // MARK: - 项目

    func listProjects(accountId: String) async throws -> [PagesProject] {
        let response: CFAPIResponse<[PagesProject]> = try await client.get(
            "accounts/\(accountId)/pages/projects"
        )
        guard response.success, let projects = response.result else {
            throw response.toAPIError()
        }
        return projects
    }

    func getProject(accountId: String, projectName: String) async throws -> PagesProject {
        let response: CFAPIResponse<PagesProject> = try await client.get(
            "accounts/\(accountId)/pages/projects/\(projectName)"
        )
        guard response.success, let project = response.result else {
            throw response.toAPIError()
        }
        return project
    }

    /// PATCH 项目（构建配置 / 生产分支）。仅传要改的字段，顶层合并。
    func updateProject(accountId: String, projectName: String, update: PagesProjectUpdate) async throws -> PagesProject {
        let response: CFAPIResponse<PagesProject> = try await client.patch(
            "accounts/\(accountId)/pages/projects/\(projectName)",
            body: update
        )
        guard response.success, let project = response.result else {
            throw response.toAPIError()
        }
        return project
    }

    func deleteProject(accountId: String, projectName: String) async throws {
        try await client.delete("accounts/\(accountId)/pages/projects/\(projectName)")
    }

    // MARK: - 部署

    func listDeployments(accountId: String, projectName: String) async throws -> [PagesDeployment] {
        let response: CFAPIResponse<[PagesDeployment]> = try await client.get(
            "accounts/\(accountId)/pages/projects/\(projectName)/deployments"
        )
        guard response.success, let deployments = response.result else {
            throw response.toAPIError()
        }
        return deployments
    }

    func getDeployment(accountId: String, projectName: String, deploymentId: String) async throws -> PagesDeployment {
        let response: CFAPIResponse<PagesDeployment> = try await client.get(
            "accounts/\(accountId)/pages/projects/\(projectName)/deployments/\(deploymentId)"
        )
        guard response.success, let deployment = response.result else {
            throw response.toAPIError()
        }
        return deployment
    }

    /// 重试部署（重新构建并部署）
    func retryDeployment(accountId: String, projectName: String, deploymentId: String) async throws -> PagesDeployment {
        let response: CFAPIResponse<PagesDeployment> = try await client.post(
            "accounts/\(accountId)/pages/projects/\(projectName)/deployments/\(deploymentId)/retry",
            body: PagesEmptyBody()
        )
        guard response.success, let deployment = response.result else {
            throw response.toAPIError()
        }
        return deployment
    }

    /// 回滚到某次部署（使其重新生效）
    func rollbackDeployment(accountId: String, projectName: String, deploymentId: String) async throws -> PagesDeployment {
        let response: CFAPIResponse<PagesDeployment> = try await client.post(
            "accounts/\(accountId)/pages/projects/\(projectName)/deployments/\(deploymentId)/rollback",
            body: PagesEmptyBody()
        )
        guard response.success, let deployment = response.result else {
            throw response.toAPIError()
        }
        return deployment
    }

    func deleteDeployment(accountId: String, projectName: String, deploymentId: String) async throws {
        try await client.delete("accounts/\(accountId)/pages/projects/\(projectName)/deployments/\(deploymentId)")
    }
}
