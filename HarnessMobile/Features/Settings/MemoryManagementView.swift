import SwiftUI
import UniformTypeIdentifiers

struct MemoryManagementView: View {
    @Environment(AppModel.self) private var model
    @State private var recordPendingDeletion: MemoryRecord?
    @State private var isPreparingExport = false
    @State private var isFileExporterPresented = false
    @State private var exportDocument: ConversationExportFileDocument?

    var body: some View {
        List {
            sessionSection

            Section {
                if model.memoryRecords.isEmpty {
                    Label("No saved memory", systemImage: "brain")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.memoryRecords) { record in
                        MemoryRecordRow(record: record) {
                            recordPendingDeletion = record
                        }
                    }
                }
                DisclosureGroup("Storage and sending scope") {
                    Text("Memories are stored only on the device. Only content the model explicitly saves via memory_write is written; a whole conversation is never copied automatically. Content that is read or injected may be sent to the model provider you configured.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, HarnessTheme.Spacing.xSmall)
                }
            } header: {
                Label("Saved memory", systemImage: "brain.head.profile")
            }

            Section {
                Button {
                    prepareExport()
                } label: {
                    Label(isPreparingExport ? "Preparing export" : "Export JSON", systemImage: "square.and.arrow.up")
                }
                .disabled(isPreparingExport)
                .accessibilityIdentifier("memory-export-json")
            } header: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
        }
        .listStyle(.insetGrouped)
        .environment(\.defaultMinListRowHeight, 44)
        .scrollContentBackground(.hidden)
        .background(HarnessTheme.pageBackground)
        .navigationTitle("Memory")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: model.activeSessionID) {
            await model.refreshMemory()
        }
        .refreshable {
            await model.refreshMemory()
        }
        .confirmationDialog(
            "Delete this memory?",
            isPresented: Binding(
                get: { recordPendingDeletion != nil },
                set: { if !$0 { recordPendingDeletion = nil } }
            ),
            titleVisibility: .visible,
            presenting: recordPendingDeletion
        ) { record in
            Button("Delete", role: .destructive) {
                Task { await model.deleteMemory(id: record.id) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { record in
            Text("This permanently deletes this \(scopeLabel(for: record)) memory and cannot be undone.")
        }
        .fileExporter(
            isPresented: $isFileExporterPresented,
            document: exportDocument,
            contentType: .json,
            defaultFilename: "Harness-Memory"
        ) { result in
            exportDocument = nil
            if case let .failure(error) = result {
                model.presentError(error)
            }
        }
    }

    private func prepareExport() {
        guard !isPreparingExport else { return }
        isPreparingExport = true
        Task { @MainActor in
            defer { isPreparingExport = false }
            do {
                exportDocument = ConversationExportFileDocument(data: try await model.memoryExportData())
                isFileExporterPresented = true
            } catch {
                model.presentError(error)
            }
        }
    }

    private var sessionSection: some View {
        Section {
            Toggle("Allow use of saved memories", isOn: memoryEnabledBinding)
                .disabled(!hasActiveSession)
                .accessibilityHint("When off, this session neither injects nor reads saved memory.")
            DisclosureGroup("About session memory") {
                Text(sessionExplanation)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, HarnessTheme.Spacing.xSmall)
            }
        } header: {
            Label("Current session", systemImage: "bubble.left.and.bubble.right")
        }
    }

    private var hasActiveSession: Bool {
        model.activeSessionID != nil
    }

    private var sessionExplanation: String {
        hasActiveSession
            ? "When off, this session does not inject or read saved memories. Turning it back on does not delete any records."
            : "There is no active session, so this switch cannot be changed."
    }

    private var memoryEnabledBinding: Binding<Bool> {
        Binding(
            get: { model.isMemoryEnabledForActiveSession },
            set: { isEnabled in
                Task { await model.setMemoryEnabledForActiveSession(isEnabled) }
            }
        )
    }

    private func scopeLabel(for record: MemoryRecord) -> String {
        switch record.scope {
        case .global:
            "Global"
        case .session:
            "Session scope"
        }
    }
}

private struct MemoryRecordRow: View {
    let record: MemoryRecord
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: HarnessTheme.Spacing.medium) {
            HarnessIconTile(
                systemImage: record.scope == .global ? "globe" : "bubble.left.and.bubble.right",
                tint: record.scope == .global ? .accentColor : .secondary
            )

            VStack(alignment: .leading, spacing: HarnessTheme.Spacing.small) {
                Text(record.content)
                    .lineLimit(4)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: HarnessTheme.Spacing.small) {
                        metadataPill
                        metadataText
                    }

                    VStack(alignment: .leading, spacing: HarnessTheme.Spacing.xSmall) {
                        metadataPill
                        metadataText
                    }
                }
            }

            Spacer(minLength: HarnessTheme.Spacing.small)

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Delete memory")
            .accessibilityHint("Delete this saved memory.")
        }
        .padding(.vertical, HarnessTheme.Spacing.xSmall)
        .accessibilityElement(children: .contain)
    }

    private var scopeLabel: String {
        switch record.scope {
        case .global:
            "Global"
        case .session:
            "Session scope"
        }
    }

    private var metadataPill: some View {
        HarnessStatusPill(
            title: scopeLabel,
            systemImage: record.scope == .global ? "globe" : "bubble.left",
            tint: record.scope == .global ? .accentColor : .secondary
        )
    }

    private var metadataText: some View {
        Text("\(record.provenance == .explicitModelWrite ? "Saved explicitly by the model" : "User managed") · \(record.createdAt, format: .dateTime.year().month().day().hour().minute())")
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
