//
//  PagesProjectListView.swift
//  Orange Cloud
//
//  Cloudflare Pages 项目列表（account 级）。入口在 Workers Tab 顶部。
//

import SwiftUI

struct PagesProjectListView: View {

    let session: SessionStore

    @State private var viewModel: PagesProjectListViewModel
    @State private var searchText = ""

    init(session: SessionStore) {
        self.session = session
        _viewModel = State(initialValue: PagesProjectListViewModel(service: session.pagesService))
    }

    private var filtered: [PagesProject] {
        guard !searchText.isEmpty else { return viewModel.projects }
        return viewModel.projects.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        Group {
            if viewModel.isLoading && !viewModel.loaded {
                SkeletonList(rows: 6, trailing: true)
            } else if viewModel.projects.isEmpty {
                ContentUnavailableView {
                    Label("没有 Pages 项目", systemImage: "doc.richtext")
                } description: {
                    Text("在 Cloudflare Dashboard 创建 Pages 项目后，在此查看部署、重试 / 回滚与构建配置。")
                }
            } else if filtered.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                List {
                    Section {
                        ForEach(filtered) { project in
                            NavigationLink {
                                PagesProjectDetailView(project: project, session: session)
                            } label: {
                                PagesProjectRow(project: project)
                            }
                        }
                    } footer: {
                        Text("\(viewModel.projects.count) 个项目")
                    }
                    .glassRow()
                }
                .scrollContentBackground(.hidden)
                .refreshable { await load() }
            }
        }
        .background { SkyBackground() }
        .navigationTitle(Text(verbatim: "Pages"))
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "搜索项目")
        .task { await load() }
        .alert("出错了", isPresented: .init(
            get: { viewModel.error != nil }, set: { if !$0 { viewModel.error = nil } }
        )) {
            Button("好", role: .cancel) {}
        } message: {
            Text(viewModel.error ?? "")
        }
    }

    private func load() async {
        await session.ensureAccounts()
        guard let accountId = session.selectedAccount?.id else { return }
        await viewModel.load(accountId: accountId)
    }
}

private struct PagesProjectRow: View {
    let project: PagesProject
    var body: some View {
        HStack(spacing: 12) {
            TintIcon(systemImage: "doc.richtext", color: .ocOrange)
            VStack(alignment: .leading, spacing: 2) {
                Text(project.name)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                if let sub = project.subdomain {
                    Text(sub)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            Spacer()
            if let status = project.latestDeployment?.status, status != .unknown {
                PagesStatusBadge(status: status)
            }
        }
        .padding(.vertical, 2)
    }
}

/// 部署状态徽章（列表 / 详情 / 阶段共用）
struct PagesStatusBadge: View {
    let status: PagesDeployStatus
    var body: some View {
        Text(status.label)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.14), in: Capsule())
    }
    private var color: Color {
        switch status {
        case .success:            .green
        case .active, .idle:      .orange
        case .failure:            .red
        case .canceled, .unknown: .gray
        }
    }
}
