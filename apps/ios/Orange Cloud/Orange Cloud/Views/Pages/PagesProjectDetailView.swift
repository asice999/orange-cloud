//
//  PagesProjectDetailView.swift
//  Orange Cloud
//
//  Pages 项目详情：信息 + 部署列表（→ 重试 / 回滚 / 删除）+ 环境变量（只读）+ 构建配置 + 删项目。
//

import SwiftUI

struct PagesProjectDetailView: View {

    @State private var viewModel: PagesProjectDetailViewModel
    @State private var showDeleteConfirm = false
    @Environment(\.dismiss) private var dismiss

    init(project: PagesProject, session: SessionStore) {
        _viewModel = State(initialValue: PagesProjectDetailViewModel(
            project: project,
            accountId: session.selectedAccount?.id ?? "",
            service: session.pagesService
        ))
    }

    private var project: PagesProject { viewModel.project }

    var body: some View {
        List {
            infoSection
            deploymentsSection
            envVarsSection
            configSection
            dangerSection
        }
        .daybreakList()
        .navigationTitle(project.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.loadDeployments() }
        .refreshable {
            await viewModel.refreshProject()
            await viewModel.loadDeployments()
        }
        .sensoryFeedback(.success, trigger: viewModel.didMutate)
        .confirmationDialog("删除项目「\(project.name)」？", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("删除项目", role: .destructive) {
                Task { if await viewModel.deleteProject() { dismiss() } }
            }
        } message: {
            Text("将移除该项目的所有部署，且不可撤销。")
        }
        .alert("出错了", isPresented: .init(
            get: { viewModel.error != nil }, set: { if !$0 { viewModel.error = nil } }
        )) {
            Button("好", role: .cancel) {}
        } message: {
            Text(viewModel.error ?? "")
        }
    }

    // MARK: - 信息

    private var infoSection: some View {
        Section {
            if let sub = project.subdomain, let url = URL(string: "https://\(sub)") {
                Link(destination: url) {
                    HStack {
                        Text("访问地址")
                        Spacer()
                        Text(sub).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                        Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(.tertiary)
                    }
                }
            }
            if let branch = project.productionBranch {
                infoRow("生产分支", value: branch)
            }
            if let repo = project.source?.config?.repoLabel {
                infoRow(project.source?.type == "gitlab" ? "GitLab" : "GitHub", value: repo)
            }
            if let domains = project.domains, !domains.isEmpty {
                ForEach(domains, id: \.self) { domain in
                    infoRow("自定义域名", value: domain)
                }
            }
            if let date = WorkerScript.parseDate(project.createdOn) {
                infoRow("创建于", value: date.formatted(.dateTime.year().month().day()))
            }
        } header: {
            Text("项目")
        }
        .glassRow()
    }

    // MARK: - 部署

    private var deploymentsSection: some View {
        Section {
            if viewModel.isLoadingDeployments && !viewModel.deploymentsLoaded {
                ProgressView().frame(maxWidth: .infinity)
            } else if viewModel.deployments.isEmpty {
                Text("暂无部署").font(.footnote).foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.deployments.prefix(20)) { dep in
                    NavigationLink {
                        PagesDeploymentDetailView(deployment: dep, viewModel: viewModel)
                    } label: {
                        deploymentRow(dep)
                    }
                }
            }
        } header: {
            Text("部署")
        } footer: {
            Text("点按查看构建阶段，并可重试 / 回滚 / 删除。")
        }
        .glassRow()
    }

    private func deploymentRow(_ dep: PagesDeployment) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    PagesStatusBadge(status: dep.status)
                    Text(dep.isProduction ? String(localized: "生产") : String(localized: "预览"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                if let msg = dep.deploymentTrigger?.metadata?.commitMessage, !msg.isEmpty {
                    Text(msg).font(.caption).foregroundStyle(.primary).lineLimit(1)
                } else if let branch = dep.deploymentTrigger?.metadata?.branch {
                    Text(branch).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer()
            if let date = WorkerScript.parseDate(dep.createdOn) {
                Text(date, format: .relative(presentation: .named))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - 环境变量（只读）

    @ViewBuilder
    private var envVarsSection: some View {
        if let envVars = project.deploymentConfigs?.production?.envVars, !envVars.isEmpty {
            Section {
                ForEach(envVars.keys.sorted(), id: \.self) { key in
                    HStack {
                        Text(key).font(.callout.monospaced()).lineLimit(1)
                        Spacer()
                        if let v = envVars[key] {
                            Text(v.isSecret ? "••••••" : (v.value ?? ""))
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                }
            } header: {
                Text("生产环境变量")
            } footer: {
                Text("环境变量在 App 内只读；密钥值已隐藏。需修改请在 Cloudflare 控制台操作。")
            }
            .glassRow()
        }
    }

    // MARK: - 配置

    private var configSection: some View {
        Section {
            NavigationLink {
                PagesBuildConfigEditorView(viewModel: viewModel)
            } label: {
                HStack(spacing: 12) {
                    TintIcon(systemImage: "hammer", color: .blue)
                    Text("构建配置")
                }
            }
        } header: {
            Text("配置")
        }
        .glassRow()
    }

    // MARK: - 危险操作

    private var dangerSection: some View {
        Section {
            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                HStack(spacing: 12) {
                    TintIcon(systemImage: "trash", color: .red)
                    Text("删除项目")
                    if viewModel.isMutating {
                        Spacer()
                        ProgressView()
                    }
                }
            }
            .disabled(viewModel.isMutating)
        } footer: {
            Text("删除项目会移除所有部署，且不可撤销。")
        }
        .glassRow()
    }

    private func infoRow(_ title: LocalizedStringKey, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}
