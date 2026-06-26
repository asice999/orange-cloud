//
//  PagesModels.swift
//  Orange Cloud
//
//  Cloudflare Pages（account 级）：项目 + 部署。读 page.read，写 page.write。
//  字段名核对自 Cloudflare 官方 SDK（cloudflare-python types/pages）。
//  注意：GET 项目时 secret_text 类型的环境变量 value 为 null（已脱敏），故 App 内环境变量只读展示。
//

import Foundation

// MARK: - 项目

nonisolated struct PagesProject: Codable, Identifiable, Sendable {
    let name:              String
    let subdomain:         String?
    let domains:           [String]?
    let productionBranch:  String?
    let createdOn:         String?
    let buildConfig:       PagesBuildConfig?
    let deploymentConfigs: PagesDeploymentConfigs?
    let latestDeployment:  PagesDeployment?
    let source:            PagesSource?

    var id: String { name }

    enum CodingKeys: String, CodingKey {
        case name, subdomain, domains, source
        case productionBranch  = "production_branch"
        case createdOn         = "created_on"
        case buildConfig       = "build_config"
        case deploymentConfigs = "deployment_configs"
        case latestDeployment  = "latest_deployment"
    }
}

nonisolated struct PagesBuildConfig: Codable, Sendable {
    var buildCommand:   String?
    var destinationDir: String?
    var rootDir:        String?

    enum CodingKeys: String, CodingKey {
        case buildCommand   = "build_command"
        case destinationDir = "destination_dir"
        case rootDir        = "root_dir"
    }
}

nonisolated struct PagesDeploymentConfigs: Codable, Sendable {
    var production: PagesEnvConfig?
    var preview:    PagesEnvConfig?
}

nonisolated struct PagesEnvConfig: Codable, Sendable {
    var envVars: [String: PagesEnvVar]?

    enum CodingKeys: String, CodingKey {
        case envVars = "env_vars"
    }
}

nonisolated struct PagesEnvVar: Codable, Sendable {
    var type:  String?     // plain_text | secret_text
    var value: String?     // secret_text 时为 null

    var isSecret: Bool { type == "secret_text" }
}

nonisolated struct PagesSource: Codable, Sendable {
    let type:   String?    // github | gitlab
    let config: PagesSourceConfig?
}

nonisolated struct PagesSourceConfig: Codable, Sendable {
    let owner:            String?
    let repoName:         String?
    let productionBranch: String?

    enum CodingKeys: String, CodingKey {
        case owner
        case repoName         = "repo_name"
        case productionBranch = "production_branch"
    }

    /// owner/repo 展示
    var repoLabel: String? {
        guard let repoName else { return nil }
        return owner.map { "\($0)/\(repoName)" } ?? repoName
    }
}

// MARK: - 部署

nonisolated struct PagesDeployment: Codable, Identifiable, Sendable {
    let id:                String
    let shortId:           String?
    let projectName:       String?
    let environment:       String?    // production | preview
    let url:               String?
    let createdOn:         String?
    let modifiedOn:        String?
    let aliases:           [String]?
    let isSkipped:         Bool?
    let latestStage:       PagesStage?
    let stages:            [PagesStage]?
    let deploymentTrigger: PagesDeploymentTrigger?

    enum CodingKeys: String, CodingKey {
        case id, environment, url, stages, aliases
        case shortId           = "short_id"
        case projectName       = "project_name"
        case createdOn         = "created_on"
        case modifiedOn        = "modified_on"
        case isSkipped         = "is_skipped"
        case latestStage       = "latest_stage"
        case deploymentTrigger = "deployment_trigger"
    }

    /// 整体状态（取最新阶段）
    var status: PagesDeployStatus { PagesDeployStatus(rawValue: latestStage?.status ?? "") ?? .unknown }

    var isProduction: Bool { environment == "production" }
}

nonisolated struct PagesStage: Codable, Identifiable, Sendable {
    let name:      String?
    let status:    String?    // success | idle | active | failure | canceled
    let startedOn: String?
    let endedOn:   String?

    var id: String { name ?? UUID().uuidString }

    enum CodingKeys: String, CodingKey {
        case name, status
        case startedOn = "started_on"
        case endedOn   = "ended_on"
    }

    var statusValue: PagesDeployStatus { PagesDeployStatus(rawValue: status ?? "") ?? .unknown }
}

nonisolated struct PagesDeploymentTrigger: Codable, Sendable {
    let type:     String?
    let metadata: PagesTriggerMetadata?
}

nonisolated struct PagesTriggerMetadata: Codable, Sendable {
    let branch:        String?
    let commitHash:    String?
    let commitMessage: String?

    enum CodingKeys: String, CodingKey {
        case branch
        case commitHash    = "commit_hash"
        case commitMessage = "commit_message"
    }

    /// 短哈希
    var shortHash: String? { commitHash.map { String($0.prefix(8)) } }
}

// MARK: - 部署状态

nonisolated enum PagesDeployStatus: String, Sendable {
    case success, idle, active, failure, canceled
    case unknown = ""

    var label: String {
        switch self {
        case .success:  String(localized: "成功")
        case .idle:     String(localized: "排队中")
        case .active:   String(localized: "进行中")
        case .failure:  String(localized: "失败")
        case .canceled: String(localized: "已取消")
        case .unknown:  String(localized: "未知")
        }
    }
}

// MARK: - 写入载荷

/// PATCH 项目：仅传要改的字段（顶层合并，省略字段不变）。环境变量不在此（脱敏风险，App 内只读）。
nonisolated struct PagesProjectUpdate: Codable, Sendable {
    var buildConfig:      PagesBuildConfig?
    var productionBranch: String?

    enum CodingKeys: String, CodingKey {
        case buildConfig      = "build_config"
        case productionBranch = "production_branch"
    }
}

/// retry / rollback 的空 POST 体
nonisolated struct PagesEmptyBody: Codable, Sendable {}
