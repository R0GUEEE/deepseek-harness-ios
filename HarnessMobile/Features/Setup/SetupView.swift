import SwiftUI

enum SetupMode: Equatable {
    case onboarding
    case editing
    case profile(String)
    case addingCatalog(ModelProviderID)
    case addingCustom
}

struct SetupView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    let mode: SetupMode

    @State private var draft = AgentConfiguration()
    @State private var profileID = ""
    @State private var displayName = ""
    @State private var isCustomProfile = false
    @State private var apiKey = ""
    @State private var oauthAccessToken = ""
    @State private var oauthRefreshToken = ""
    @State private var oauthExpiresAt = ""
    @State private var oauthTokenEndpoint = ""
    @State private var oauthClientID = ""
    @State private var catalog = SetupModelCatalog.builtIn(for: AgentConfiguration())
    @State private var isDiscoveringModels = false
    @State private var isSaving = false
    @State private var modelDiscoveryError: String?
    @State private var inlineError: String?
    @State private var didLoad = false
    @FocusState private var focusedField: Field?

    private enum Field {
        case profileID
        case displayName
        case baseURL
        case apiKey
        case model
    }

    private var provider: ModelProviderDescriptor {
        ModelProviderCatalog.descriptor(for: draft.providerID)
    }

    private var visibleCatalog: SetupModelCatalog {
        guard catalog.identity == ModelCatalogIdentity(configuration: draft) else {
            return .builtIn(for: draft)
        }
        return catalog
    }

    private var providerSelection: Binding<ModelProviderID> {
        Binding(
            get: { draft.providerID },
            set: { selectProvider($0) }
        )
    }

    private var existingProfile: ProviderProfile? {
        guard let existingProfileID else { return nil }
        return model.providerDirectory.profile(id: existingProfileID)
    }

    private var existingProfileID: String? {
        switch mode {
        case .onboarding:
            return model.providerDirectory.profile(id: profileID)?.id
        case .editing:
            return model.activeProviderProfile?.id
        case let .profile(id):
            return id
        case .addingCatalog, .addingCustom:
            return nil
        }
    }

    private var canChangeCatalogProvider: Bool {
        mode == .onboarding
    }

    private var isCreatingProfile: Bool {
        switch mode {
        case .addingCatalog, .addingCustom:
            true
        case .onboarding, .editing, .profile:
            false
        }
    }

    private var makeActiveAfterSave: Bool {
        switch mode {
        case .onboarding, .editing, .addingCatalog, .addingCustom:
            return true
        case let .profile(id):
            return model.providerDirectory.activeProfileID == id
        }
    }

    private var navigationTitle: String {
        switch mode {
        case .onboarding:
            "Set up Harness"
        case .editing, .profile:
            "Edit provider"
        case .addingCatalog:
            "Add provider"
        case .addingCustom:
            "Custom provider"
        }
    }

    private var keyPlaceholder: String {
        guard let existingProfile else { return "API Key" }
        return model.credentialStatus(for: existingProfile) == .configured
            ? "API key (leave blank to keep)"
            : "API Key"
    }

    private var canRefreshModels: Bool {
        provider.supportsRemoteModelDiscovery
            && !isDiscoveringModels
            && (try? draft.modelsURL()) != nil
    }

    private var selectedModelLabel: String {
        guard !draft.model.isEmpty else { return "None selected" }
        return visibleCatalog.models.first(where: { $0.id == draft.model })?.name
            ?? draft.model
    }

    private var compatibilityForegroundStyle: AnyShapeStyle {
        provider.supportsCurrentInferenceWire
            ? AnyShapeStyle(.secondary)
            : AnyShapeStyle(.orange)
    }

    private var effectiveRetryPolicy: ProviderRetryPolicyConfiguration {
        draft.retryPolicy ?? .upstreamDefault
    }

    private var retryModeBinding: Binding<ProviderRetryPolicyConfiguration.Mode> {
        Binding(
            get: { effectiveRetryPolicy.mode },
            set: { mode in
                var policy = effectiveRetryPolicy
                policy.mode = mode
                draft.retryPolicy = policy
            }
        )
    }

    private var retryCountBinding: Binding<Int> {
        Binding(
            get: { effectiveRetryPolicy.maxRetries ?? 5 },
            set: { value in
                var policy = effectiveRetryPolicy
                policy.maxRetries = value
                draft.retryPolicy = policy
            }
        )
    }

    private var wireProfileBinding: Binding<OpenAICompatibleWireProfile> {
        Binding(
            get: { draft.openAIWireProfile ?? OpenAICompatibleWireProfile.resolve(draft) },
            set: { draft.openAIWireProfile = $0 }
        )
    }

    private var effectiveOpenAICompatibility: OpenAICompletionsCompatibility {
        (draft.openAIWireProfile ?? OpenAICompatibleWireProfile.resolve(draft))
            .compatibilityBaseline
            .overlaying(draft.openAICompatibility)
    }

    private func compatibilityBoolBinding(
        _ keyPath: WritableKeyPath<OpenAICompletionsCompatibility, Bool?>
    ) -> Binding<Bool> {
        Binding(
            get: { effectiveOpenAICompatibility[keyPath: keyPath] ?? false },
            set: { value in
                var compatibility = draft.openAICompatibility ?? .init()
                compatibility[keyPath: keyPath] = value
                draft.openAICompatibility = compatibility
            }
        )
    }

    private var maxTokensFieldBinding: Binding<OpenAICompletionsCompatibility.MaxTokensField> {
        Binding(
            get: { effectiveOpenAICompatibility.maxTokensField ?? .maxTokens },
            set: { value in
                var compatibility = draft.openAICompatibility ?? .init()
                compatibility.maxTokensField = value
                draft.openAICompatibility = compatibility
            }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                identitySection
                connectionSection
                modelSection
                if mode != .onboarding {
                    inferenceSection
                }
                securitySection

                if let inlineError {
                    Section {
                        Text(inlineError)
                            .foregroundStyle(.red)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                saveActionBar
            }
            .toolbar {
                if mode != .onboarding {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }
            }
            .task {
                guard !didLoad else { return }
                loadDraft()
                didLoad = true

                if existingProfile != nil,
                   existingProfile.map(model.credentialStatus(for:)) == .configured,
                   provider.supportsRemoteModelDiscovery {
                    await discoverModels(forceRefresh: false)
                }
            }
        }
    }

    private var saveActionBar: some View {
        VStack(spacing: 0) {
            Divider()
            Button {
                save()
            } label: {
                Group {
                    if isSaving {
                        ProgressView()
                    } else {
                        Text(mode == .onboarding ? "Save and start" : "Save")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 24)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(
                isSaving
                    || isDiscoveringModels
                    || !provider.supportsCurrentInferenceWire
            )
            .accessibilityIdentifier("save-configuration")
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(.bar)
    }

    @ViewBuilder
    private var identitySection: some View {
        Section {
            if canChangeCatalogProvider {
                HStack {
                    Text("Provider")
                    Spacer()
                    Picker("Provider", selection: providerSelection) {
                        ForEach(ModelProviderCatalog.providers) { provider in
                            Text(provider.displayName).tag(provider.id)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .disabled(isDiscoveringModels)
                    .accessibilityIdentifier("provider-picker")
                }
            } else {
                LabeledContent("Provider ID", value: profileID.isEmpty ? "Not set" : profileID)
            }

            if mode == .addingCustom || (mode == .onboarding && isCustomProfile) {
                TextField("For example, acme-gateway", text: $profileID)
                    .accessibilityIdentifier("provider-id-field")
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .profileID)
            }

            if mode != .onboarding || isCustomProfile {
                TextField("Display name", text: $displayName)
                    .accessibilityIdentifier("provider-display-name-field")
                    .focused($focusedField, equals: .displayName)
            }

            if isCustomProfile {
                LabeledContent("API protocol", value: "OpenAI Chat Completions")
            } else {
                Text(provider.detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Provider")
        } footer: {
            if mode == .onboarding {
                Text("You can change the name, address, key and model later in settings.")
            } else {
                Text("The Provider ID is written into sessions and credential references and cannot be renamed after saving; the display name, URL, key and model catalog stay editable.")
            }
        }
    }

    private var connectionSection: some View {
        Section {
            TextField("API Base URL", text: $draft.baseURL)
                .accessibilityIdentifier("base-url-field")
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .baseURL)
                .disabled(isDiscoveringModels)

            SecureField(keyPlaceholder, text: $apiKey)
            .accessibilityIdentifier("api-key-field")
            .textContentType(.password)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .focused($focusedField, equals: .apiKey)
            .disabled(isDiscoveringModels)

            DisclosureGroup("OAuth grant (advanced)") {
                SecureField("Access token", text: $oauthAccessToken)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField("Refresh token (optional)", text: $oauthRefreshToken)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Token endpoint HTTPS URL (optional)", text: $oauthTokenEndpoint)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Client ID (optional)", text: $oauthClientID)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Expiration ISO 8601 (optional)", text: $oauthExpiresAt)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Text("Enter an access token and save it to use as this profile's credential; leave it blank to keep the existing grant.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .disabled(isDiscoveringModels)
        } header: {
            Text("Connection")
        } footer: {
            Text(
                mode == .onboarding
                    ? "The API key or OAuth grant is stored only in the on-device Keychain; model requests go to the selected provider, while the Agent loop and tools still run on this iPhone."
                    : "The API key or OAuth grant is written only to the on-device Keychain item for this Provider ID and is bound to the current HTTPS host and port. Model inference goes to the selected provider, while the Agent loop and tools still run on this iPhone."
            )
        }
    }

    private var modelSection: some View {
        Section {
            if visibleCatalog.models.isEmpty {
                Label("No built-in models in the current catalog", systemImage: "tray")
                    .foregroundStyle(.secondary)
            } else {
                NavigationLink {
                    ModelSelectionView(
                        models: visibleCatalog.models,
                        selection: $draft.model
                    )
                } label: {
                    LabeledContent("Catalog", value: selectedModelLabel)
                }
                .accessibilityIdentifier("model-catalog-link")
            }

            TextField("Manual model ID", text: $draft.model)
                .accessibilityIdentifier("model-field")
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .model)

            ModelCatalogStatusView(
                catalog: visibleCatalog,
                isLoading: isDiscoveringModels
            )

            Button("Refresh models", systemImage: "arrow.clockwise") {
                Task {
                    await discoverModels(forceRefresh: true)
                }
            }
            .disabled(!canRefreshModels)
            .accessibilityIdentifier("refresh-models")

            if let compatibilityNotice = provider.compatibilityNotice {
                Label(
                    compatibilityNotice,
                    systemImage: provider.supportsCurrentInferenceWire
                        ? "info.circle"
                        : "exclamationmark.triangle.fill"
                )
                .font(.footnote)
                .foregroundStyle(compatibilityForegroundStyle)
            }

            if let modelDiscoveryError {
                Text(modelDiscoveryError)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        } header: {
            Text("Model")
        } footer: {
            Text(
                mode == .onboarding
                    ? "Pick from the catalog or type a model ID; refreshing the catalog only uses the current key temporarily."
                    : "Models outside the catalog can be entered directly. When refreshing, the key you enter is used only for this same-origin /models request; the field is cleared once the request finishes, so re-enter it before saving."
            )
        }
    }

    private var inferenceSection: some View {
        Section {
            Picker("Thinking mode", selection: $draft.reasoningMode) {
                ForEach(draft.supportedReasoningModes
                    ?? ReasoningMode.supportedModes(for: draft.providerID)) { mode in
                    Text(mode.title).tag(mode)
                }
            }

            if provider.wireProtocol == .openAIChatCompletions {
                Picker("Compatible protocol", selection: wireProfileBinding) {
                    ForEach(OpenAICompatibleWireProfile.allCases) { profile in
                        Text(profile.title).tag(profile)
                    }
                }
                Text("Private gateways default to conservative mode; enable OpenAI or DeepSeek extension fields only when the gateway explicitly supports them.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                DisclosureGroup("Advanced gateway compatibility") {
                    Toggle(
                        "Send reasoning_effort",
                        isOn: compatibilityBoolBinding(\.supportsReasoningEffort)
                    )
                    Toggle(
                        "Return usage in the stream",
                        isOn: compatibilityBoolBinding(\.supportsUsageInStreaming)
                    )
                    Toggle(
                        "Use the developer role",
                        isOn: compatibilityBoolBinding(\.supportsDeveloperRole)
                    )
                    Picker("Output token field", selection: maxTokensFieldBinding) {
                        Text("max_tokens").tag(
                            OpenAICompletionsCompatibility.MaxTokensField.maxTokens
                        )
                        Text("max_completion_tokens").tag(
                            OpenAICompletionsCompatibility.MaxTokensField.maxCompletionTokens
                        )
                    }
                    Toggle(
                        "Attach name to tool results",
                        isOn: compatibilityBoolBinding(\.requiresToolResultName)
                    )
                    Toggle(
                        "Add assistant after tool results",
                        isOn: compatibilityBoolBinding(\.requiresAssistantAfterToolResult)
                    )
                    Toggle(
                        "Turn thinking into text tags",
                        isOn: compatibilityBoolBinding(\.requiresThinkingAsText)
                    )
                    Toggle(
                        "Replay reasoning_content",
                        isOn: compatibilityBoolBinding(
                            \.requiresReasoningContentOnAssistantMessages
                        )
                    )
                    Button("Restore preset compatibility") {
                        draft.openAICompatibility = nil
                    }
                }
            }

            Picker("Retry on failure", selection: retryModeBinding) {
                ForEach(ProviderRetryPolicyConfiguration.Mode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            if effectiveRetryPolicy.mode == .normal {
                TextField("Max retries", value: retryCountBinding, format: .number)
                    .keyboardType(.numberPad)
            } else {
                Text("Continuous retry backs off in a bounded way after each failure until it succeeds, is stopped manually, or the app terminates; every retry is still written to the trajectory.")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }

            LabeledContent("Agent loop", value: "No app-wide step limit")
            Text("A single model response should call at most 8 tools; the phone runs up to 2 concurrency-safe tools at once and queues the rest. Anthropic extended thinking needs signature blocks stored, so only provider default and off are available for now.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } header: {
            Label("Reasoning", systemImage: "cpu")
        }
    }

    private var securitySection: some View {
        Section {
            Label(
                "API keys and OAuth grants are kept only in the on-device Keychain and never enter sessions, logs or the tool environment.",
                systemImage: "lock.shield"
            )
            Label(
                "BYOK on mobile cannot hide the key as completely as your own backend; use a separate, rate-limited, revocable key.",
                systemImage: "exclamationmark.shield"
            )
        } header: {
            Text("Security boundary")
        }
    }

    private func selectProvider(_ providerID: ModelProviderID) {
        guard providerID != draft.providerID else { return }
        let profile: ProviderProfile
        if providerID != .customOpenAICompatible,
           let stored = model.providerDirectory.profile(id: providerID.rawValue) {
            profile = stored
        } else if providerID == .customOpenAICompatible {
            profile = ProviderProfile.customDraft(
                maxSteps: draft.maxSteps,
                maxOutputTokens: draft.maxOutputTokens
            )
        } else {
            profile = ProviderProfile.catalogDefault(
                for: providerID,
                maxSteps: draft.maxSteps,
                maxOutputTokens: draft.maxOutputTokens
            )
        }
        profileID = profile.id
        displayName = profile.displayName
        isCustomProfile = providerID == .customOpenAICompatible
        draft = profile.configuration()
        draft.profileID = nil
        draft.credentialReference = nil
        apiKey = ""
        oauthAccessToken = ""
        oauthRefreshToken = ""
        oauthExpiresAt = ""
        oauthTokenEndpoint = ""
        oauthClientID = ""
        catalog = .stored(for: profile)
        modelDiscoveryError = nil
        inlineError = nil
    }

    private func discoverModels(forceRefresh: Bool) async {
        guard canRefreshModels else { return }
        let requestConfiguration = draft
        let requestIdentity = ModelCatalogIdentity(configuration: requestConfiguration)
        let temporaryKey = normalizedAPIKey(apiKey)

        isDiscoveringModels = true
        modelDiscoveryError = nil
        defer {
            if let temporaryKey, normalizedAPIKey(apiKey) == temporaryKey {
                apiKey = ""
            }
            isDiscoveringModels = false
        }

        do {
            let snapshot = try await model.discoverModels(
                for: requestConfiguration,
                temporaryAPIKey: temporaryKey,
                forceRefresh: forceRefresh
            )
            guard requestIdentity == ModelCatalogIdentity(configuration: draft) else { return }
            let refreshedCatalog = SetupModelCatalog.merging(
                snapshot,
                existing: visibleCatalog.models,
                for: requestConfiguration
            )
            catalog = refreshedCatalog
            if draft.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               let firstModel = refreshedCatalog.models.first {
                draft.model = firstModel.id
            }
            draft.inputModalities = refreshedCatalog.models.first(
                where: { $0.id == draft.model }
            )?.inputModalities
        } catch is CancellationError {
            return
        } catch {
            guard requestIdentity == ModelCatalogIdentity(configuration: draft) else { return }
            modelDiscoveryError = error.localizedDescription
        }
    }

    private func normalizedAPIKey(_ value: String) -> String? {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    private func makeOAuthCredential() throws -> ProviderOAuthCredential? {
        let access = oauthAccessToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let refresh = oauthRefreshToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let expiry = oauthExpiresAt.trimmingCharacters(in: .whitespacesAndNewlines)
        let endpointText = oauthTokenEndpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        let clientID = oauthClientID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !access.isEmpty else {
            guard refresh.isEmpty, expiry.isEmpty, endpointText.isEmpty, clientID.isEmpty else {
                throw SetupOAuthError.accessTokenRequired
            }
            return nil
        }
        let tokenEndpoint: URL?
        if endpointText.isEmpty {
            tokenEndpoint = nil
        } else {
            guard let url = URL(string: endpointText) else {
                throw SetupOAuthError.invalidEndpoint
            }
            tokenEndpoint = url
        }
        if (tokenEndpoint == nil) != clientID.isEmpty {
            throw SetupOAuthError.endpointAndClientIDRequired
        }
        let expiresAt: Date?
        if expiry.isEmpty {
            expiresAt = nil
        } else {
            let formatter = ISO8601DateFormatter()
            guard let parsed = formatter.date(from: expiry) else {
                throw SetupOAuthError.invalidExpiry
            }
            expiresAt = parsed
        }
        return ProviderOAuthCredential(
            accessToken: access,
            refreshToken: refresh.isEmpty ? nil : refresh,
            expiresAt: expiresAt,
            tokenEndpoint: tokenEndpoint,
            clientID: clientID.isEmpty ? nil : clientID
        )
    }

    private func save() {
        guard !isSaving else { return }
        isSaving = true
        inlineError = nil
        Task {
            do {
                let routeID = profileID.trimmingCharacters(in: .whitespacesAndNewlines)
                let credentialReference = existingProfile?.id == routeID
                    ? existingProfile?.credentialReference
                    : .providerAPIKey(profileID: routeID)
                let profile = ProviderProfile(
                    id: routeID,
                    displayName: displayName,
                    providerID: draft.providerID,
                    wireProtocol: isCustomProfile
                        ? .openAIChatCompletions
                        : provider.wireProtocol,
                    baseURL: draft.baseURL,
                    credentialReference: credentialReference,
                    models: modelsEnsuringSelection(visibleCatalog.models),
                    defaultModel: draft.model,
                    reasoningMode: draft.reasoningMode,
                    openAIWireProfile: draft.openAIWireProfile,
                    openAICompatibility: draft.openAICompatibility,
                    retryPolicy: draft.retryPolicy ?? .upstreamDefault,
                    maxSteps: draft.maxSteps,
                    maxOutputTokens: draft.maxOutputTokens,
                    isCustom: isCustomProfile
                )
                let oauthCredential = try makeOAuthCredential()
                try await model.saveProviderProfile(
                    profile,
                    apiKey: apiKey,
                    makeActive: makeActiveAfterSave,
                    existingProfileID: existingProfile?.id == routeID
                        ? existingProfile?.id
                        : nil,
                    oauthCredential: oauthCredential
                )
                apiKey = ""
                oauthAccessToken = ""
                oauthRefreshToken = ""
                oauthExpiresAt = ""
                oauthTokenEndpoint = ""
                oauthClientID = ""
                if mode != .onboarding {
                    dismiss()
                }
            } catch {
                inlineError = error.localizedDescription
            }
            isSaving = false
        }
    }

    private func loadDraft() {
        let profile: ProviderProfile
        switch mode {
        case .onboarding, .editing:
            profile = model.activeProviderProfile ?? .catalogDefault(for: .deepSeekOfficial)
        case let .profile(id):
            profile = model.providerDirectory.profile(id: id)
                ?? .catalogDefault(for: .deepSeekOfficial)
        case let .addingCatalog(providerID):
            profile = .catalogDefault(
                for: providerID,
                maxSteps: model.configuration.maxSteps,
                maxOutputTokens: model.configuration.maxOutputTokens
            )
        case .addingCustom:
            profile = .customDraft(
                maxSteps: model.configuration.maxSteps,
                maxOutputTokens: model.configuration.maxOutputTokens
            )
        }

        profileID = profile.id
        displayName = profile.displayName
        isCustomProfile = profile.isCustom
        draft = profile.configuration()
        apiKey = ""
        oauthAccessToken = ""
        oauthRefreshToken = ""
        oauthExpiresAt = ""
        oauthTokenEndpoint = ""
        oauthClientID = ""
        if isCreatingProfile {
            draft.profileID = nil
            draft.credentialReference = nil
        }
        catalog = .stored(for: profile)
    }

    private func modelsEnsuringSelection(_ models: [ProviderModel]) -> [ProviderModel] {
        let selected = draft.model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !selected.isEmpty, !models.contains(where: { $0.id == selected }) else {
            return models
        }
        return models + [ProviderModel(id: selected)]
    }
}

private struct ModelCatalogIdentity: Equatable {
    let providerID: ModelProviderID
    let baseURL: String

    init(configuration: AgentConfiguration) {
        providerID = configuration.providerID
        baseURL = configuration.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct SetupModelCatalog {
    let identity: ModelCatalogIdentity
    let source: ModelCatalogSource
    let fetchedAt: Date?
    let models: [ProviderModel]

    static func builtIn(for configuration: AgentConfiguration) -> SetupModelCatalog {
        let snapshot = ModelProviderCatalog.builtInSnapshot(for: configuration.providerID)
        return SetupModelCatalog(
            identity: ModelCatalogIdentity(configuration: configuration),
            source: snapshot.source,
            fetchedAt: snapshot.fetchedAt,
            models: snapshot.models
        )
    }

    static func stored(for profile: ProviderProfile) -> SetupModelCatalog {
        SetupModelCatalog(
            identity: ModelCatalogIdentity(configuration: profile.configuration()),
            source: .builtIn,
            fetchedAt: nil,
            models: profile.models
        )
    }

    static func merging(
        _ snapshot: ModelCatalogSnapshot,
        existing: [ProviderModel],
        for configuration: AgentConfiguration
    ) -> SetupModelCatalog {
        guard snapshot.providerID == configuration.providerID else {
            return .builtIn(for: configuration)
        }

        let builtIn = ModelProviderCatalog.builtInSnapshot(for: configuration.providerID).models
        var models = existing.isEmpty ? builtIn : existing
        var positions = Dictionary(
            uniqueKeysWithValues: models.enumerated().map { ($0.element.id, $0.offset) }
        )
        for discoveredModel in snapshot.models {
            if let position = positions[discoveredModel.id] {
                let existing = models[position]
                let builtIn = ModelProviderCatalog.descriptor(for: configuration.providerID)
                    .builtInModels
                    .first(where: { $0.id == discoveredModel.id })
                let refreshedModalities = discoveredModel.inputModalities == [.text]
                    && builtIn?.inputModalities.contains(.image) == true
                    ? builtIn?.inputModalities ?? discoveredModel.inputModalities
                    : discoveredModel.inputModalities
                let resolvedName = discoveredModel.name ?? existing.name
                let resolvedDescription = discoveredModel.description ?? existing.description
                let resolvedContextWindow = discoveredModel.contextWindow ?? existing.contextWindow
                let resolvedMaxOutputTokens = discoveredModel.maxOutputTokens ?? existing.maxOutputTokens
                let resolvedReasoningModes = discoveredModel.reasoningModes ?? existing.reasoningModes
                let resolvedDefaultReasoningMode = discoveredModel.defaultReasoningMode
                    ?? existing.defaultReasoningMode
                let resolvedReasoningWireStyle = discoveredModel.reasoningWireStyle
                    ?? existing.reasoningWireStyle
                models[position] = ProviderModel(
                    id: discoveredModel.id,
                    name: resolvedName,
                    description: resolvedDescription,
                    contextWindow: resolvedContextWindow,
                    maxOutputTokens: resolvedMaxOutputTokens,
                    inputModalities: refreshedModalities,
                    reasoningModes: resolvedReasoningModes,
                    defaultReasoningMode: resolvedDefaultReasoningMode,
                    reasoningWireStyle: resolvedReasoningWireStyle,
                    // A refreshed provider catalog is authoritative for model
                    // capabilities. Keeping the cached value can leave a
                    // vision model marked as text-only after discovery.
                    openAICompatibility: existing.openAICompatibility
                )
            } else {
                positions[discoveredModel.id] = models.count
                models.append(discoveredModel)
            }
        }

        return SetupModelCatalog(
            identity: ModelCatalogIdentity(configuration: configuration),
            source: snapshot.source,
            fetchedAt: snapshot.fetchedAt,
            models: models
        )
    }
}

private struct ModelCatalogStatusView: View {
    let catalog: SetupModelCatalog
    let isLoading: Bool

    var body: some View {
        HStack(spacing: 8) {
            if isLoading {
                ProgressView()
                    .controlSize(.small)
                Text("Fetching models…")
            } else {
                Label("\(sourceTitle) · \(catalog.models.count) items", systemImage: sourceIcon)
            }
            Spacer()
            if let fetchedAt = catalog.fetchedAt, !isLoading {
                Text(fetchedAt, format: .dateTime.month().day().hour().minute())
                    .foregroundStyle(.tertiary)
            }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .combine)
    }

    private var sourceTitle: String {
        switch catalog.source {
        case .builtIn:
            return "Built-in catalog"
        case .remote:
            return "From provider"
        case .cache:
            return "On-device cache"
        }
    }

    private var sourceIcon: String {
        switch catalog.source {
        case .builtIn:
            return "shippingbox"
        case .remote:
            return "network"
        case .cache:
            return "internaldrive"
        }
    }
}

private struct ModelSelectionView: View {
    @Environment(\.dismiss) private var dismiss

    let models: [ProviderModel]
    @Binding var selection: String

    @State private var searchText = ""

    private var filteredModels: [ProviderModel] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return models }
        return models.filter { model in
            model.id.localizedCaseInsensitiveContains(query)
                || model.name?.localizedCaseInsensitiveContains(query) == true
        }
    }

    var body: some View {
        List(filteredModels) { model in
            Button {
                selection = model.id
                dismiss()
            } label: {
                ModelSelectionRow(model: model, isSelected: model.id == selection)
            }
            .buttonStyle(.plain)
        }
        .harnessCompactListChrome()
        .overlay {
            if filteredModels.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
        .navigationTitle("Select model")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search model ID or name")
    }
}

private struct ModelSelectionRow: View {
    let model: ProviderModel
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(model.name ?? model.id)
                    .foregroundStyle(.primary)
                if model.name != nil {
                    Text(model.id)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let capacity = capacityDescription {
                    Text(capacity)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer(minLength: 8)
            Image(systemName: "checkmark")
                .fontWeight(.semibold)
                .foregroundStyle(.tint)
                .opacity(isSelected ? 1 : 0)
                .accessibilityHidden(true)
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var capacityDescription: String? {
        var parts: [String] = []
        if let contextWindow = model.contextWindow {
            parts.append("Context \(contextWindow.formatted())")
        }
        if let maxOutputTokens = model.maxOutputTokens {
            parts.append("Max output \(maxOutputTokens.formatted())")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

private enum SetupOAuthError: LocalizedError {
    case accessTokenRequired
    case invalidExpiry
    case invalidEndpoint
    case endpointAndClientIDRequired

    var errorDescription: String? {
        switch self {
        case .accessTokenRequired:
            "Enter the access token before the refresh token or expiry."
        case .invalidExpiry:
            "The OAuth expiration must be in ISO 8601 format."
        case .invalidEndpoint:
            "Invalid OAuth token endpoint URL."
        case .endpointAndClientIDRequired:
            "If you enter a token endpoint you must also enter a client ID, and vice versa."
        }
    }
}
