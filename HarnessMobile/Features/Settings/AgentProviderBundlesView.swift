import SwiftUI

struct AgentProviderBundlesView: View {
    @Environment(AppModel.self) private var model
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section {
                ForEach(model.providerBundles) { bundle in
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle(isOn: binding(for: bundle)) {
                            Label {
                                Text(bundle.displayName)
                            } icon: {
                                HarnessIconTile(
                                    systemImage: bundle.id == .codex ? "terminal" : "text.bubble",
                                    tint: bundle.enabled ? .accentColor : .secondary,
                                    size: 28
                                )
                            }
                        }
                        installStatus(for: bundle)
                        installActions(for: bundle)
                        Text("Pinned source: \(bundle.installPayload.packageName)@\(bundle.installPayload.version)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                DisclosureGroup("Install and security") {
                    Text("The URL, SHA-256, npm package identity, CLI name and commands all come from a built-in manifest that cannot be edited. Downloads are verified and replaced atomically; a failure or cancellation keeps the old version. The installer never reads model service API keys.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Built-in Agent Bundle")
            } footer: {
                Text("Installation happens inside the phone's iSH; downloads are verified and replaced atomically.")
            }
        }
        .listStyle(.insetGrouped)
        .environment(\.defaultMinListRowHeight, 44)
        .scrollContentBackground(.hidden)
        .background(HarnessTheme.pageBackground)
        .navigationTitle("Agent orchestration")
        .alert("Failed to set Bundle", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .task {
            await model.refreshProviderBundleInstallStatuses()
        }
    }

    @ViewBuilder
    private func installStatus(for bundle: AgentProviderBundle) -> some View {
        let status = model.providerBundleInstallStatus(bundle.id)
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if status.phase.isActive {
                ProgressView()
                    .controlSize(.small)
            } else {
                HarnessIconTile(
                    systemImage: status.phase == .installed ? "checkmark.seal.fill" : "shippingbox",
                    tint: status.phase == .installed ? .green : .secondary,
                    size: 28
                )
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(status.message)
                    .font(.caption)
                if let version = status.installedVersion {
                    Text("Verified version \(version)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func installActions(for bundle: AgentProviderBundle) -> some View {
        let status = model.providerBundleInstallStatus(bundle.id)
        HStack(spacing: 12) {
            if status.phase.isActive {
                Button("Cancel") {
                    model.cancelProviderBundleInstall(bundle.id)
                }
                .buttonStyle(.bordered)
            } else {
                Button(status.phase == .installed ? "Reinstall" : "Install on phone") {
                    model.startProviderBundleInstall(
                        bundle.id,
                        reinstall: status.phase == .installed
                    )
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private func binding(for bundle: AgentProviderBundle) -> Binding<Bool> {
        Binding(
            get: { model.providerBundle(bundle.id)?.enabled == true },
            set: { enabled in
                do {
                    try model.setProviderBundleEnabled(bundle.id, enabled: enabled)
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        )
    }
}
