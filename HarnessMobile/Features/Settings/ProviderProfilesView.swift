import SwiftUI

struct ProviderProfilesView: View {
    @Environment(AppModel.self) private var model

    @State private var presentedEditor: ProviderEditorRoute?
    @State private var pendingDeletion: ProviderProfile?
    @State private var workingProfileID: String?
    @State private var operationError: String?

    var body: some View {
        List {
            Section {
                if model.providerProfiles.isEmpty {
                    ContentUnavailableView(
                        "No provider",
                        systemImage: "server.rack",
                        description: Text("Add a catalog provider or a custom OpenAI-compatible provider.")
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(model.providerProfiles) { profile in
                        ProviderProfileListRow(
                            profile: profile,
                            credentialStatus: model.credentialStatus(for: profile),
                            isActive: model.providerDirectory.activeProfileID == profile.id,
                            isWorking: workingProfileID == profile.id,
                            onEdit: { presentedEditor = .edit(profile.id) },
                            onActivate: { activate(profile) }
                        )
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            if model.providerDirectory.activeProfileID != profile.id {
                                Button {
                                    activate(profile)
                                } label: {
                                    Label("Set as default", systemImage: "checkmark.circle")
                                }
                                .tint(.green)
                                .disabled(!canActivate(profile))
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                pendingDeletion = profile
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }

                            Button {
                                presentedEditor = .edit(profile.id)
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                        .contextMenu {
                            if model.providerDirectory.activeProfileID != profile.id {
                                Button("Set as default", systemImage: "checkmark.circle") {
                                    activate(profile)
                                }
                                .disabled(!canActivate(profile))
                            }
                            Button("Edit", systemImage: "pencil") {
                                presentedEditor = .edit(profile.id)
                            }
                            Button("Quick test", systemImage: "bolt.horizontal.circle") {
                                quickTest(profile)
                            }
                            .disabled(!canActivate(profile))
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                pendingDeletion = profile
                            }
                        }
                    }
                }
            } header: {
                Label("Provider profiles", systemImage: "server.rack")
            } footer: {
                Text("The default profile is used for new requests; a request that is already running does not switch mid-flight. API keys are stored only in their own on-device Keychain items.")
            }

            Section {
                NavigationLink {
                    List {
                        providerBehaviorSections
                    }
                    .navigationTitle("Model behavior")
                    .navigationBarTitleDisplayMode(.inline)
                } label: {
                    LabeledContent {
                        Text("Compaction, time, title")
                            .foregroundStyle(.secondary)
                    } label: {
                        Label("Model behavior", systemImage: "slider.horizontal.3")
                    }
                }
                .accessibilityIdentifier("provider-behavior-settings")
            } header: { Label("Request behavior", systemImage: "slider.horizontal.3") }

            Section {
                ForEach(catalogProviders) { descriptor in
                    Button {
                        presentedEditor = .addCatalog(descriptor.id)
                    } label: {
                        LabeledContent {
                            if hasCatalogProfile(descriptor.id) {
                                Text("Added")
                                    .foregroundStyle(.secondary)
                            } else if !descriptor.supportsCurrentInferenceWire {
                                Text("Protocol not wired up yet")
                                    .foregroundStyle(.orange)
                            }
                        } label: {
                            Label(descriptor.displayName, systemImage: descriptor.systemImage)
                        }
                    }
                    .disabled(
                        hasCatalogProfile(descriptor.id)
                            || !descriptor.supportsCurrentInferenceWire
                    )
                }

                Button {
                    presentedEditor = .addCustom
                } label: {
                    Label("Custom OpenAI-compatible", systemImage: "plus.rectangle.on.rectangle")
                }
            } header: { Label("Add", systemImage: "plus.circle") }
        }
        .listStyle(.insetGrouped)
        .environment(\.defaultMinListRowHeight, 44)
        .scrollContentBackground(.hidden)
        .background(HarnessTheme.pageBackground)
        .navigationTitle("Models and providers")
        .task {
            await model.refreshProviderCredentialStatuses()
        }
        .sheet(item: $presentedEditor) { route in
            SetupView(mode: route.setupMode)
        }
        .confirmationDialog(
            deletionTitle,
            isPresented: deletionPresented,
            titleVisibility: .visible
        ) {
            Button("Delete profile and API key", role: .destructive) {
                deletePendingProfile()
            }
            Button("Cancel", role: .cancel) {
                pendingDeletion = nil
            }
        } message: {
            Text("Local sessions and workspace files are kept. Existing sessions that reference this profile need a new model selection before they can send requests again.")
        }
        .alert("Provider action failed", isPresented: operationErrorPresented) {
            Button("OK") {
                operationError = nil
            }
        } message: {
            Text(operationError ?? "")
        }
    }

    @ViewBuilder
    private var providerBehaviorSections: some View {
        Section {
            Picker("Summary model", selection: compactionSummaryRouteBinding) {
                Text("Follow current session")
                    .tag(nil as CompactionSummaryRoute?)
                ForEach(compactionSummaryRouteOptions) { option in
                    Text("\(option.profileName) / \(option.route.model)")
                        .tag(Optional(option.route))
                }
            }
            .disabled(model.isRunning)
        } header: {
            Text("Context compaction")
        } footer: {
            Text("The separate summary route falls back only when nothing has been output yet; partial output, cancellation, truncation or a tool call are never retried silently.")
        }

        Section {
            Toggle("Give the Agent the current time", isOn: timeContextEnabledBinding)
                .disabled(model.isRunning)
            if model.timeContextSettings.isEnabled {
                Picker("Show time zone", selection: timeContextTimeZoneBinding) {
                    Text("Follow iPhone (\(TimeZone.current.identifier))")
                        .tag(nil as String?)
                    Text("UTC")
                        .tag(Optional("UTC"))
                }
                Picker("Refresh interval", selection: timeContextRefreshBinding) {
                    Text("Per model step").tag(0)
                    Text("1 minute").tag(60_000)
                    Text("5 minutes").tag(300_000)
                    Text("15 minutes").tag(900_000)
                }
            }
        } header: {
            Text("Time context")
        } footer: {
            Text("Time is appended to the end of messages as a persistent snapshot; it is not injected again within the refresh interval.")
        }

        Section {
            Picker("Automatic titles", selection: sessionTitleModeBinding) {
                ForEach(SessionTitleAutomaticMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .disabled(model.isRunning)
            if model.sessionTitleSettings.automaticMode != .disabled {
                Picker("Title model", selection: sessionTitleRouteBinding) {
                    Text("Follow session model")
                        .tag(nil as CompactionSummaryRoute?)
                    ForEach(compactionSummaryRouteOptions) { option in
                        Text("\(option.profileName) / \(option.route.model)")
                            .tag(Optional(option.route))
                    }
                }
                .disabled(model.isRunning)
            }
        } header: {
            Text("Session title")
        } footer: {
            Text("Title requests carry no tools; on failure the on-device title generated from the first prompt is kept.")
        }
    }

    private var catalogProviders: [ModelProviderDescriptor] {
        ModelProviderCatalog.providers.filter { $0.id != .customOpenAICompatible }
    }

    private var deletionTitle: String {
        guard let pendingDeletion else { return "Delete provider profile?" }
        return "Delete \"\(pendingDeletion.displayName)\"?"
    }

    private var deletionPresented: Binding<Bool> {
        Binding(
            get: { pendingDeletion != nil },
            set: { presented in
                if !presented {
                    pendingDeletion = nil
                }
            }
        )
    }

    private var operationErrorPresented: Binding<Bool> {
        Binding(
            get: { operationError != nil },
            set: { presented in
                if !presented {
                    operationError = nil
                }
            }
        )
    }

    private var compactionSummaryRouteOptions: [CompactionSummaryRouteOption] {
        model.providerProfiles.flatMap { profile in
            profile.models.map { providerModel in
                CompactionSummaryRouteOption(
                    profileName: profile.displayName,
                    route: CompactionSummaryRoute(
                        profileID: profile.id,
                        model: providerModel.id
                    )
                )
            }
        }
    }

    private var compactionSummaryRouteBinding: Binding<CompactionSummaryRoute?> {
        Binding(
            get: { model.compactionSummaryRoute },
            set: { route in
                do {
                    try model.setCompactionSummaryRoute(route)
                    operationError = nil
                } catch {
                    operationError = error.localizedDescription
                }
            }
        )
    }

    private var timeContextEnabledBinding: Binding<Bool> {
        Binding(
            get: { model.timeContextSettings.isEnabled },
            set: { enabled in
                updateTimeContextSettings { $0.isEnabled = enabled }
            }
        )
    }

    private var timeContextTimeZoneBinding: Binding<String?> {
        Binding(
            get: { model.timeContextSettings.timeZoneIdentifier },
            set: { identifier in
                updateTimeContextSettings { $0.timeZoneIdentifier = identifier }
            }
        )
    }

    private var timeContextRefreshBinding: Binding<Int> {
        Binding(
            get: { model.timeContextSettings.refreshIntervalMilliseconds },
            set: { interval in
                updateTimeContextSettings { $0.refreshIntervalMilliseconds = interval }
            }
        )
    }

    private func updateTimeContextSettings(
        _ update: (inout TimeContextSettings) -> Void
    ) {
        var settings = model.timeContextSettings
        update(&settings)
        do {
            try model.setTimeContextSettings(settings)
            operationError = nil
        } catch {
            operationError = error.localizedDescription
        }
    }

    private var sessionTitleModeBinding: Binding<SessionTitleAutomaticMode> {
        Binding(
            get: { model.sessionTitleSettings.automaticMode },
            set: { mode in
                updateSessionTitleSettings { $0.automaticMode = mode }
            }
        )
    }

    private var sessionTitleRouteBinding: Binding<CompactionSummaryRoute?> {
        Binding(
            get: { model.sessionTitleSettings.route },
            set: { route in
                updateSessionTitleSettings { $0.route = route }
            }
        )
    }

    private func updateSessionTitleSettings(
        _ update: (inout SessionTitleSettings) -> Void
    ) {
        var settings = model.sessionTitleSettings
        update(&settings)
        do {
            try model.setSessionTitleSettings(settings)
            operationError = nil
        } catch {
            operationError = error.localizedDescription
        }
    }

    private func hasCatalogProfile(_ providerID: ModelProviderID) -> Bool {
        model.providerProfiles.contains { profile in
            !profile.isCustom && profile.providerID == providerID
        }
    }

    private func canActivate(_ profile: ProviderProfile) -> Bool {
        profile.descriptor.supportsCurrentInferenceWire
            && model.credentialStatus(for: profile) == .configured
            && workingProfileID == nil
            && !model.isRunning
    }

    private func activate(_ profile: ProviderProfile) {
        guard canActivate(profile) else { return }
        workingProfileID = profile.id
        operationError = nil
        Task {
            do {
                try await model.activateProviderProfile(id: profile.id)
            } catch {
                operationError = error.localizedDescription
            }
            workingProfileID = nil
        }
    }

    private func deletePendingProfile() {
        guard let profile = pendingDeletion else { return }
        pendingDeletion = nil
        workingProfileID = profile.id
        operationError = nil
        Task {
            do {
                try await model.removeProviderProfile(id: profile.id)
            } catch {
                operationError = error.localizedDescription
            }
            workingProfileID = nil
        }
    }

    private func quickTest(_ profile: ProviderProfile) {
        guard canActivate(profile) else { return }
        workingProfileID = profile.id
        operationError = nil
        Task {
            do {
                _ = try await model.quickTestProviderProfile(id: profile.id)
            } catch {
                operationError = error.localizedDescription
            }
            workingProfileID = nil
        }
    }
}

private struct CompactionSummaryRouteOption: Identifiable {
    let profileName: String
    let route: CompactionSummaryRoute

    var id: String { route.profileID + "\u{0}" + route.model }
}

private enum ProviderEditorRoute: Identifiable {
    case edit(String)
    case addCatalog(ModelProviderID)
    case addCustom

    var id: String {
        switch self {
        case let .edit(profileID):
            return "edit-\(profileID)"
        case let .addCatalog(providerID):
            return "add-\(providerID.rawValue)"
        case .addCustom:
            return "add-custom"
        }
    }

    var setupMode: SetupMode {
        switch self {
        case let .edit(profileID):
            return .profile(profileID)
        case let .addCatalog(providerID):
            return .addingCatalog(providerID)
        case .addCustom:
            return .addingCustom
        }
    }
}

private struct ProviderProfileListRow: View {
    let profile: ProviderProfile
    let credentialStatus: ProviderCredentialStatus
    let isActive: Bool
    let isWorking: Bool
    let onEdit: () -> Void
    let onActivate: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onEdit) {
                HStack(spacing: 12) {
                    HarnessIconTile(
                        systemImage: profile.descriptor.systemImage,
                        tint: .accentColor
                    )

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(profile.displayName)
                                .font(.body.weight(.medium))
                            if profile.isCustom {
                                Text("Custom")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        if profile.isCustom {
                            Text(profile.id)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Text(profile.defaultModel)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)

            VStack(alignment: .trailing, spacing: 5) {
                ProviderCredentialStatusLabel(
                    status: credentialStatus,
                    supportsInference: profile.descriptor.supportsCurrentInferenceWire
                )

                if isWorking {
                    ProgressView()
                        .controlSize(.small)
                } else if isActive {
                    HarnessStatusPill(
                        title: "Default",
                        systemImage: "checkmark.circle.fill",
                        tint: .green
                    )
                    .accessibilityLabel("Default provider")
                } else {
                    Button(action: onActivate) {
                        Image(systemName: "circle")
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .disabled(
                        credentialStatus != .configured
                            || !profile.descriptor.supportsCurrentInferenceWire
                    )
                    .accessibilityLabel("Set as default provider")
                    .help("Set as default provider")
                }
            }
        }
        .accessibilityElement(children: .contain)
    }
}

private struct ProviderCredentialStatusLabel: View {
    let status: ProviderCredentialStatus
    let supportsInference: Bool

    var body: some View {
        HarnessStatusPill(
            title: title,
            systemImage: systemImage,
            tint: foregroundColor
        )
    }

    private var title: String {
        guard supportsInference else { return "Protocol not wired up yet" }
        switch status {
        case .unknown:
            return "Checking"
        case .configured:
            return "Configured"
        case .missing:
            return "Missing key"
        case .originMismatch:
            return "Key needs update"
        }
    }

    private var systemImage: String {
        guard supportsInference else { return "exclamationmark.triangle.fill" }
        switch status {
        case .unknown:
            return "ellipsis.circle"
        case .configured:
            return "checkmark.circle.fill"
        case .missing:
            return "key.slash"
        case .originMismatch:
            return "arrow.trianglehead.2.clockwise.rotate.90.circle"
        }
    }

    private var foregroundColor: Color {
        guard supportsInference else { return .orange }
        switch status {
        case .unknown: return .secondary
        case .configured: return .green
        case .missing: return .red
        case .originMismatch: return .orange
        }
    }
}

private extension ModelProviderDescriptor {
    var systemImage: String {
        switch id {
        case .deepSeekOfficial:
            return "brain.head.profile"
        case .openAI:
            return "sparkles"
        case .anthropic:
            return "text.bubble"
        case .openRouter:
            return "arrow.triangle.branch"
        case .customOpenAICompatible:
            return "server.rack"
        }
    }
}
