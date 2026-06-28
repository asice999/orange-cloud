//
//  WorkersAIView.swift
//  Orange Cloud
//
//  Workers AI 模型目录（只读浏览）。account 级，ai.read。
//  按任务类型分组，可搜索。模型推理（run）受输入 schema 各异，暂不在此提供。
//

import SwiftUI

struct WorkersAIView: View {

    let session: SessionStore
    @State private var vm: WorkersAIViewModel?
    @State private var searchText = ""

    var body: some View {
        Group {
            if let vm { content(vm) } else { ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity) }
        }
        .background { SkyBackground() }
        .navigationTitle("Workers AI")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "搜索模型")
        .task {
            await session.ensureAccounts()
            guard vm == nil else { return }
            let model = WorkersAIViewModel(service: session.workersAIService, accountId: session.selectedAccount?.id)
            vm = model
            await model.load()
        }
    }

    @ViewBuilder
    private func content(_ vm: WorkersAIViewModel) -> some View {
        if vm.isLoading && !vm.loaded {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if vm.models.isEmpty {
            ContentUnavailableView {
                Label("没有可用模型", systemImage: "brain")
            } description: {
                Text(vm.error ?? String(localized: "未能取到 Workers AI 模型目录。"))
            }
        } else {
            let groups = filteredGroups(vm)
            if groups.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                List {
                    ForEach(groups, id: \.task) { group in
                        Section {
                            ForEach(group.models) { model in
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(model.shortName).font(.callout.weight(.semibold)).lineLimit(1)
                                    if let desc = model.description, !desc.isEmpty {
                                        Text(desc).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                                    }
                                    Text(model.name ?? model.id)
                                        .font(.caption2.monospaced()).foregroundStyle(.tertiary)
                                        .lineLimit(1).truncationMode(.middle)
                                }
                                .padding(.vertical, 2)
                            }
                        } header: {
                            Text(group.task)
                        }
                        .glassRow()
                    }
                }
                .daybreakList()
                .refreshable { await vm.load() }
            }
        }
    }

    private func filteredGroups(_ vm: WorkersAIViewModel) -> [(task: String, models: [AIModel])] {
        guard !searchText.isEmpty else { return vm.grouped }
        return vm.grouped.compactMap { group in
            let matches = group.models.filter {
                $0.shortName.localizedCaseInsensitiveContains(searchText)
                    || ($0.name ?? "").localizedCaseInsensitiveContains(searchText)
                    || ($0.description ?? "").localizedCaseInsensitiveContains(searchText)
            }
            return matches.isEmpty ? nil : (task: group.task, models: matches)
        }
    }
}
