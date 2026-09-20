import XCTest

@MainActor
final class HarnessMobileOnboardingUITests: XCTestCase {
    func testResetAlwaysReturnsToOnboarding() {
        let app = XCUIApplication()
        addTeardownBlock {
            app.terminate()
        }

        launchResetAndAssertOnboarding(app)
        launchResetAndAssertOnboarding(app)
    }

    func testOnboardingKeepsAdvancedInferenceInSettings() {
        let app = XCUIApplication()
        addTeardownBlock {
            app.terminate()
        }

        app.launchArguments = [
            "-reset-persistent-state-for-ui-testing",
            "-disable-animations-for-ui-testing",
        ]
        app.launch()

        XCTAssertTrue(app.navigationBars["Set up Harness"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["provider-picker"].isHittable)
        for _ in 0..<6 {
            app.swipeUp(velocity: .fast)
        }
        XCTAssertTrue(app.staticTexts["Security boundary"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Reasoning"].exists)
    }

    private func launchResetAndAssertOnboarding(_ app: XCUIApplication) {
        app.launchArguments = [
            "-reset-persistent-state-for-ui-testing",
            "-disable-animations-for-ui-testing",
        ]
        app.launch()

        XCTAssertTrue(app.navigationBars["Set up Harness"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.secureTextFields["api-key-field"].exists)
        XCTAssertFalse(app.textFields["provider-display-name-field"].exists)
        XCTAssertFalse(app.keyboards.firstMatch.exists)
        let saveButton = app.buttons["save-configuration"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        XCTAssertTrue(saveButton.isHittable)
        XCTAssertFalse(app.tabBars.buttons["Settings"].exists)
    }
}

@MainActor
final class HarnessMobileConversationModeUITests: XCTestCase {
    func testConversationSwitchesBetweenChatAndTrajectory() {
        let app = XCUIApplication()
        addTeardownBlock {
            app.terminate()
        }
        app.launchArguments = [
            "-reset-persistent-state-for-ui-testing",
            "-bootstrap-configuration-for-ui-testing",
            "-disable-animations-for-ui-testing",
        ]
        app.launch()

        openConversation(in: app)

        app.buttons["Session options"].tap()
        let trajectoryMode = app.buttons["Trajectory"]
        XCTAssertTrue(trajectoryMode.waitForExistence(timeout: 5))
        trajectoryMode.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["harness-trace-strip"]
                .waitForExistence(timeout: 10)
        )

        app.buttons["Session options"].tap()
        let chatMode = app.buttons["Chat"]
        XCTAssertTrue(chatMode.waitForExistence(timeout: 5))
        chatMode.tap()
        XCTAssertTrue(app.descendants(matching: .any)["chat-input"].waitForExistence(timeout: 5))
    }
}

@MainActor
final class HarnessMobileSessionModelPickerUITests: XCTestCase {
    func testSessionModelPickerShowsScopeAndSearchableModels() {
        let app = XCUIApplication()
        addTeardownBlock { app.terminate() }
        app.launchArguments = [
            "-reset-persistent-state-for-ui-testing",
            "-bootstrap-configuration-for-ui-testing",
            "-disable-animations-for-ui-testing",
        ]
        app.launch()

        openConversation(in: app)
        let modelButton = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Select model, current")
        ).firstMatch
        XCTAssertTrue(modelButton.waitForExistence(timeout: 5))
        modelButton.tap()

        XCTAssertTrue(app.navigationBars["Session model"].waitForExistence(timeout: 5))
        let followDefault = app.switches["session-model-follow-global"]
        XCTAssertTrue(followDefault.isHittable)
        XCTAssertTrue(app.buttons["session-model-option-deepseek-v4-flash"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["session-model-option-deepseek-v4-pro"].exists)
        XCTAssertTrue(app.searchFields["Search model ID or name"].exists)
        attachScreenshot(named: "model-picker-follow-default")

        app.buttons["session-model-option-deepseek-v4-pro"].tap()
        XCTAssertEqual(followDefault.value as? String, "0")
        XCTAssertTrue(app.buttons["session-model-provider-picker"].waitForExistence(timeout: 5))
        // Selecting a model toggles follow-default off, which re-renders the
        // list and resets scroll to the top; the manual-ID field falls out of
        // the lazy list window, so scroll it back into view first.
        let modelField = app.textFields["session-model-field"]
        scrollUntilExists(modelField, in: app)
        XCTAssertTrue(modelField.exists)
        XCTAssertEqual(modelField.value as? String, "deepseek-v4-pro")
        attachScreenshot(named: "model-picker-session-override")
    }

    private func attachScreenshot(named name: String) {
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}

@MainActor
final class HarnessMobilePhonePermissionsUITests: XCTestCase {
    func testPhonePermissionsShowsGroupedStatusAndSystemSettingsLink() {
        let app = XCUIApplication()
        addTeardownBlock { app.terminate() }
        app.launchArguments = [
            "-reset-persistent-state-for-ui-testing",
            "-bootstrap-configuration-for-ui-testing",
            "-disable-animations-for-ui-testing",
        ]
        app.launch()

        XCTAssertTrue(app.navigationBars["Harness"].waitForExistence(timeout: 15))
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 10))
        let permissions = app.buttons["settings-phone-permissions"]
        scrollUntilHittable(permissions, in: app)
        permissions.tap()

        XCTAssertTrue(app.navigationBars["Phone permissions"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Privacy access"].exists)
        XCTAssertTrue(app.staticTexts["Camera"].exists)
        XCTAssertTrue(app.staticTexts["Not yet requested"].firstMatch.exists)
        XCTAssertTrue(app.buttons["Refresh permission status"].isHittable)
        let cameraPurpose = app.staticTexts["Used for taking photos and on-device OCR."]
        XCTAssertFalse(cameraPurpose.exists)
        app.buttons["phone-permission-camera"].tap()
        XCTAssertTrue(cameraPurpose.waitForExistence(timeout: 5))
        let firstScreen = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        firstScreen.name = "phone-permissions-first-screen"
        firstScreen.lifetime = .keepAlways
        add(firstScreen)

        let systemSettings = app.buttons["Open iOS settings"]
        scrollUntilHittable(systemSettings, in: app)
        XCTAssertTrue(app.staticTexts["Additional capabilities"].exists)
        XCTAssertTrue(app.staticTexts["HealthKit"].exists)
        XCTAssertTrue(systemSettings.isHittable)
        let lastScreen = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        lastScreen.name = "phone-permissions-last-screen"
        lastScreen.lifetime = .keepAlways
        add(lastScreen)
    }
}

@MainActor
final class HarnessMobileMemoryManagementUITests: XCTestCase {
    func testMemoryManagementKeepsSessionScopeAndExportVisible() {
        let app = XCUIApplication()
        addTeardownBlock { app.terminate() }
        app.launchArguments = [
            "-reset-persistent-state-for-ui-testing",
            "-bootstrap-configuration-for-ui-testing",
            "-disable-animations-for-ui-testing",
        ]
        app.launch()

        XCTAssertTrue(app.navigationBars["Harness"].waitForExistence(timeout: 15))
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 10))
        let memory = app.buttons["settings-memory"]
        scrollUntilHittable(memory, in: app)
        memory.tap()

        XCTAssertTrue(app.navigationBars["Memory"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.switches["Allow use of saved memories"].exists)
        XCTAssertTrue(app.buttons["About session memory"].exists)
        XCTAssertFalse(app.staticTexts["When off, this session does not inject or read saved memories. Turning it back on does not delete any records."].exists)
        XCTAssertTrue(app.staticTexts["Saved memory"].exists)
        XCTAssertTrue(app.staticTexts["No saved memory"].exists)
        XCTAssertTrue(app.buttons["memory-export-json"].exists)
        let privacyDetails = app.buttons["Storage and sending scope"]
        XCTAssertTrue(privacyDetails.exists)
        let privacyExplanation = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Memory is saved on-device only")
        ).firstMatch
        XCTAssertFalse(privacyExplanation.exists)
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "memory-management-empty-state"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        privacyDetails.tap()
        XCTAssertTrue(privacyExplanation.waitForExistence(timeout: 5))
    }
}

@MainActor
final class HarnessMobilePluginSettingsUITests: XCTestCase {
    func testPluginSettingsShowsHostStateFromPluginRoute() {
        let app = XCUIApplication()
        addTeardownBlock { app.terminate() }
        app.launchArguments = [
            "-reset-persistent-state-for-ui-testing",
            "-bootstrap-configuration-for-ui-testing",
            "-disable-animations-for-ui-testing",
        ]
        app.launch()

        XCTAssertTrue(app.navigationBars["Harness"].waitForExistence(timeout: 15))
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 10))
        let plugins = app.buttons["Cordis plugins"]
        scrollUntilHittable(plugins, in: app)
        plugins.tap()

        XCTAssertTrue(app.navigationBars["Plugin"].waitForExistence(timeout: 10))
        let settings = app.buttons["ish-plugin-settings"]
        scrollUntilHittable(settings, in: app)
        settings.tap()

        XCTAssertTrue(app.navigationBars["Plugin settings"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["ish-plugin-settings-list"].exists)
        XCTAssertTrue(app.buttons["ish-plugin-settings-refresh"].exists)
        XCTAssertTrue(app.staticTexts["Starting the settings Host"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["ish-plugin-settings-loading"].exists)
        XCTAssertFalse(app.buttons["Start Host"].exists)
        XCTAssertFalse(app.searchFields["Search namespace"].exists)
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "plugin-settings-host-state"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    func testPluginSettingsNamespaceKeepsStatusAndEditorVisible() {
        let app = XCUIApplication()
        addTeardownBlock { app.terminate() }
        app.launchArguments = [
            "-reset-persistent-state-for-ui-testing",
            "-bootstrap-configuration-for-ui-testing",
            "-disable-animations-for-ui-testing",
            "-present-plugin-settings-for-ui-testing",
        ]
        app.launch()

        XCTAssertTrue(app.navigationBars["Harness"].waitForExistence(timeout: 15))
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 10))
        let plugins = app.buttons["Cordis plugins"]
        scrollUntilHittable(plugins, in: app)
        plugins.tap()

        XCTAssertTrue(app.navigationBars["Plugin"].waitForExistence(timeout: 10))
        let settings = app.buttons["ish-plugin-settings"]
        scrollUntilHittable(settings, in: app)
        settings.tap()

        XCTAssertTrue(app.navigationBars["Plugin settings"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.searchFields["Search namespaces"].exists)
        let namespace = app.buttons["ish-plugin-settings-namespace-memory-notes"]
        XCTAssertTrue(namespace.waitForExistence(timeout: 5))
        namespace.tap()

        XCTAssertTrue(app.navigationBars["memory-notes"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["ish-plugin-settings-editor"].exists)
        XCTAssertFalse(app.staticTexts["Namespace"].exists)
        XCTAssertFalse(app.staticTexts["Revision"].exists)
        XCTAssertTrue(app.staticTexts["Revision"].exists)
        XCTAssertTrue(app.staticTexts["Max records"].exists)
        XCTAssertTrue(app.buttons["ish-plugin-settings-save"].exists)
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "plugin-settings-namespace-editor"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}

@MainActor
final class HarnessMobileConcurrentRunsUITests: XCTestCase {
    func testCreatingAndSwitchingSessionsKeepsBothRootRunsVisible() {
        let app = XCUIApplication()
        addTeardownBlock { app.terminate() }
        app.launchArguments = [
            "-reset-persistent-state-for-ui-testing",
            "-bootstrap-configuration-for-ui-testing",
            "-disable-animations-for-ui-testing",
            "-present-concurrent-session-runs-for-ui-testing",
        ]
        app.launch()

        let firstSession = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "New session")
        ).firstMatch
        let secondSession = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "Concurrent session B")
        ).firstMatch
        XCTAssertTrue(firstSession.waitForExistence(timeout: 15))
        XCTAssertTrue(secondSession.exists)
        XCTAssertEqual(
            app.staticTexts.matching(NSPredicate(format: "label == %@", "Running")).count,
            2
        )

        secondSession.tap()
        XCTAssertTrue(app.descendants(matching: .any)["chat-input"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Working deeper…"].waitForExistence(timeout: 5))
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "chat-running-status"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(firstSession.waitForExistence(timeout: 5))
        XCTAssertEqual(
            app.staticTexts.matching(NSPredicate(format: "label == %@", "Running")).count,
            2
        )
    }

    func testQueuedInputKeepsActionsReachableWhileRunning() {
        let app = XCUIApplication()
        addTeardownBlock { app.terminate() }
        app.launchArguments = [
            "-reset-persistent-state-for-ui-testing",
            "-bootstrap-configuration-for-ui-testing",
            "-disable-animations-for-ui-testing",
            "-present-concurrent-session-runs-for-ui-testing",
        ]
        app.launch()

        let currentProject = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "New session", "Running")
        ).firstMatch
        XCTAssertTrue(currentProject.waitForExistence(timeout: 15))
        currentProject.tap()

        XCTAssertTrue(app.staticTexts["Queued 1"].waitForExistence(timeout: 5))
        let actions = app.buttons["Queued message actions"]
        XCTAssertTrue(actions.exists)
        XCTAssertFalse(app.buttons["Edit queued message"].exists)
        XCTAssertTrue(app.buttons["Stop the current run"].exists)
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "chat-queued-input-actions"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        actions.tap()
        XCTAssertTrue(app.buttons["Edit queued message"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Set queued message as steer"].exists)
        XCTAssertTrue(app.buttons["Remove queued message"].exists)
    }
}

@MainActor
final class HarnessMobileWorkspaceHierarchyUITests: XCTestCase {
    func testWorkspaceRootExposesFilesMountsAndSessionStateFromHome() {
        let app = XCUIApplication()
        addTeardownBlock { app.terminate() }
        app.launchArguments = [
            "-reset-persistent-state-for-ui-testing",
            "-bootstrap-configuration-for-ui-testing",
            "-disable-animations-for-ui-testing",
        ]
        app.launch()

        XCTAssertTrue(app.buttons["Tool"].waitForExistence(timeout: 15))
        app.buttons["Tool"].tap()
        XCTAssertTrue(app.navigationBars["Tool"].waitForExistence(timeout: 5))
        let open = app.buttons["tool-route-workspace"]
        XCTAssertTrue(open.waitForExistence(timeout: 5))
        XCTAssertTrue(open.isHittable)
        open.tap()
        XCTAssertTrue(app.navigationBars["Workspace"].waitForExistence(timeout: 5))
    }
}

@MainActor
final class HarnessMobileAccessibilityUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .landscapeLeft
    }

    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
        super.tearDown()
    }

    func testHomeAtAccessibilityXXXLInDarkLandscape() {
        let app = launchAccessibilityApp()
        addTeardownBlock { app.terminate() }

        XCTAssertTrue(app.navigationBars["Harness"].waitForExistence(timeout: 15))
        assertSystemToolbarTarget(app.buttons["Settings"], named: "Home settings")
        assertSystemToolbarTarget(app.buttons["Filter and sort"], named: "Home filters and sorting")
        assertSystemToolbarTarget(app.buttons["Tool"], named: "Home tools")
        let project = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "New session")).firstMatch
        assertCriticalTarget(project, named: "Home project entry")
        attachAccessibilityEvidence(for: app, surface: "home")
    }

    func testTerminalAtAccessibilityXXXLInDarkLandscape() {
        let app = launchAccessibilityApp()
        addTeardownBlock { app.terminate() }

        openTerminal(in: app)
        XCTAssertTrue(app.navigationBars["iSH"].waitForExistence(timeout: 15))

        let field = app.descendants(matching: .any)["ish-command-field"]
        assertCriticalTarget(field, named: "Terminal command input")
        XCTAssertTrue(
            app.descendants(matching: .any)["ish-ready-status"]
                .waitForExistence(timeout: 120)
        )
        field.tap()
        field.typeText("pwd")
        assertCriticalTarget(app.buttons["ish-run-command"], named: "Run a command in the terminal")
        attachAccessibilityEvidence(for: app, surface: "terminal")
    }

    func testChatAtAccessibilityXXXLInDarkLandscape() {
        let app = launchAccessibilityApp()
        addTeardownBlock { app.terminate() }

        openConversation(in: app)
        assertSystemToolbarTarget(app.buttons["Session options"], named: "Chat session options")
        assertCriticalTarget(app.buttons["Add content"], named: "Add chat content")
        assertCriticalTarget(app.buttons["Command"], named: "Chat commands")

        let field = app.descendants(matching: .any)["chat-input"]
        assertCriticalTarget(field, named: "Chat input")
        field.tap()
        field.typeText("accessibility audit")
        assertCriticalTarget(app.buttons["chat-send-button"], named: "Send in chat")
        attachAccessibilityEvidence(for: app, surface: "chat")
    }

    func testSettingsAtAccessibilityXXXLInDarkLandscape() {
        let app = launchAccessibilityApp()
        addTeardownBlock { app.terminate() }

        XCTAssertTrue(app.navigationBars["Harness"].waitForExistence(timeout: 15))
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 15))
        let modelProviders = app.buttons["settings-model-providers"]
        scrollUntilHittable(modelProviders, in: app)
        assertCriticalTarget(modelProviders, named: "Set model and provider")

        let phonePermissions = app.buttons["settings-phone-permissions"]
        scrollUntilHittable(phonePermissions, in: app)
        assertCriticalTarget(phonePermissions, named: "Set phone permissions")
        attachAccessibilityEvidence(for: app, surface: "settings")
    }

    private func launchAccessibilityApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-reset-persistent-state-for-ui-testing",
            "-bootstrap-configuration-for-ui-testing",
            "-disable-animations-for-ui-testing",
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityXXXL",
            "-force-dark-mode-for-ui-testing",
        ]
        app.launch()
        return app
    }

    private func assertCriticalTarget(
        _ element: XCUIElement,
        named name: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(
            element.waitForExistence(timeout: 10),
            "\(name) does not exist",
            file: file,
            line: line
        )
        XCTAssertTrue(element.isHittable, "\(name) is not tappable", file: file, line: line)
        XCTAssertFalse(element.label.isEmpty, "\(name) has no accessibility name", file: file, line: line)
        XCTAssertGreaterThanOrEqual(
            element.frame.width,
            44,
            "\(name) is narrower than 44pt: \(element.frame.width)",
            file: file,
            line: line
        )
        XCTAssertGreaterThanOrEqual(
            element.frame.height,
            44,
            "\(name) is shorter than 44pt: \(element.frame.height)",
            file: file,
            line: line
        )
    }

    private func assertSystemToolbarTarget(
        _ element: XCUIElement,
        named name: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(
            element.waitForExistence(timeout: 10),
            "\(name) does not exist",
            file: file,
            line: line
        )
        XCTAssertTrue(element.isHittable, "\(name) is not tappable", file: file, line: line)
        XCTAssertFalse(element.label.isEmpty, "\(name) has no accessibility name", file: file, line: line)
    }

    private func scrollUntilHittable(_ element: XCUIElement, in app: XCUIApplication) {
        let scroller = app.collectionViews.firstMatch
        for _ in 0..<6 where !element.isHittable {
            scroller.swipeUp(velocity: .slow)
        }
    }

    private func scrollUntilExists(_ element: XCUIElement, in app: XCUIApplication) {
        let scroller = app.collectionViews.firstMatch
        for _ in 0..<6 where !element.exists {
            scroller.swipeUp(velocity: .slow)
        }
    }

    private func attachAccessibilityEvidence(for app: XCUIApplication, surface: String) {
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "UI-004-\(surface)-AccessibilityXXXL-dark-landscape"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        let tree = XCTAttachment(string: app.debugDescription)
        tree.name = "UI-004-\(surface)-accessibility-tree"
        tree.lifetime = .keepAlways
        add(tree)
    }
}

@MainActor
final class HarnessMobileProgressiveDisclosureUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testHomePrioritizesProjectsAndMovesSecondaryToolsToToolsRoute() {
        let app = launchConfiguredApp()
        addTeardownBlock { app.terminate() }

        XCTAssertTrue(app.navigationBars["Harness"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["Project"].exists)
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "New session")).firstMatch.exists)
        XCTAssertFalse(app.buttons["home-continue-task"].exists)
        XCTAssertFalse(app.buttons["home-background-status"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["workspace-hierarchy-root"].exists)

        app.buttons["Tool"].tap()
        XCTAssertTrue(app.navigationBars["Tool"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["tool-route-terminal"].exists)
        XCTAssertTrue(app.buttons["tool-route-workspace"].exists)
        XCTAssertTrue(app.buttons["tool-route-settings"].exists)
        XCTAssertTrue(app.staticTexts["Goals, plans, todos, and the Harness call chain"].exists)
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "tools-overview"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    func testSettingsGroupsBackgroundStorageAndPrivacyWithoutHidingRoutes() {
        let app = launchConfiguredApp()
        addTeardownBlock { app.terminate() }

        app.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["settings-model-providers"].exists)
        XCTAssertTrue(app.buttons["settings-background-tasks"].exists)
        XCTAssertTrue(app.buttons["settings-phone-permissions"].exists)
        let workspace = app.descendants(matching: .any)["settings-workspace"]
        scrollUntilExists(workspace, in: app)
        XCTAssertTrue(workspace.exists)
        let diagnostics = app.descendants(matching: .any)["settings-diagnostics"]
        scrollUntilExists(diagnostics, in: app)
        XCTAssertTrue(diagnostics.exists)

        scrollToTop(in: app)
        scrollUntilHittable(app.buttons["settings-background-tasks"], in: app)
        app.buttons["settings-background-tasks"].tap()
        XCTAssertTrue(app.navigationBars["Background jobs"].waitForExistence(timeout: 10))
        let firstScreen = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        firstScreen.name = "background-settings-first-screen"
        firstScreen.lifetime = .keepAlways
        add(firstScreen)
        let executionDetails = app.buttons["How it works and limits"]
        XCTAssertTrue(executionDetails.isHittable)
        let executionExplanation = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Combines iOS 26")
        ).firstMatch
        XCTAssertFalse(executionExplanation.exists)
        executionDetails.tap()
        XCTAssertTrue(executionExplanation.waitForExistence(timeout: 5))
        executionDetails.tap()
        let projectionHeader = app.staticTexts["Current system projection"]
        scrollUntilExists(projectionHeader, in: app)
        XCTAssertTrue(projectionHeader.exists)
        let activeRuns = app.staticTexts["Active tasks"]
        scrollUntilExists(activeRuns, in: app)
        XCTAssertTrue(activeRuns.exists)
        let safetyBoundary = app.staticTexts["Execution limits"]
        scrollUntilExists(safetyBoundary, in: app)
        XCTAssertTrue(safetyBoundary.exists)
        let lastScreen = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        lastScreen.name = "background-settings-last-screen"
        lastScreen.lifetime = .keepAlways
        add(lastScreen)
    }

    func testProviderManagementMovesRequestBehaviorToFocusedSubpage() {
        let app = launchConfiguredApp()
        addTeardownBlock { app.terminate() }

        app.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 15))
        app.buttons["settings-model-providers"].tap()
        XCTAssertTrue(app.navigationBars["Models and providers"].waitForExistence(timeout: 10))

        let behavior = app.buttons["provider-behavior-settings"]
        XCTAssertTrue(behavior.waitForExistence(timeout: 5))
        behavior.tap()

        XCTAssertTrue(app.navigationBars["Model behavior"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Context compaction"].exists)
        XCTAssertTrue(app.staticTexts["Time context"].exists)
        XCTAssertTrue(app.staticTexts["Session title"].exists)
        let timeContextToggles = app.switches.matching(
            NSPredicate(format: "label == %@", "Give the Agent the current time")
        )
        XCTAssertEqual(timeContextToggles.count, 1)

        let initialScreen = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        initialScreen.name = "provider-behavior-default"
        initialScreen.lifetime = .keepAlways
        add(initialScreen)

        let timeContextToggle = timeContextToggles.firstMatch
        XCTAssertEqual(timeContextToggle.value as? String, "0")
        timeContextToggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertEqual(timeContextToggle.value as? String, "1")
        let timeZone = app.descendants(matching: .any).matching(
            NSPredicate(format: "label BEGINSWITH %@", "Show time zone")
        ).firstMatch
        let refreshInterval = app.descendants(matching: .any).matching(
            NSPredicate(format: "label BEGINSWITH %@", "Refresh interval")
        ).firstMatch
        XCTAssertTrue(timeZone.waitForExistence(timeout: 5))
        XCTAssertTrue(refreshInterval.exists)
        let expandedScreen = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        expandedScreen.name = "provider-behavior-time-enabled"
        expandedScreen.lifetime = .keepAlways
        add(expandedScreen)
    }

    func testJobsPanelKeepsEmptyStateAndRefreshReachable() {
        let app = launchConfiguredApp()
        addTeardownBlock { app.terminate() }

        openConversation(in: app)
        app.buttons["Session options"].tap()
        let jobs = app.buttons["Background jobs"]
        XCTAssertTrue(jobs.waitForExistence(timeout: 5))
        jobs.tap()

        XCTAssertTrue(app.navigationBars["Background jobs"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["No background tasks"].exists)
        XCTAssertTrue(app.buttons["Refresh background tasks"].exists)
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "jobs-panel-empty"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    func testSessionOptionsKeepsConversationControlsReachable() {
        let app = launchConfiguredApp()
        addTeardownBlock { app.terminate() }

        openConversation(in: app)
        app.buttons["Session options"].tap()

        XCTAssertTrue(app.buttons["Chat"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Trajectory"].exists)
        XCTAssertTrue(app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Agent preset: ")
        ).firstMatch.exists)
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "session-options"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        XCTAssertTrue(app.descendants(matching: .any)["Agent"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["Workspace write"].exists)
        XCTAssertTrue(app.buttons["Switch model"].exists)
        XCTAssertTrue(app.buttons["Settings"].exists)
        XCTAssertTrue(app.buttons["Background jobs"].exists)
        XCTAssertTrue(app.buttons["Export conversation"].exists)
    }

    func testAgentPresetPickerShowsAllSystemPresets() {
        let app = launchConfiguredApp()
        addTeardownBlock { app.terminate() }

        openConversation(in: app)
        app.buttons["Session options"].tap()
        let presetButton = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Agent preset: ")
        ).firstMatch
        XCTAssertTrue(presetButton.waitForExistence(timeout: 5))
        presetButton.tap()

        XCTAssertTrue(app.navigationBars["Agent preset"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["Standard mode"].value as? String, "Selected")
        XCTAssertTrue(app.buttons["PTC mode"].exists)
        XCTAssertTrue(app.buttons["Minimal mode"].exists)
        XCTAssertTrue(app.buttons["Creation mode"].exists)
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "agent-preset-picker"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    func testConversationExportExplainsRedactionBeforeChoosingFormat() {
        let app = launchConfiguredApp(extraArguments: ["-present-chat-error-for-ui-testing"])
        addTeardownBlock { app.terminate() }

        openConversation(in: app)
        app.buttons["Session options"].tap()
        let export = app.buttons["Export conversation"]
        XCTAssertTrue(export.waitForExistence(timeout: 5))
        XCTAssertTrue(export.isEnabled)
        export.tap()

        XCTAssertTrue(app.staticTexts["Export redacted conversation"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["JSON"].exists)
        XCTAssertTrue(app.buttons["Markdown"].exists)
        XCTAssertTrue(app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Export removes raw tool arguments")
        ).firstMatch.exists)
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "conversation-export-confirmation"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    func testRenameConversationKeepsTitleValidationVisible() {
        let app = launchConfiguredApp()
        addTeardownBlock { app.terminate() }

        XCTAssertTrue(app.navigationBars["Harness"].waitForExistence(timeout: 15))
        let currentSession = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "New session", "Current")
        ).firstMatch
        XCTAssertTrue(currentSession.waitForExistence(timeout: 5))
        currentSession.swipeLeft()
        let rename = app.buttons["Rename"]
        XCTAssertTrue(rename.waitForExistence(timeout: 5))
        rename.tap()

        XCTAssertTrue(app.navigationBars["Rename project"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields["Project name"].exists)
        XCTAssertTrue(app.staticTexts["The name is saved on-device and can be up to 80 characters."].exists)
        XCTAssertTrue(app.staticTexts["3/80"].exists)
        XCTAssertTrue(app.buttons["Cancel"].exists)
        XCTAssertTrue(app.buttons["Save"].exists)
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "rename-conversation"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    func testDeleteProjectExplainsLocalDataAndWorkspaceBoundary() {
        let app = launchConfiguredApp()
        addTeardownBlock { app.terminate() }

        XCTAssertTrue(app.navigationBars["Harness"].waitForExistence(timeout: 15))
        let currentSession = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "New session", "Current")
        ).firstMatch
        XCTAssertTrue(currentSession.waitForExistence(timeout: 5))
        currentSession.swipeLeft()
        let delete = app.buttons["Delete"]
        XCTAssertTrue(delete.waitForExistence(timeout: 5))
        delete.tap()

        XCTAssertTrue(app.staticTexts["Delete project?"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Delete \"New session\""].exists)
        XCTAssertTrue(app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Deletes the messages this project saved on the device")
        ).firstMatch.exists)
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "delete-project-confirmation"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    func testHomeNewProjectEntryUsesProjectLanguage() {
        let app = launchConfiguredApp()
        addTeardownBlock { app.terminate() }

        XCTAssertTrue(app.navigationBars["Harness"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["Project"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["New project"].exists)
        XCTAssertFalse(app.buttons["New session"].exists)
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "home-new-project-entry"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    func testArchivedProjectActionsUseProjectLanguage() {
        let app = launchConfiguredApp()
        addTeardownBlock { app.terminate() }

        XCTAssertTrue(app.navigationBars["Harness"].waitForExistence(timeout: 15))
        let currentProject = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "New session", "Current")
        ).firstMatch
        XCTAssertTrue(currentProject.waitForExistence(timeout: 5))
        currentProject.swipeRight()
        let archive = app.buttons["Archive"]
        XCTAssertTrue(archive.waitForExistence(timeout: 5))
        archive.tap()

        app.buttons["Filter and sort"].tap()
        let archivedScope = app.buttons["Archive"]
        XCTAssertTrue(archivedScope.waitForExistence(timeout: 5))
        archivedScope.tap()

        XCTAssertTrue(app.staticTexts["Archived"].waitForExistence(timeout: 10))
        let archivedProject = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "New session", "Archived")
        ).firstMatch
        XCTAssertTrue(archivedProject.waitForExistence(timeout: 5))
        archivedProject.press(forDuration: 1)
        XCTAssertTrue(app.buttons["Fork project"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Restore project"].exists)
        XCTAssertFalse(app.buttons["Resume session"].exists)
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "archived-project-actions"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    func testDiagnosticLogKeepsRuntimeAndExportActionsReachable() {
        let app = launchConfiguredApp()
        addTeardownBlock { app.terminate() }

        app.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 15))
        let diagnostics = app.descendants(matching: .any)["settings-diagnostics"]
        scrollUntilHittable(diagnostics, in: app)
        diagnostics.tap()

        XCTAssertTrue(app.navigationBars["Detailed log"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Current run"].exists)
        XCTAssertTrue(app.staticTexts["Cordis Host"].exists)
        let refresh = app.buttons["Refresh log"]
        scrollUntilHittable(refresh, in: app)
        XCTAssertTrue(refresh.isHittable)
        XCTAssertTrue(app.buttons["Export detailed log"].exists)
        let exportDetails = app.buttons["Export contents and redaction"]
        XCTAssertTrue(exportDetails.exists)
        let exportExplanation = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Export includes device and runtime status")
        ).firstMatch
        XCTAssertFalse(exportExplanation.exists)
        exportDetails.tap()
        XCTAssertTrue(exportExplanation.waitForExistence(timeout: 5))
        exportDetails.tap()

        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "diagnostic-log"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    func testToolApprovalsShowsRememberedGrantState() {
        let app = launchConfiguredApp()
        addTeardownBlock { app.terminate() }

        app.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 15))
        let approvals = app.descendants(matching: .any)["settings-tool-approvals"]
        scrollUntilHittable(approvals, in: app)
        approvals.tap()

        XCTAssertTrue(app.navigationBars["Tool grants"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["No long-term tool permissions"].exists)
        XCTAssertFalse(app.staticTexts["Remembered tool grants"].exists)
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "tool-approvals"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    func testAgentBundlesKeepsInstallControlsReachable() {
        let app = launchConfiguredApp()
        addTeardownBlock { app.terminate() }

        app.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 15))
        let bundles = app.descendants(matching: .any)["settings-agent-bundles"]
        scrollUntilHittable(bundles, in: app)
        bundles.tap()

        XCTAssertTrue(app.navigationBars["Agent orchestration"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Built-in Agent Bundle"].exists)
        XCTAssertFalse(app.staticTexts["RC.8 Profile Bundles"].exists)
        XCTAssertFalse(app.staticTexts["Not enabled"].exists)
        XCTAssertTrue(app.buttons["Install on phone"].firstMatch.exists)
        let installationDetails = app.buttons["Install and security"]
        XCTAssertTrue(installationDetails.exists)
        let explanation = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH %@", "URL, SHA-256")
        ).firstMatch
        XCTAssertFalse(explanation.exists)
        installationDetails.tap()
        XCTAssertTrue(explanation.waitForExistence(timeout: 5))
        installationDetails.tap()
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "agent-bundles"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    private func launchConfiguredApp(extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-reset-persistent-state-for-ui-testing",
            "-bootstrap-configuration-for-ui-testing",
            "-disable-animations-for-ui-testing",
        ] + extraArguments
        app.launch()
        return app
    }
}

@MainActor
final class HarnessMobileLongConversationUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testLongConversationStartsAtBoundedLatestWindowAndCanPageBackward() {
        let app = XCUIApplication()
        addTeardownBlock {
            app.terminate()
        }
        app.launchArguments = [
            "-reset-persistent-state-for-ui-testing",
            "-bootstrap-configuration-for-ui-testing",
            "-disable-animations-for-ui-testing",
            "-present-long-conversation-for-ui-testing",
        ]
        app.launch()

        openConversation(in: app)

        XCTAssertTrue(text(containing: "perf-message-999", in: app).waitForExistence(timeout: 10))
        XCTAssertFalse(text(containing: "perf-message-0", in: app).exists)

        let loadEarlierTools = app.buttons["Showing the first 20 tool calls"]
        XCTAssertTrue(loadEarlierTools.waitForExistence(timeout: 5))
        XCTAssertEqual(loadEarlierTools.value as? String, "96 earlier tool calls remain")
        for _ in 0..<3 where !loadEarlierTools.isHittable {
            app.swipeDown(velocity: .fast)
        }
        XCTAssertTrue(loadEarlierTools.isHittable)
        loadEarlierTools.tap()
        let pagedToolValue = NSPredicate(format: "value == %@", "76 earlier tool calls remaining")
        let pagedToolExpectation = XCTNSPredicateExpectation(
            predicate: pagedToolValue,
            object: loadEarlierTools
        )
        XCTAssertEqual(XCTWaiter.wait(for: [pagedToolExpectation], timeout: 5), .completed)

        let loadEarlier = app.descendants(matching: .any)["load-earlier-messages"]
        // Avoid querying an off-screen lazy element after every gesture: on
        // Xcode 27 each miss retries for about three seconds. Twelve fast
        // gestures cover the fixed 80-row initial window, then query once.
        for _ in 0..<12 {
            app.swipeDown(velocity: .fast)
        }
        XCTAssertTrue(loadEarlier.waitForExistence(timeout: 5))
        XCTAssertTrue(loadEarlier.isHittable)
        XCTAssertEqual(loadEarlier.value as? String, "920 earlier messages remain")
        loadEarlier.tap()

        let pagedValue = NSPredicate(format: "value == %@", "840 earlier messages remain")
        let pagedExpectation = XCTNSPredicateExpectation(predicate: pagedValue, object: loadEarlier)
        XCTAssertEqual(XCTWaiter.wait(for: [pagedExpectation], timeout: 10), .completed)
    }

    private func text(containing fragment: String, in app: XCUIApplication) -> XCUIElement {
        app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", fragment)
        ).firstMatch
    }
}

@MainActor
final class HarnessMobileTrajectoryUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testTrajectoryLedgersSearchCollapseAndInspect() {
        let app = XCUIApplication()
        addTeardownBlock { app.terminate() }
        app.launchArguments = [
            "-reset-persistent-state-for-ui-testing",
            "-bootstrap-configuration-for-ui-testing",
            "-disable-animations-for-ui-testing",
            "-present-trajectory-for-ui-testing",
        ]
        app.launch()

        openConversation(in: app)
        app.buttons["Session options"].tap()
        XCTAssertTrue(app.buttons["Trajectory"].waitForExistence(timeout: 5))
        app.buttons["Trajectory"].tap()

        XCTAssertTrue(app.staticTexts["Duration"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Turn"].exists)
        XCTAssertTrue(app.staticTexts["Call"].exists)
        XCTAssertTrue(app.staticTexts["Time to first token"].exists)
        XCTAssertTrue(app.staticTexts["Output"].exists)
        XCTAssertTrue(app.staticTexts["Cache"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["harness-trace-strip"].exists)

        let initialScreen = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        initialScreen.name = "trajectory-overview"
        initialScreen.lifetime = .keepAlways
        add(initialScreen)

        let ledger = app.segmentedControls.firstMatch
        XCTAssertTrue(ledger.waitForExistence(timeout: 5))
        ledger.buttons["Call"].tap()
        let toolEvent = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "Tool call")
        ).firstMatch
        XCTAssertTrue(toolEvent.waitForExistence(timeout: 5))
        toolEvent.tap()
        XCTAssertTrue(app.staticTexts["Tool call"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "1970", "year")
        ).firstMatch.exists)
        let toolInspector = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        toolInspector.name = "trajectory-tool-inspector"
        toolInspector.lifetime = .keepAlways
        add(toolInspector)
        app.navigationBars.buttons["Done"].tap()

        let resultEvent = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "Tool result")
        ).firstMatch
        XCTAssertTrue(resultEvent.waitForExistence(timeout: 5))
        resultEvent.tap()
        XCTAssertTrue(app.staticTexts["Tool result"].waitForExistence(timeout: 5))
        let resultInspector = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        resultInspector.name = "trajectory-result-inspector"
        resultInspector.lifetime = .keepAlways
        add(resultInspector)

        app.navigationBars.buttons["Done"].tap()
        ledger.buttons["Turn"].tap()
        let turnHeader = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "Turn 1")
        ).firstMatch
        XCTAssertTrue(turnHeader.waitForExistence(timeout: 5))
        turnHeader.tap()
        XCTAssertTrue(app.staticTexts["Request headers"].waitForExistence(timeout: 5))
        turnHeader.tap()
        XCTAssertTrue(app.staticTexts["Request headers"].exists)

        let search = app.searchFields["Search type, content, tool or Call ID"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("workspace_read_text")
        XCTAssertTrue(app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "workspace_read_text")
        ).firstMatch.waitForExistence(timeout: 5))
    }
}

@MainActor
final class HarnessMobileChatChromeUITests: XCTestCase {
    func testEmptyConversationKeepsPromptAndComposerVisible() {
        let app = XCUIApplication()
        addTeardownBlock { app.terminate() }
        app.launchArguments = [
            "-reset-persistent-state-for-ui-testing",
            "-bootstrap-configuration-for-ui-testing",
            "-disable-animations-for-ui-testing",
        ]
        app.launch()

        openConversation(in: app)

        XCTAssertTrue(app.buttons["What needs to be done?"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["chat-input"].exists)
        XCTAssertTrue(app.buttons["Add content"].exists)
        // The slash command entry is a persistent composer affordance now;
        // the command palette test taps it in this same empty state.
        XCTAssertTrue(app.buttons["Command"].isHittable)
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "chat-empty-state"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    func testAddContentMenuOnlyContainsAttachments() {
        let app = XCUIApplication()
        addTeardownBlock { app.terminate() }
        app.launchArguments = [
            "-reset-persistent-state-for-ui-testing",
            "-bootstrap-configuration-for-ui-testing",
            "-disable-animations-for-ui-testing",
        ]
        app.launch()

        openConversation(in: app)
        app.buttons["Add content"].tap()
        XCTAssertTrue(app.buttons["Choose image"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Take photo"].exists)
        XCTAssertTrue(app.buttons["Choose PDF, audio or video"].exists)
        XCTAssertTrue(app.buttons["Command"].exists)
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "chat-add-content-menu"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    func testCommandPaletteKeepsSuggestionsAboveComposer() {
        let app = XCUIApplication()
        addTeardownBlock { app.terminate() }
        app.launchArguments = [
            "-reset-persistent-state-for-ui-testing",
            "-bootstrap-configuration-for-ui-testing",
            "-disable-animations-for-ui-testing",
        ]
        app.launch()

        openConversation(in: app)
        app.buttons["Command"].tap()
        let input = app.descendants(matching: .any)["chat-input"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        XCTAssertEqual(input.value as? String, "/")
        XCTAssertTrue(app.staticTexts["Command"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "/")
        ).firstMatch.exists)
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "chat-command-palette"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    func testErrorStaysInlineAndCanBeDismissed() {
        let app = XCUIApplication()
        addTeardownBlock {
            app.terminate()
        }
        app.launchArguments = [
            "-reset-persistent-state-for-ui-testing",
            "-bootstrap-configuration-for-ui-testing",
            "-disable-animations-for-ui-testing",
            "-present-chat-error-for-ui-testing",
        ]
        app.launch()

        openConversation(in: app)

        let banner = app.descendants(matching: .any)["chat-error-banner"]
        XCTAssertTrue(banner.waitForExistence(timeout: 10))
        XCTAssertEqual(app.alerts.count, 0)

        let dismiss = app.buttons["Dismiss error"]
        XCTAssertTrue(dismiss.isHittable)
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "chat-inline-error"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        dismiss.tap()
        XCTAssertTrue(banner.waitForNonExistence(timeout: 3))
    }

    func testReasoningDisclosureKeepsModelContentReachable() {
        let app = XCUIApplication()
        addTeardownBlock { app.terminate() }
        app.launchArguments = [
            "-reset-persistent-state-for-ui-testing",
            "-bootstrap-configuration-for-ui-testing",
            "-disable-animations-for-ui-testing",
            "-present-reasoning-for-ui-testing",
        ]
        app.launch()

        openConversation(in: app)
        let reasoning = app.buttons["Thinking"]
        XCTAssertTrue(reasoning.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Thinking"].exists)
        reasoning.tap()
        XCTAssertTrue(app.staticTexts["Check the entry point first, then the state and visible actions."].waitForExistence(timeout: 5))
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "chat-reasoning-disclosure"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}

@MainActor
final class HarnessMobileMarkdownUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testWideMarkdownTableRemainsAccessibleAtLargeDynamicType() {
        let app = XCUIApplication()
        addTeardownBlock {
            app.terminate()
        }
        app.launchArguments = [
            "-reset-persistent-state-for-ui-testing",
            "-bootstrap-configuration-for-ui-testing",
            "-disable-animations-for-ui-testing",
            "-present-markdown-table-for-ui-testing",
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityXXXL",
        ]
        app.launch()

        openConversation(in: app)

        let table = app.scrollViews["Table, 3 rows, 5 columns"]
        XCTAssertTrue(table.waitForExistence(timeout: 10))
        XCTAssertEqual(table.label, "Table, 3 rows, 5 columns")
        XCTAssertTrue(app.staticTexts["Tool capability comparison"].exists)
        table.swipeLeft(velocity: .slow)
        XCTAssertTrue(app.staticTexts["Explain"].exists)
    }

    func testOneMillionCharacterMarkdownRendersFirstSegmentAndCopiesCompleteSource() {
        let app = XCUIApplication()
        addTeardownBlock {
            app.terminate()
        }
        app.launchArguments = [
            "-reset-persistent-state-for-ui-testing",
            "-bootstrap-configuration-for-ui-testing",
            "-disable-animations-for-ui-testing",
            "-present-large-markdown-for-ui-testing",
        ]
        app.launch()

        let started = Date()
        openConversation(in: app)
        let heading = app.staticTexts["large-markdown-end"]
        XCTAssertTrue(heading.waitForExistence(timeout: 15))
        XCTAssertLessThan(Date().timeIntervalSince(started), 15)

        XCTAssertTrue(app.links["OpenAI"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["quoted line one"].exists)
        XCTAssertTrue(app.staticTexts["let localOnly = true"].exists)
        XCTAssertTrue(app.scrollViews["Table, 2 rows, 2 columns"].exists)

        let copy = app.buttons["Copy answer"]
        XCTAssertTrue(copy.waitForExistence(timeout: 5))
        XCTAssertTrue(copy.isHittable)
        copy.tap()
    }
}

@MainActor
final class HarnessMobilePlanReviewUITests: XCTestCase {
    func testPlanReviewPresentsAllDesktopActions() {
        let app = XCUIApplication()
        addTeardownBlock {
            app.terminate()
        }
        app.launchArguments = [
            "-reset-persistent-state-for-ui-testing",
            "-bootstrap-configuration-for-ui-testing",
            "-disable-animations-for-ui-testing",
            "-present-plan-review-for-ui-testing",
        ]
        app.launch()

        openConversation(in: app)
        XCTAssertTrue(
            app.descendants(matching: .any)["plan-review-sheet"]
                .waitForExistence(timeout: 15)
        )
        XCTAssertTrue(app.buttons["plan-review-chat"].isHittable)
        XCTAssertTrue(app.buttons["plan-review-refuse"].isHittable)
        XCTAssertTrue(app.buttons["plan-review-approve"].isHittable)
        XCTAssertTrue(app.staticTexts["Plan review"].exists)
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "plan-review"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}

@MainActor
final class HarnessMobileISHTerminalUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testLocalTerminalExecutesStreamsAndStopsCommands() {
        let app = XCUIApplication()
        addTeardownBlock {
            app.terminate()
        }
        app.launchArguments = [
            "-reset-persistent-state-for-ui-testing",
            "-bootstrap-configuration-for-ui-testing",
            "-disable-animations-for-ui-testing",
        ]
        app.launch()

        openTerminal(in: app)

        let readyStatus = app.descendants(matching: .any)["ish-ready-status"]
        XCTAssertTrue(readyStatus.waitForExistence(timeout: 120))

        let networkToggle = app.switches["ish-network-toggle"]
        XCTAssertTrue(networkToggle.waitForExistence(timeout: 5))
        XCTAssertTrue(networkToggle.isHittable)
        setSwitch(networkToggle, enabled: true)
        setSwitch(networkToggle, enabled: false)

        run(command: "uname -m", in: app)
        let architectureOutput = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'arm64' OR label CONTAINS[c] 'aarch64'")
        ).firstMatch
        XCTAssertTrue(architectureOutput.waitForExistence(timeout: 30))

        run(command: "printf 'stdout-ok\\n'; printf 'stderr-ok\\n' >&2", in: app)
        XCTAssertTrue(app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "stdout-ok")
        ).firstMatch.waitForExistence(timeout: 30))
        XCTAssertTrue(app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "stderr-ok")
        ).firstMatch.waitForExistence(timeout: 30))

        let commandField = app.descendants(matching: .any)["ish-command-field"]
        commandField.tap()
        commandField.typeText("sleep 30")
        app.buttons["ish-run-command"].tap()
        let stopButton = app.buttons["ish-stop-command"]
        XCTAssertTrue(stopButton.waitForExistence(timeout: 5))
        stopButton.tap()
        XCTAssertTrue(app.staticTexts["Stopped"].waitForExistence(timeout: 15))
    }

    func testLiveMarketplaceEndpointsOnPhysicalDevice() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["HARNESS_RUN_LIVE_ISH_NETWORK_TEST"] == "1",
            "Set HARNESS_RUN_LIVE_ISH_NETWORK_TEST=1 for an explicit physical-device probe."
        )

        let app = XCUIApplication()
        addTeardownBlock {
            if app.state == .runningForeground {
                let networkToggle = app.switches["ish-network-toggle"]
                if networkToggle.exists, networkToggle.value as? String == "1" {
                    networkToggle.tap()
                }
            }
            app.terminate()
        }
        app.launchArguments = ["-disable-animations-for-ui-testing"]
        app.launch()

        openTerminal(in: app)

        XCTAssertTrue(
            app.descendants(matching: .any)["ish-ready-status"]
                .waitForExistence(timeout: 120)
        )
        let networkToggle = app.switches["ish-network-toggle"]
        XCTAssertTrue(networkToggle.waitForExistence(timeout: 5))
        setSwitch(networkToggle, enabled: true)

        run(
            command: Self.fetchProbeCommand(
                label: "RAW",
                url: "https://raw.githubusercontent.com/awesome-dsh-plugin/awesome-dsh-plugin/main/README.zh.md"
            ),
            in: app
        )
        XCTAssertTrue(
            output(containingAnyOf: ["RAW_STATUS=", "RAW_ERROR="], in: app)
                .waitForExistence(timeout: 45)
        )

        run(
            command: Self.fetchProbeCommand(
                label: "JSD",
                url: "https://cdn.jsdelivr.net/gh/awesome-dsh-plugin/awesome-dsh-plugin@main/README.zh.md"
            ),
            in: app
        )
        XCTAssertTrue(
            output(containingAnyOf: ["JSD_STATUS=200"], in: app)
                .waitForExistence(timeout: 45)
        )
        setSwitch(networkToggle, enabled: false)
    }

    private func run(command: String, in app: XCUIApplication) {
        let commandField = app.descendants(matching: .any)["ish-command-field"]
        XCTAssertTrue(commandField.waitForExistence(timeout: 5))
        commandField.tap()
        commandField.typeText(command)

        let runButton = app.buttons["ish-run-command"]
        XCTAssertTrue(runButton.isEnabled)
        runButton.tap()
    }

    private func setSwitch(_ toggle: XCUIElement, enabled: Bool) {
        let expectedValue = enabled ? "1" : "0"
        guard toggle.value as? String != expectedValue else { return }

        toggle.tap()

        let predicate = NSPredicate(format: "value == %@", expectedValue)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: toggle)
        XCTAssertEqual(
            XCTWaiter.wait(for: [expectation], timeout: 5),
            .completed,
            "Expected switch value to become \(expectedValue), got \(String(describing: toggle.value))"
        )
    }

    private static func fetchProbeCommand(label: String, url: String) -> String {
        "node -e \"fetch('\\(url)').then(r=>{console.log('\\(label)_STATUS='+r.status);process.exit(r.ok?0:1)}).catch(e=>{console.error('\\(label)_ERROR='+e.message);console.error('\\(label)_CAUSE='+(e.cause?.code||e.cause?.message||''));process.exit(1)})\""
    }

    private func output(containingAnyOf fragments: [String], in app: XCUIApplication) -> XCUIElement {
        let clauses = fragments.map { _ in "label CONTAINS %@" }.joined(separator: " OR ")
        return app.staticTexts.matching(
            NSPredicate(format: clauses, argumentArray: fragments)
        ).firstMatch
    }
}

@MainActor
final class HarnessMobilePluginManagementUITests: XCTestCase {
    func testCompilationFailureTraceExposesStagesLogsAndStructuredDiagnostic() {
        let app = XCUIApplication()
        addTeardownBlock {
            app.terminate()
        }
        app.launchArguments = [
            "-reset-persistent-state-for-ui-testing",
            "-bootstrap-configuration-for-ui-testing",
            "-disable-animations-for-ui-testing",
            "-present-plugin-compilation-failure-for-ui-testing",
        ]
        app.launch()

        XCTAssertTrue(app.navigationBars["Community plugins"].waitForExistence(timeout: 15))
        let trace = app.descendants(matching: .any)["community-plugin-compilation-summary"]
        XCTAssertTrue(trace.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Failed"].exists)
        XCTAssertFalse(app.staticTexts["Ended"].exists)
        XCTAssertTrue(app.staticTexts["Download source"].exists)
        let validation = app.staticTexts["Swift validation"]
        XCTAssertTrue(validation.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Reject unaudited web client contributions."].exists)
        let summaryScreen = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        summaryScreen.name = "plugin-compilation-failure-summary"
        summaryScreen.lifetime = .keepAlways
        add(summaryScreen)

        let logs = app.buttons["community-plugin-compilation-logs-toggle"]
        scrollUntilHittable(logs, in: app)
        XCTAssertTrue(logs.isHittable)
        logs.tap()
        let sourceSnapshotLog = app.staticTexts["The source snapshot is complete; credentials remain in the Keychain."]
        XCTAssertTrue(sourceSnapshotLog.waitForExistence(timeout: 5))
        let diagnosticTitle = app.staticTexts["Structured diagnostics · UNSUPPORTED_CLIENT_CONTRIBUTION"]
        scrollUntilExists(diagnosticTitle, in: app)
        // The iOS 26 bottom search glass counts as occlusion for hittability;
        // keep scrolling until the title clears it instead of stopping at the
        // first frame where it merely exists.
        scrollUntilHittable(diagnosticTitle, in: app)
        XCTAssertTrue(diagnosticTitle.exists)
        XCTAssertTrue(diagnosticTitle.isHittable)
        XCTAssertTrue(app.staticTexts["This plugin requests a web client slot; the phone does not load web or Swift code dynamically."].exists)
        XCTAssertTrue(app.staticTexts["example/unsupported-web-client"].exists)
        let detailsScreen = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        detailsScreen.name = "plugin-compilation-failure-details"
        detailsScreen.lifetime = .keepAlways
        add(detailsScreen)
    }

    func testCommunityMarketplaceUsesCompactSearchableList() {
        let app = XCUIApplication()
        addTeardownBlock {
            app.terminate()
        }
        app.launchArguments = [
            "-reset-persistent-state-for-ui-testing",
            "-bootstrap-configuration-for-ui-testing",
            "-disable-animations-for-ui-testing",
            "-present-plugin-market-for-ui-testing",
        ]
        app.launch()

        XCTAssertTrue(app.navigationBars["Community plugins"].waitForExistence(timeout: 15))

        let mode = app.segmentedControls["community-plugin-market-mode"]
        XCTAssertTrue(mode.waitForExistence(timeout: 5))
        XCTAssertTrue(mode.buttons["Marketplace"].isSelected)
        XCTAssertTrue(app.descendants(matching: .any)["community-plugin-market-summary"].exists)
        XCTAssertTrue(app.staticTexts["Git Tools"].exists)
        XCTAssertTrue(app.staticTexts["Memory Notes"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["community-plugin-market-error"].exists)

        let search = app.searchFields["Search plugins, categories or repositories"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("memory")
        XCTAssertTrue(app.staticTexts["Memory Notes"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Git Tools"].exists)

        mode.buttons["Installed"].tap()
        XCTAssertTrue(mode.buttons["Installed"].isSelected)
        XCTAssertTrue(app.staticTexts["Memory Notes"].waitForExistence(timeout: 5))

        let actions = app.buttons["community-plugin-market-actions"]
        XCTAssertTrue(actions.isHittable)
        actions.tap()
        XCTAssertTrue(app.buttons["Refresh catalog"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["GitHub repository"].exists)
        XCTAssertTrue(app.buttons["Import ZIP"].exists)
        XCTAssertTrue(app.buttons["Clear download cache"].exists)
    }

    func testGitHubInstallSheetKeepsRepositoryAndReplaceControlsClear() {
        let app = XCUIApplication()
        addTeardownBlock { app.terminate() }
        app.launchArguments = [
            "-reset-persistent-state-for-ui-testing",
            "-bootstrap-configuration-for-ui-testing",
            "-disable-animations-for-ui-testing",
            "-present-plugin-market-for-ui-testing",
        ]
        app.launch()

        XCTAssertTrue(app.navigationBars["Community plugins"].waitForExistence(timeout: 15))
        app.buttons["community-plugin-market-actions"].tap()
        let github = app.buttons["GitHub repository"]
        XCTAssertTrue(github.waitForExistence(timeout: 5))
        github.tap()

        XCTAssertTrue(app.navigationBars["Install repository"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields["https://github.com/owner/repository"].exists)
        XCTAssertTrue(app.switches["Overwrite plugin with the same name"].exists)
        XCTAssertTrue(app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Analyze the source on the device first")
        ).firstMatch.exists)
        XCTAssertTrue(app.buttons["Cancel"].exists)
        XCTAssertFalse(app.buttons["Install"].isEnabled)
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "plugin-github-install-sheet"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    func testCommunityPluginCatalogDetailKeepsSourceAndInstallBoundaryVisible() {
        let app = XCUIApplication()
        addTeardownBlock { app.terminate() }
        app.launchArguments = [
            "-reset-persistent-state-for-ui-testing",
            "-bootstrap-configuration-for-ui-testing",
            "-disable-animations-for-ui-testing",
            "-present-plugin-market-for-ui-testing",
        ]
        app.launch()

        XCTAssertTrue(app.navigationBars["Community plugins"].waitForExistence(timeout: 15))
        let plugin = app.staticTexts["Git Tools"]
        XCTAssertTrue(plugin.waitForExistence(timeout: 5))
        plugin.tap()

        XCTAssertTrue(app.navigationBars["Git Tools"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Name"].exists)
        XCTAssertTrue(app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS %@", "Tools and capabilities")
        ).firstMatch.exists)
        XCTAssertTrue(app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS %@", "Host compatible")
        ).firstMatch.exists)
        XCTAssertTrue(app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS %@", "Native preferred")
        ).firstMatch.exists)
        XCTAssertTrue(app.staticTexts["https://github.com/example/git-tools"].exists)
        XCTAssertTrue(app.buttons["Native-first install"].exists)
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "community-plugin-catalog-detail"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    func testInstalledPluginDetailKeepsRuntimeAndManagementClear() {
        let app = XCUIApplication()
        addTeardownBlock { app.terminate() }
        app.launchArguments = [
            "-reset-persistent-state-for-ui-testing",
            "-bootstrap-configuration-for-ui-testing",
            "-disable-animations-for-ui-testing",
            "-present-plugin-market-for-ui-testing",
        ]
        app.launch()

        XCTAssertTrue(app.navigationBars["Community plugins"].waitForExistence(timeout: 15))
        let mode = app.segmentedControls["community-plugin-market-mode"]
        XCTAssertTrue(mode.waitForExistence(timeout: 5))
        mode.buttons["Installed"].tap()
        let plugin = app.staticTexts["File Memory Native"]
        XCTAssertTrue(plugin.waitForExistence(timeout: 5))
        plugin.tap()

        XCTAssertTrue(app.navigationBars["File Memory Native"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Entries"].exists)
        XCTAssertFalse(app.staticTexts["Loader entries"].exists)
        XCTAssertTrue(app.switches["Enable plugin"].exists)
        XCTAssertTrue(app.buttons["Plugin settings"].exists)
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "installed-plugin-detail"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    func testNativeAgentPluginSettingsKeepsRuntimeAndValueControlsClear() {
        let app = XCUIApplication()
        addTeardownBlock { app.terminate() }
        app.launchArguments = [
            "-reset-persistent-state-for-ui-testing",
            "-bootstrap-configuration-for-ui-testing",
            "-disable-animations-for-ui-testing",
            "-present-plugin-market-for-ui-testing",
        ]
        app.launch()

        XCTAssertTrue(app.navigationBars["Community plugins"].waitForExistence(timeout: 15))
        let mode = app.segmentedControls["community-plugin-market-mode"]
        XCTAssertTrue(mode.waitForExistence(timeout: 5))
        mode.buttons["Installed"].tap()
        let plugin = app.staticTexts["File Memory Native"]
        XCTAssertTrue(plugin.waitForExistence(timeout: 5))
        plugin.tap()

        let settings = app.buttons["Plugin settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        settings.tap()
        XCTAssertTrue(app.navigationBars["File Memory Native"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["native-agent-settings-editor"].exists)
        XCTAssertTrue(app.staticTexts["Run mode"].exists)
        XCTAssertFalse(app.staticTexts["Plugin"].exists)
        XCTAssertTrue(app.staticTexts["Max recall characters"].exists)
        XCTAssertTrue(app.buttons["Restore all defaults"].exists)
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "native-agent-plugin-settings"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }


    func testSchedulePanelReachableFromSessionOptions() {
        let app = XCUIApplication()
        addTeardownBlock { app.terminate() }
        app.launchArguments = [
            "-reset-persistent-state-for-ui-testing",
            "-bootstrap-configuration-for-ui-testing",
            "-disable-animations-for-ui-testing",
        ]
        app.launch()

        openConversation(in: app)
        app.buttons["Session options"].tap()
        XCTAssertTrue(app.buttons["Scheduled reminders"].waitForExistence(timeout: 5))
        app.buttons["Scheduled reminders"].tap()

        XCTAssertTrue(app.navigationBars["Scheduled reminders"].waitForExistence(timeout: 5))
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "schedule-panel"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    // MARK: - Live smoke (simulator, real provider)

    /// Live-route configuration shared with the simulator through the host
    /// temp directory (simulators share the host filesystem, so a file beats
    /// environment variables that never reach the on-device test runner).
    private struct LiveRouteFile: Codable {
        let baseURL: String
        let model: String
        let apiKey: String
    }

    private func liveRouteConfig() -> LiveRouteFile? {
        // xcodebuild forwards host environment variables prefixed with
        // TEST_RUNNER_ to the on-device test runner.
        let environment = ProcessInfo.processInfo.environment
        let route = LiveRouteFile(
            baseURL: environment["UITEST_BASE_URL"] ?? "",
            model: environment["UITEST_MODEL"] ?? "",
            apiKey: environment["UITEST_API_KEY"] ?? ""
        )
        guard !route.apiKey.isEmpty else { return nil }
        return route
    }

    /// Full chat round trip through the configured route. Skips unless
    /// UITEST_API_KEY is set, so normal CI and local runs are unaffected.
    func testLiveChatRoundTripWhenExplicitlyEnabled() throws {
        guard let route = liveRouteConfig() else {
            throw XCTSkip("Export TEST_RUNNER_UITEST_API_KEY (optionally UITEST_BASE_URL/UITEST_MODEL) for the live smoke test.")
        }
        let apiKey = route.apiKey

        let app = XCUIApplication()
        addTeardownBlock { app.terminate() }
        app.launchArguments = [
            "-reset-persistent-state-for-ui-testing",
            "-bootstrap-configuration-for-ui-testing",
            "-disable-animations-for-ui-testing",
        ]
        app.launchEnvironment["UITEST_BASE_URL"] = route.baseURL
        app.launchEnvironment["UITEST_MODEL"] = route.model
        app.launchEnvironment["UITEST_API_KEY"] = apiKey
        app.launch()

        openConversation(in: app)

        let field = app.descendants(matching: .any)["chat-input"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap()
        field.typeText("Reply with exactly OK")

        app.buttons["chat-send-button"].tap()

        // The assistant reply must arrive through the live route within the
        // streaming budget.
        let reply = app.descendants(matching: .any)["message-assistant"].firstMatch
        XCTAssertTrue(reply.waitForExistence(timeout: 120))
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "live-chat-roundtrip"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    /// Native-first plugin install from the built-in community catalog. The
    /// marketplace compiler issues a real model call; the plugin must end up
    /// installed (native backend preferred, iSH fallback allowed).
    func testLiveNativePluginInstallWhenExplicitlyEnabled() throws {
        guard let route = liveRouteConfig() else {
            throw XCTSkip("Export TEST_RUNNER_UITEST_API_KEY (optionally UITEST_BASE_URL/UITEST_MODEL) for the live plugin install test.")
        }
        let apiKey = route.apiKey

        let app = XCUIApplication()
        addTeardownBlock { app.terminate() }
        app.launchArguments = [
            "-reset-persistent-state-for-ui-testing",
            "-bootstrap-configuration-for-ui-testing",
            "-disable-animations-for-ui-testing",
            "-present-plugin-market-for-ui-testing",
        ]
        app.launchEnvironment["UITEST_BASE_URL"] = route.baseURL
        app.launchEnvironment["UITEST_MODEL"] = route.model
        app.launchEnvironment["UITEST_API_KEY"] = apiKey
        app.launch()

        XCTAssertTrue(app.navigationBars["Community plugins"].waitForExistence(timeout: 15))
        // A fresh reset starts with an empty directory; the refresh control
        // repopulates it within a few seconds on a live network.
        let firstEntry = app.staticTexts["Git Tools"]
        if !firstEntry.waitForExistence(timeout: 10) {
            app.buttons["Refresh catalog"].firstMatch.tap()
        }
        XCTAssertTrue(firstEntry.waitForExistence(timeout: 20))
        // Git Tools starts uninstalled in a reset container, so this drives
        // the full native-compilation path end to end.
        XCTAssertTrue(app.staticTexts["Git Tools"].waitForExistence(timeout: 10))

        app.staticTexts["Git Tools"].tap()

        // The detail sheet gates the install behind a confirmation dialog;
        // the button label reflects the strategy (Native-first install / iSH Install).
        let install = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "Install")
        ).firstMatch
        XCTAssertTrue(install.waitForExistence(timeout: 10))
        install.tap()
        let confirm = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "Install")
        ).firstMatch
        if confirm.waitForExistence(timeout: 3) {
            confirm.tap()
        }

        // Compilation is a real model round trip; allow a generous budget.
        let installedLabel = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Installed")
        ).firstMatch
        let deadline = Date().addingTimeInterval(300)
        var sawInstalled = false
        while Date() < deadline {
            if installedLabel.exists {
                sawInstalled = true
                break
            }
            sleep(5)
        }
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "live-native-plugin-install"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        XCTAssertTrue(sawInstalled, "plugin did not reach installed state within 300s")
    }

    func testLiveMarketplaceCatalogRPCOnDevice() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["HARNESS_RUN_LIVE_ISH_NETWORK_TEST"] == "1",
            "Set HARNESS_RUN_LIVE_ISH_NETWORK_TEST=1 for an explicit on-device catalog probe."
        )

        let app = XCUIApplication()
        addTeardownBlock {
            app.terminate()
        }
        app.launchArguments = [
            "-reset-persistent-state-for-ui-testing",
            "-bootstrap-configuration-for-ui-testing",
            "-disable-animations-for-ui-testing",
        ]
        app.launch()

        XCTAssertTrue(app.navigationBars["Harness"].waitForExistence(timeout: 15))
        let toolsButton = app.buttons["Tool"]
        XCTAssertTrue(toolsButton.waitForExistence(timeout: 5))
        toolsButton.tap()

        let pluginsButton = app.buttons["tool-route-plugins"]
        XCTAssertTrue(pluginsButton.waitForExistence(timeout: 5))
        pluginsButton.tap()

        let marketplaceButton = app.buttons["community-plugin-market"]
        XCTAssertTrue(marketplaceButton.waitForExistence(timeout: 15))
        marketplaceButton.tap()
        XCTAssertTrue(app.navigationBars["Community plugins"].waitForExistence(timeout: 10))

        let status = app.descendants(matching: .any)["community-plugin-market-status"]
        _ = status.waitForExistence(timeout: 3)
        XCTAssertTrue(
            status.waitForNonExistence(timeout: 240),
            "The real market/catalog RPC did not finish."
        )
        XCTAssertFalse(
            app.descendants(matching: .any)["community-plugin-market-error"].exists,
            "The real market/catalog RPC surfaced an error."
        )
        XCTAssertTrue(
            app.staticTexts["Community catalog"].waitForExistence(timeout: 10),
            "The real market/catalog RPC returned no catalog rows."
        )
    }

    func testHostControlsAndJavaScriptEditorAreReachable() {
        let app = XCUIApplication()
        addTeardownBlock {
            app.terminate()
        }
        app.launchArguments = [
            "-reset-persistent-state-for-ui-testing",
            "-bootstrap-configuration-for-ui-testing",
            "-disable-animations-for-ui-testing",
        ]
        app.launch()

        XCTAssertTrue(app.navigationBars["Harness"].waitForExistence(timeout: 15))
        let toolsButton = app.buttons["Tool"]
        XCTAssertTrue(toolsButton.waitForExistence(timeout: 5))
        toolsButton.tap()
        XCTAssertTrue(app.navigationBars["Tool"].waitForExistence(timeout: 5))

        let pluginsButton = app.buttons["tool-route-plugins"]
        XCTAssertTrue(pluginsButton.waitForExistence(timeout: 5))
        pluginsButton.tap()

        XCTAssertTrue(app.descendants(matching: .any)["ish-plugin-host-status"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["plugin-runtime-summary"].exists)
        XCTAssertTrue(app.buttons["ish-plugin-host-start"].isEnabled)
        XCTAssertFalse(app.buttons["ish-plugin-host-refresh"].isEnabled)
        XCTAssertFalse(app.buttons["ish-plugin-host-stop"].isEnabled)

        let addPlugin = app.buttons["add-plugin-menu"]
        XCTAssertTrue(addPlugin.exists)
        addPlugin.tap()
        app.buttons["iSH JavaScript plugins"].tap()

        XCTAssertTrue(app.navigationBars["iSH plugins"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields["ish-plugin-name"].exists)
        XCTAssertTrue(app.textFields["ish-plugin-purpose"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["ish-plugin-host-code"].exists)
    }
}

@MainActor
private func openConversation(in app: XCUIApplication) {
    XCTAssertTrue(app.navigationBars["Harness"].waitForExistence(timeout: 15))

    let activeConversation = app.buttons.matching(
        NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "New session", "Current")
    ).firstMatch
    if activeConversation.waitForExistence(timeout: 3), activeConversation.isHittable {
        activeConversation.tap()
    } else {
        for _ in 0..<3 where !activeConversation.exists {
            app.swipeUp(velocity: .fast)
        }
        if activeConversation.waitForExistence(timeout: 2), activeConversation.isHittable {
            activeConversation.tap()
        } else {
            let newProject = app.buttons["New project"]
            XCTAssertTrue(newProject.waitForExistence(timeout: 5))
            newProject.tap()
        }
    }

    XCTAssertTrue(app.buttons["Session options"].waitForExistence(timeout: 15))
}

@MainActor
private func openTerminal(in app: XCUIApplication) {
    XCTAssertTrue(app.navigationBars["Harness"].waitForExistence(timeout: 15))
    let toolsButton = app.buttons["Tool"]
    XCTAssertTrue(toolsButton.waitForExistence(timeout: 5))
    toolsButton.tap()
    let terminalButton = app.descendants(matching: .any)["tool-route-terminal"]
    let scroller = app.collectionViews.firstMatch
    for _ in 0..<8 {
        if terminalButton.exists && terminalButton.isHittable {
            break
        }
        if scroller.exists {
            scroller.swipeUp(velocity: .fast)
        } else {
            app.swipeUp(velocity: .fast)
        }
    }
    XCTAssertTrue(terminalButton.waitForExistence(timeout: 5))
    XCTAssertTrue(terminalButton.isHittable)
    terminalButton.tap()
}

@MainActor
private func scrollUntilExists(_ element: XCUIElement, in app: XCUIApplication) {
    let scroller = app.collectionViews.firstMatch
    for _ in 0..<6 where !element.exists {
        scroller.swipeUp(velocity: .slow)
    }
}

@MainActor
private func scrollUntilHittable(_ element: XCUIElement, in app: XCUIApplication) {
    let scroller = app.collectionViews.firstMatch
    for _ in 0..<6 where !element.isHittable {
        scroller.swipeUp(velocity: .slow)
    }
}

@MainActor
private func scrollPluginMarketUntilHittable(_ element: XCUIElement, in app: XCUIApplication) {
    let scroller = app.tables.firstMatch.exists
        ? app.tables.firstMatch
        : app.collectionViews.firstMatch
    for _ in 0..<8 where !element.isHittable {
        scroller.swipeUp(velocity: .slow)
    }
}

@MainActor
private func scrollToTop(in app: XCUIApplication) {
    let scroller = app.collectionViews.firstMatch
    for _ in 0..<8 {
        scroller.swipeDown(velocity: .fast)
    }
}
