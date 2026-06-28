//
//  HyperdriveView.swift
//  Orange Cloud
//
//  Cloudflare Hyperdrive 列表 + 新建 / 删除。account 级，读 query-cache.read / 写 query-cache.write。
//  新建需源数据库连接信息（host/port/database/user/password）；密码为写专用，列表不回显。
//

import SwiftUI

struct HyperdriveView: View {

    let session: SessionStore

    @Environment(AuthManager.self) private var auth
    @State private var vm: HyperdriveViewModel?
    @State private var showCreate = false
    @State private var deleteTarget: HyperdriveConfig?
    @State private var writeDenied = false

    private var canWrite: Bool { auth.hasScope("query-cache.write") }

    var body: some View {
        Group {
            if let vm { content(vm) } else { ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity) }
        }
        .background { SkyBackground() }
        .navigationTitle("Hyperdrive")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if vm != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("新建配置", systemImage: "plus") {
                        if canWrite { showCreate = true } else { writeDenied = true }
                    }
                }
            }
        }
        .sheet(isPresented: $showCreate) {
            if let vm { HyperdriveCreateView(viewModel: vm) }
        }
        .alert("权限不足", isPresented: $writeDenied) {
            Button("好", role: .cancel) {}
        } message: {
            Text("当前授权未包含 Hyperdrive 写权限（query-cache.write）。\n请在设置中退出登录后重新授权以启用此功能。")
        }
        .confirmationDialog(
            deleteTarget.map { String(localized: "删除配置「\($0.displayName)」？") } ?? "",
            isPresented: Binding(get: { deleteTarget != nil }, set: { if !$0 { deleteTarget = nil } }),
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                if let c = deleteTarget, let vm { Task { await vm.delete(c) } }
            }
        } message: {
            Text("删除后引用该配置的 Worker 将无法连接，不可撤销。")
        }
        .task {
            await session.ensureAccounts()
            guard vm == nil else { return }
            let model = HyperdriveViewModel(service: session.hyperdriveService, accountId: session.selectedAccount?.id)
            vm = model
            await model.load()
        }
    }

    @ViewBuilder
    private func content(_ vm: HyperdriveViewModel) -> some View {
        if vm.isLoading && !vm.loaded {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if vm.configs.isEmpty {
            ContentUnavailableView {
                Label("没有 Hyperdrive 配置", systemImage: "bolt.horizontal.circle")
            } description: {
                Text(vm.error ?? String(localized: "该账号下还没有 Hyperdrive 配置。"))
            } actions: {
                if canWrite {
                    Button("新建配置") { showCreate = true }
                        .buttonStyle(.borderedProminent).tint(Color.ocOrangePressed).fontWeight(.bold)
                }
            }
        } else {
            List {
                Section {
                    ForEach(vm.configs) { config in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(config.displayName).font(.callout.weight(.semibold)).lineLimit(1)
                            if let origin = config.origin {
                                Text(origin.summary).font(.caption.monospaced())
                                    .foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                            }
                        }
                        .padding(.vertical, 2)
                        .swipeActions(edge: .trailing) {
                            if canWrite {
                                Button(role: .destructive) { deleteTarget = config } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                        }
                    }
                } footer: {
                    Text("Hyperdrive 为外部 Postgres / MySQL 提供连接池与查询缓存。")
                }
                .glassRow()
            }
            .daybreakList()
            .refreshable { await vm.load() }
            .sensoryFeedback(.success, trigger: vm.didChange)
        }
    }
}

private struct HyperdriveCreateView: View {
    let viewModel: HyperdriveViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var scheme: HyperdriveScheme = .postgres
    @State private var host = ""
    @State private var portText = "5432"
    @State private var database = ""
    @State private var user = ""
    @State private var password = ""

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var canSave: Bool {
        !trimmedName.isEmpty && !host.trimmingCharacters(in: .whitespaces).isEmpty
            && !database.trimmingCharacters(in: .whitespaces).isEmpty
            && !user.trimmingCharacters(in: .whitespaces).isEmpty
            && !password.isEmpty
            && Int(portText) != nil
            && !viewModel.isSaving
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("配置") {
                    TextField("名称", text: $name)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    Picker("数据库类型", selection: $scheme) {
                        ForEach(HyperdriveScheme.allCases) { Text($0.label).tag($0) }
                    }
                    .onChange(of: scheme) { _, new in portText = String(new.defaultPort) }
                }
                Section("源数据库连接") {
                    TextField("主机", text: $host)
                        .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                    TextField("端口", text: $portText).keyboardType(.numberPad)
                    TextField("数据库名", text: $database)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    TextField("用户名", text: $user)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    SecureField("密码", text: $password)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                }
                Section {} footer: {
                    Text("密码只用于建立连接，Cloudflare 不会再回显。请确保该数据库允许 Cloudflare 出口 IP 访问。")
                }
                if let error = viewModel.error {
                    Section { Text(error).font(.footnote).foregroundStyle(.red) }
                }
            }
            .navigationTitle("新建 Hyperdrive")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
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

    private func save() async {
        let body = HyperdriveCreate(
            name: trimmedName,
            origin: HyperdriveCreate.Origin(
                scheme: scheme.rawValue,
                host: host.trimmingCharacters(in: .whitespaces),
                port: Int(portText) ?? scheme.defaultPort,
                database: database.trimmingCharacters(in: .whitespaces),
                user: user.trimmingCharacters(in: .whitespaces),
                password: password
            )
        )
        if await viewModel.create(body) { dismiss() }
    }
}
