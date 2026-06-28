//
//  DurableObjectsView.swift
//  Orange Cloud
//
//  Durable Objects 命名空间（只读）。account 级，workers-scripts.read。
//  命名空间由 Worker 迁移声明，API 不支持增删，故此处仅展示。
//

import SwiftUI

struct DurableObjectsView: View {

    let session: SessionStore
    @State private var vm: DurableObjectsViewModel?

    var body: some View {
        Group {
            if let vm { content(vm) } else { ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity) }
        }
        .background { SkyBackground() }
        .navigationTitle("Durable Objects")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await session.ensureAccounts()
            guard vm == nil else { return }
            let model = DurableObjectsViewModel(service: session.durableObjectService, accountId: session.selectedAccount?.id)
            vm = model
            await model.load()
        }
    }

    @ViewBuilder
    private func content(_ vm: DurableObjectsViewModel) -> some View {
        if vm.isLoading && !vm.loaded {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if vm.namespaces.isEmpty {
            ContentUnavailableView {
                Label("没有 Durable Objects", systemImage: "cube.transparent")
            } description: {
                Text(vm.error ?? String(localized: "该账号下还没有 Durable Object 命名空间。命名空间由 Worker 迁移声明。"))
            }
        } else {
            List {
                Section {
                    ForEach(vm.namespaces) { ns in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(ns.name ?? ns.className ?? ns.id)
                                    .font(.callout.weight(.semibold)).lineLimit(1)
                                if ns.useSqlite == true {
                                    Text("SQLite").font(.caption2.weight(.semibold))
                                        .foregroundStyle(Color.ocOrangeText)
                                        .padding(.horizontal, 6).padding(.vertical, 2)
                                        .background(Color.ocOrange.opacity(0.14), in: Capsule())
                                }
                            }
                            if let cls = ns.className {
                                Text(verbatim: "class \(cls)").font(.caption.monospaced()).foregroundStyle(.secondary).lineLimit(1)
                            }
                            if let script = ns.script {
                                Text(script).font(.caption2.monospaced()).foregroundStyle(.tertiary).lineLimit(1)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                } footer: {
                    Text("Durable Objects 命名空间（只读）。增删改请在 Worker 迁移中进行。")
                }
                .glassRow()
            }
            .daybreakList()
            .refreshable { await vm.load() }
        }
    }
}
