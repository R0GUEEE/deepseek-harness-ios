import SwiftUI

struct BackgroundSettingsView: View {
    @Environment(BackgroundPreferencesModel.self) private var preferences
    @State private var notificationAuthorization: BackgroundNotificationAuthorization = .notDetermined
    @State private var notificationErrorDescription: String?

    let runtimeStatus: BackgroundRuntimeStatus
    let locationSnapshot: BackgroundLocationKeepAliveSnapshot
    let systemProjection: BackgroundSystemProjection
    let requestLocationAuthorization: () -> Void

    private let notifier = BackgroundCompletionNotifier()

    var body: some View {
        @Bindable var preferences = preferences

        Form {
            BackgroundExecutionSettingsSection(
                isEnabled: $preferences.isEnhancedBackgroundEnabled,
                isSystemSupported: isContinuedProcessingSupported
            )
            BackgroundLocationKeepAliveSettingsSection(
                isEnabled: $preferences.isBackgroundLocationKeepAliveEnabled,
                snapshot: locationSnapshot,
                requestAuthorization: requestLocationAuthorization
            )
            BackgroundLiveActivitySettingsSection(
                isEnabled: $preferences.isLiveActivityEnabled,
                isSystemSupported: isLiveActivitySupported,
                areActivitiesEnabled: areLiveActivitiesEnabled
            )
            BackgroundNotificationSettingsSection(
                isEnabled: $preferences.areTaskNotificationsEnabled,
                authorization: notificationAuthorization,
                errorDescription: notificationErrorDescription
            )
            BackgroundPrivacySettingsSection(
                isEnabled: $preferences.isPrivacyModeEnabled
            )
            BackgroundRuntimeStatusSection(
                status: runtimeStatus,
                privacyModeEnabled: preferences.isPrivacyModeEnabled,
                isContinuedProcessingSupported: isContinuedProcessingSupported,
                isLiveActivitySupported: isLiveActivitySupported,
                isLiveActivityEnabled: preferences.isLiveActivityEnabled
            )
            BackgroundSystemProjectionSection(projection: systemProjection)
            BackgroundSafetyBoundarySection()

            if let persistenceErrorDescription = preferences.persistenceErrorDescription {
                Section {
                    Text(persistenceErrorDescription)
                        .foregroundStyle(.red)
                } header: {
                    Text("Preferred storage")
                } footer: {
                    Text("This setting was not saved on the device.")
                }
            }
        }
        .listStyle(.insetGrouped)
        .environment(\.defaultMinListRowHeight, 44)
        .scrollContentBackground(.hidden)
        .background(HarnessTheme.pageBackground)
        .navigationTitle("Background jobs")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            notificationAuthorization = await notifier.authorizationStatus()
        }
        .onChange(of: preferences.areTaskNotificationsEnabled) { _, isEnabled in
            guard isEnabled else { return }
            Task {
                await requestNotificationAuthorization()
            }
        }
        .onChange(of: preferences.isLiveActivityEnabled) { _, isEnabled in
            guard !isEnabled else { return }
            Task {
                await HarnessLiveActivityManager.shared.endAll()
            }
        }
        .onChange(of: preferences.isPrivacyModeEnabled) { _, isEnabled in
            Task {
                await HarnessLiveActivityManager.shared.applyPrivacyMode(isEnabled)
            }
        }
    }

    private var isContinuedProcessingSupported: Bool {
        if #available(iOS 26.0, *) {
            true
        } else {
            false
        }
    }

    private var isLiveActivitySupported: Bool {
        HarnessLiveActivityManager.isSystemSupported
    }

    private var areLiveActivitiesEnabled: Bool {
        HarnessLiveActivityManager.shared.areActivitiesEnabled
    }

    private func requestNotificationAuthorization() async {
        do {
            notificationAuthorization = try await notifier.requestAuthorization()
            notificationErrorDescription = nil
        } catch {
            notificationAuthorization = await notifier.authorizationStatus()
            notificationErrorDescription = error.localizedDescription
        }
    }
}

private struct BackgroundSystemProjectionSection: View {
    let projection: BackgroundSystemProjection

    var body: some View {
        Section {
            HStack(spacing: HarnessTheme.Spacing.medium) {
                HarnessIconTile(systemImage: "bolt.horizontal.circle", tint: .accentColor)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Active tasks")
                    Text("\(projection.activeRunCount)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                HarnessStatusPill(title: tierLabel, systemImage: tierIcon, tint: tierTint)
            }
            statusRow("Notification permission", value: projection.notificationAuthorization, icon: "bell.badge")
            statusRow("Location permission", value: projection.locationAuthorization, icon: "location.fill")
            statusRow(
                "Live Activity permission",
                value: projection.liveActivitySupported
                    ? (projection.liveActivityEnabled ? "Enabled" : "Off")
                    : "Unavailable",
                icon: "rectangle.topthird.inset.filled"
            )
            if !projection.degradedReasons.isEmpty {
                statusRow("Current degradation", value: degradedLabel, icon: "exclamationmark.triangle", tint: .orange)
            }
            if !projection.degradedDetails.isEmpty {
                LabeledContent("Failure evidence", value: projection.degradedDetails.joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            BackgroundDetailsRow(
                title: "Projection scope",
                text: "Shows the aggregate status of all parallel tasks. It never shows prompts, tool arguments, tool output, or model text; degraded only means the corresponding system capability is currently unavailable."
            )
        } header: {
            Label("Current system projection", systemImage: "waveform.path.ecg")
        }
    }

    private var tierLabel: String {
        switch projection.survivalTier {
        case .foreground: "Foreground"
        case .finiteBackgroundTask: "Short background"
        case .continuedProcessing: "Continued Processing"
        case .extendedAudio: "Audio extension"
        case .extendedLocation: "Extended location"
        case .degraded: "Degraded"
        }
    }

    private var tierIcon: String {
        switch projection.survivalTier {
        case .foreground: "iphone"
        case .finiteBackgroundTask: "timer"
        case .continuedProcessing: "arrow.clockwise.icloud"
        case .extendedAudio: "speaker.wave.2"
        case .extendedLocation: "location.fill"
        case .degraded: "exclamationmark.triangle"
        }
    }

    private var tierTint: Color {
        switch projection.survivalTier {
        case .foreground: .secondary
        case .finiteBackgroundTask, .continuedProcessing: .blue
        case .extendedAudio, .extendedLocation: .green
        case .degraded: .orange
        }
    }

    private func statusRow(
        _ title: String,
        value: String,
        icon: String,
        tint: Color = .secondary
    ) -> some View {
        HStack(spacing: HarnessTheme.Spacing.medium) {
            HarnessIconTile(systemImage: icon, tint: tint, size: 28)
            Text(title)
            Spacer(minLength: 8)
            Text(value)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }

    private var degradedLabel: String {
        projection.degradedReasons.map {
            switch $0 {
            case .lowPowerMode: "Low Power Mode"
            case .thermalPressure: "Thermal pressure"
            case .audioUnavailable: "Audio unavailable"
            case .locationUnavailable: "Location unavailable"
            }
        }.sorted().joined(separator: ", ")
    }
}

private struct BackgroundLiveActivitySettingsSection: View {
    @Binding var isEnabled: Bool
    let isSystemSupported: Bool
    let areActivitiesEnabled: Bool

    var body: some View {
        Section {
            if isSystemSupported {
                Toggle("Live Activity", isOn: $isEnabled)
                LabeledContent(
                    "System permissions",
                    value: areActivitiesEnabled ? "Allowed" : "Turned off in system settings"
                )
            } else {
                Toggle("Live Activity", isOn: .constant(false))
                    .disabled(true)
            }
            BackgroundDetailsRow(
                title: "About Live Activity",
                text: isSystemSupported
                    ? "Shows the current session, step, tools, and real progress. It only projects task state and does not give the app permanent background execution; turning it off immediately removes the current Live Activity."
                    : "The current device environment does not support ActivityKit Live Activities."
            )
        } header: {
            Label("Lock Screen and Dynamic Island", systemImage: "rectangle.topthird.inset.filled")
        }
    }
}

private struct BackgroundExecutionSettingsSection: View {
    @Binding var isEnabled: Bool
    let isSystemSupported: Bool

    var body: some View {
        Section {
            if isSystemSupported {
                Toggle("Enhanced background processing", isOn: $isEnabled)
            } else {
                Toggle("Enhanced background processing", isOn: .constant(false))
                    .disabled(true)
            }
            BackgroundDetailsRow(
                title: "How it works and limits",
                text: isSystemSupported
                    ? "Combines iOS 26 Continued Processing with audio/location extension during the task. When the system background time quota expires, the old lease ends as long as the extension layer is still healthy, a new finite lease is attached, and the same task and context continue; this is not a provider quota renewal, and the system can still terminate the app for resource, thermal or user reasons."
                    : "The current system does not support Continued Processing. On iOS 18–25 only the short background time provided by the system is used, and continuous running is not guaranteed."
            )
        } header: {
            Label("Background execution", systemImage: "arrow.clockwise.icloud")
        }
    }
}

private struct BackgroundLocationKeepAliveSettingsSection: View {
    @Binding var isEnabled: Bool
    let snapshot: BackgroundLocationKeepAliveSnapshot
    let requestAuthorization: () -> Void

    var body: some View {
        Section {
            Toggle("Background coarse location keep-alive", isOn: $isEnabled)
            LabeledContent("Location permission", value: authorizationLabel)
            if isEnabled && (snapshot.authorization == .notDetermined || snapshot.authorization == .whenInUse) {
                Button("Request Always location access", action: requestAuthorization)
            }
            LabeledContent("Current status", value: phaseLabel)
            BackgroundDetailsRow(
                title: "Location use and privacy",
                text: "Location services at about 3 km accuracy are used only when this switch is on, Always location is allowed, the app has been in the background for about 15 seconds, and tasks are still running. Coordinates are never saved, shown, or uploaded; an ordinary one-shot location tool does not trigger this authorization."
            )
        } header: {
            Label("Optional location keep-alive", systemImage: "location.fill")
        }
    }

    private var authorizationLabel: String {
        switch snapshot.authorization {
        case .notDetermined: "Not yet requested"
        case .whenInUse: "While using"
        case .always: "Always allow"
        case .denied: "Denied"
        case .restricted: "Limited by system"
        case .unavailable: "Unavailable"
        }
    }

    private var phaseLabel: String {
        switch snapshot.phase {
        case .idle: "Not running"
        case .waitingForDelay: "Waiting for background delay"
        case .waitingForPermission: "Waiting for permission"
        case .running: "Running"
        case .degraded: "Unavailable"
        }
    }
}

private struct BackgroundNotificationSettingsSection: View {
    @Binding var isEnabled: Bool
    let authorization: BackgroundNotificationAuthorization
    let errorDescription: String?

    var body: some View {
        Section {
            Toggle("Task notifications", isOn: $isEnabled)
            LabeledContent("System permissions", value: authorizationLabel)
            if let errorDescription {
                Text("Notification authorization failed: \(errorDescription)")
                    .foregroundStyle(.red)
            } else if authorization == .denied {
                Text("Notification preferences were saved, but system permission was denied. Allow notifications in system settings to receive task completion alerts.")
                    .foregroundStyle(.orange)
            }
            BackgroundDetailsRow(
                title: "About notifications",
                text: "Sends a local notification only when the task finishes. System notification permission is requested only when you turn the switch on."
            )
        } header: {
            Label("Task notifications", systemImage: "bell.badge")
        }
    }

    private var authorizationLabel: String {
        switch authorization {
        case .notDetermined:
            "Not yet requested"
        case .denied:
            "Denied"
        case .authorized:
            "Allowed"
        case .unavailable:
            "Unavailable"
        }
    }
}

private struct BackgroundPrivacySettingsSection: View {
    @Binding var isEnabled: Bool

    var body: some View {
        Section {
            Toggle("Task status privacy", isOn: $isEnabled)
            BackgroundDetailsRow(
                title: "About privacy display",
                text: "When on, the lock screen, Dynamic Island status and completion notifications show only generic task state, without session titles, tool names or reply content."
            )
        } header: {
            Label("Privacy display", systemImage: "eye.slash")
        }
    }
}

private struct BackgroundRuntimeStatusSection: View {
    let status: BackgroundRuntimeStatus
    let privacyModeEnabled: Bool
    let isContinuedProcessingSupported: Bool
    let isLiveActivitySupported: Bool
    let isLiveActivityEnabled: Bool

    var body: some View {
        Section {
            LabeledContent(
                "Continued Processing",
                value: isContinuedProcessingSupported ? "Available on iOS 26" : "Currently unavailable"
            )
            LabeledContent(
                "Live Activity",
                value: liveActivityStatus
            )
            runtimeContent
            BackgroundDetailsRow(
                title: "Status details",
                text: "Continued Processing and Live Activity are both managed by iOS. Live Activity shows only real task state; neither is a guarantee of unlimited background time or a persistent process."
            )
        } header: {
            Label("Status", systemImage: "chart.bar.xaxis")
        }
    }

    private var liveActivityStatus: String {
        guard isLiveActivitySupported else { return "Currently unavailable" }
        return isLiveActivityEnabled ? "Enabled" : "Off"
    }

    @ViewBuilder
    private var runtimeContent: some View {
        switch status {
        case .idle:
            HarnessStatusPill(title: "Idle", systemImage: "pause.circle", tint: .secondary)
        case let .running(progress):
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Current task")
                    Spacer()
                    HarnessStatusPill(title: "Running", systemImage: "bolt.fill", tint: .green)
                    Text("\(progress.completedUnitCount)/\(progress.totalUnitCount)")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                ProgressView(
                    value: Double(progress.completedUnitCount),
                    total: Double(progress.totalUnitCount)
                )
                if privacyModeEnabled {
                    Text("Task in progress")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Text(progress.title)
                        .font(.footnote)
                    Text(progress.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .combine)
        case let .completed(success):
            HarnessStatusPill(
                title: success ? "Done" : "Not finished",
                systemImage: success ? "checkmark.circle.fill" : "xmark.circle.fill",
                tint: success ? .green : .red
            )
        case .interrupted:
            HarnessStatusPill(title: "Interrupted by the system", systemImage: "pause.circle", tint: .orange)
        }
    }
}

private struct BackgroundDetailsRow: View {
    let title: String
    let text: String

    var body: some View {
        DisclosureGroup(title) {
            Text(text)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, HarnessTheme.Spacing.xSmall)
        }
        .font(.footnote)
    }
}

private struct BackgroundSafetyBoundarySection: View {
    var body: some View {
        Section {
            Label("Silent audio runs only when it is enabled, tasks are still running, and the app is in the background", systemImage: "speaker.wave.2")
            Label("Background location must be enabled separately and requires Always authorization; coordinates are never stored or uploaded", systemImage: "location")
            Label("Does not fake background modes with Bluetooth or VoIP", systemImage: "checkmark.shield")
        } header: {
            Label("Execution limits", systemImage: "checkmark.shield")
        }
    }
}
