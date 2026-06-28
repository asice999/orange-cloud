//
//  QueuesView.swift
//  Orange Cloud
//
//  Cloudflare Queues 列表 + 新建 / 删除。account 级，读 queues.read / 写 queues.write。
//

import SwiftUI

struct QueuesView: View {

    let session: SessionStore

    @Environment(AuthManager.self) private var auth
    @State private var vm: QueuesViewModel?
    @State private var showCreate = false
    @State private var deleteTarget: CFQueue?
    @State private var writeDenied = false

    private var canWrite: Bool { auth.hasScope("queues.write") }

    var body: some View {
        Group {
            if let vm { content(vm) } else { ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity) }
        }
        .background { SkyBackground() }
        .navigationTitle("Queues")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if vm != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("新建队列", systemImage: "plus") {
                        if canWrite { showCreate = true } else { writeDenied = true }
                    }
                }
            }
        }
        .sheet(isPresented: $showCreate) {
            if let vm { QueueCreateView(viewModel: vm) }
        }
        .alert("权限不足", isPresented: $writeDenied) {
            Button("好", role: .cancel) {}
        } message: {
            Text("当前授权未包含 Queues 写权限（queues.write）。\n请在设置中退出登录后重新授权以启用此功能。")
        }
        .confirmationDialog(
            deleteTarget.map { String(localized: "删除队列「\($0.name)」？") } ?? "",
            isPresented: Binding(get: { deleteTarget != nil }, set: { if !$0 { deleteTarget = nil } }),
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                if let q = deleteTarget, let vm { Task { await vm.delete(q) } }
            }
        } message: {
            Text("删除后该队列及其未消费消息将被移除，不可撤销。")
        }
        .task {
            await session.ensureAccounts()
            guard vm == nil else { return }
            let model = QueuesViewModel(service: session.queueService, accountId: session.selectedAccount?.id)
            vm = model
            await model.load()
        }
    }

    @ViewBuilder
    private func content(_ vm: QueuesViewModel) -> some View {
        if vm.isLoading && !vm.loaded {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if vm.queues.isEmpty {
            ContentUnavailableView {
                Label("没有队列", systemImage: "tray.2")
            } description: {
                Text(vm.error ?? String(localized: "该账号下还没有 Queue。"))
            } actions: {
                if canWrite {
                    Button("新建队列") { showCreate = true }
                        .buttonStyle(.borderedProminent).tint(Color.ocOrangePressed).fontWeight(.bold)
                }
            }
        } else {
            List {
                Section {
                    ForEach(vm.queues) { queue in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(queue.name).font(.callout.weight(.semibold)).lineLimit(1)
                            Text("\(queue.producers?.count ?? 0) 生产者 · \(queue.consumers?.count ?? 0) 消费者")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                        .swipeActions(edge: .trailing) {
                            if canWrite {
                                Button(role: .destructive) { deleteTarget = queue } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                        }
                    }
                } footer: {
                    Text("Cloudflare Queues：生产者 / 消费者绑定在 Worker 中配置。")
                }
                .glassRow()
            }
            .daybreakList()
            .refreshable { await vm.load() }
            .sensoryFeedback(.success, trigger: vm.didChange)
        }
    }
}

private struct QueueCreateView: View {
    let viewModel: QueuesViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""

    private var trimmed: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canSave: Bool { !trimmed.isEmpty && !viewModel.isSaving }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("队列名称", text: $name)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .font(.callout.monospaced())
                } footer: {
                    Text("小写字母 / 数字 / 连字符。")
                }
                if let error = viewModel.error {
                    Section { Text(error).font(.footnote).foregroundStyle(.red) }
                }
            }
            .navigationTitle("新建队列")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { if await viewModel.create(name: trimmed) { dismiss() } }
                    } label: {
                        if viewModel.isSaving { ProgressView() } else { Text("创建").fontWeight(.semibold) }
                    }
                    .disabled(!canSave)
                }
            }
            .interactiveDismissDisabled(viewModel.isSaving)
            .onAppear { viewModel.error = nil }
        }
    }
}
