<div align="center">

# Harness Mobile

**Bring DeepSeek Harness agent workflows to iPhone: inference uses your own model API, while tools, plugins, and commands run on-device by default.**

[![Platform](https://img.shields.io/badge/platform-iOS%2018%2B-000000?style=flat-square&logo=apple&logoColor=white)](#quick-start)
[![Swift](https://img.shields.io/badge/Swift-6.0-F05138?style=flat-square&logo=swift&logoColor=white)](#architecture)
[![UI](https://img.shields.io/badge/UI-SwiftUI-007AFF?style=flat-square)](#ui-and-workflows)
[![Execution](https://img.shields.io/badge/execution-on--device-21C55D?style=flat-square)](#on-device-execution-boundaries)
[![DeepSeek Harness](https://img.shields.io/badge/inspired%20by-DeepSeek%20Harness-4D6BFE?style=flat-square)](https://github.com/deepseek-ai/deepseek-harness)
[![License](https://img.shields.io/badge/license-GPL--3.0-blue?style=flat-square)](LICENSE)

`iOS` · `SwiftUI` · `DeepSeek` · `OpenAI-compatible` · `Anthropic` · `Cordis` · `iSH` · `OpenMinis` · `Agent`

</div>

> [!WARNING]
> This is an experimental project for personal Xcode sideloading and development debugging, not an App Store release. Use separate, quota-limited, revocable model API keys, and do not include keys, private logs, or workspace contents in Issues.

Harness Mobile is not a web wrapper, and it does not quietly forward commands to a server. It is a native SwiftUI agent client: model inference is performed through user-configured HTTPS APIs; the agent loop, file workspace, sessions, trajectories, iOS tools, Cordis host-half plugins, and Linux commands all run on the iPhone by default. The e2b, webhook, and ACP remote backends defined by D-011 must be explicitly configured and have visible status; they are currently still marked TODO/VERIFY in the capability catalog.

<p align="center">
  <img src="Docs/Evidence/home-projects-2026-09-01.png" width="31%" alt="Harness Mobile project-first home screen" />
  <img src="Docs/Evidence/archived-project-actions-2026-09-01.png" width="31%" alt="Harness Mobile project archive and restore" />
  <img src="Docs/Evidence/chat-attachments-2026-09-01.png" width="31%" alt="Harness Mobile chat attachments menu" />
</p>

<p align="center"><sub>Project-first home screen · Project archive/restore · Chat input focused on attachments (iOS 27.0 Simulator)</sub></p>

<p align="center">
  <img src="Docs/Evidence/trajectory-overview-2026-09-01.png" width="31%" alt="Harness Mobile agent trajectory overview" />
  <img src="Docs/Evidence/plugin-compilation-failure-2026-09-01.png" width="31%" alt="Harness Mobile plugin native compilation failure diagnostics" />
  <img src="Docs/Evidence/plugin-github-install-2026-09-01.png" width="31%" alt="Harness Mobile GitHub plugin repository install" />
</p>

<p align="center"><sub>Agent trajectory · Native plugin compilation diagnostics · GitHub repository installation boundaries (iOS 27.0 Simulator)</sub></p>

## Why build it

The core desktop Harness experience is not just a chat window. It is an observable agent loop formed by the model, tools, context, trajectories, workspace, and plugins together. Harness Mobile keeps that loop on the phone and reimplements it within iOS capability boundaries.

- **BYOK model layer**: DeepSeek, OpenAI-compatible, and Anthropic request adapters; model and API key can be selected per session.
- **On-device action layer**: Files, photo OCR, location, notifications, contacts, calendars, and more are handled by native tools; Linux commands run inside the embedded iSH ARM64 Alpine guest.
- **Evolvable Harness**: Supports Cordis host-half JavaScript packages, native client sidecars, dynamic tool/prompt contributions, lifecycle handling, settings, and traceable trajectories.
- **iPhone workflows**: Long-conversation virtualization, sessions/sub-agents, Live Activities, continued processing, and local diagnostic export after failures.

## Quick start

### 1. Prerequisites

- macOS + **Xcode Beta**
- An iOS 18+ device or an arm64 iOS Simulator
- A compatible model API (DeepSeek, OpenAI-compatible, or Anthropic)

### 2. Open and run

```sh
git clone https://github.com/liulingfei-1/deepseek-harness-ios.git
cd deepseek-harness-ios
open HarnessMobile.xcodeproj
```

In Xcode, choose a connected iPhone or an arm64 Simulator, then run `HarnessMobile`. On first launch, follow the setup flow and provide:

1. Provider / API Base URL
2. API Key (stored only in the local Keychain)
3. Model name
4. Thinking mode or the service default mode

### 3. Command-line build and test

The project is pinned to Xcode Beta. SwiftPM build caches must go under `/tmp`; do not create `.build` or `DerivedData` in the repository root.

```sh
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer   swift test --build-path /tmp/hm-build

DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer   xcodebuild -project HarnessMobile.xcodeproj   -scheme HarnessMobile   -sdk iphonesimulator   -destination 'generic/platform=iOS Simulator'   ARCHS=arm64 ONLY_ACTIVE_ARCH=YES build

./Scripts/audit-no-remote-execution.sh
./Scripts/check-upstream-parity.sh
```

`HarnessISH.xcframework` does not include an x86_64 slice, so Xcode builds must specify `ARCHS=arm64 ONLY_ACTIVE_ARCH=YES`.

## Capability overview

| Module | Current capabilities |
| --- | --- |
| Models and streaming | DeepSeek thinking / reasoning replay, OpenAI-compatible SSE, Anthropic Messages, automatic model discovery, image input, and provider-level retries |
| Agent loop | Multi-turn tool calling, cancel/resume, task status, plans, todos, context injection, sessions, and restricted local sub-agents |
| Workspace | App-private file workspace, read/write/edit/search, imported files/images, session file references, and trajectory links |
| Device tools | Camera/photo OCR, location, motion, notifications, authentication, contacts, calendars, reminders, voice, Bluetooth, and more iOS capability providers |
| Command sandbox | Embedded OpenMinis/iSH ARM64 Alpine, `shell_execute`, stdout/stderr, timeouts, cancellation, and guest network toggles |
| Plugins | Cordis host-half, marketplace/GitHub/ZIP installation, Node host inside iSH, dynamic tool/prompt contributions, hot settings updates, and start/stop/replace/rollback |
| Observability | Append-only trajectory, run/turn/step views, tool timing, diagnostic export, redacted logs, and plugin generations |
| iOS workflows | Native SwiftUI chat, long-session windowing, Live Activities, Continued Processing, completion notifications, and App Intents |

For the full list of tools, permissions, and platform limits, see the [mobile capability matrix](Docs/MOBILE_CAPABILITIES.md). For desktop/web comparisons and every remaining gap, see the [desktop parity checklist](Docs/DESKTOP_PARITY.md).

## UI and workflows

```text
Projects      Project-first home screen, search, create, archive, restore, rename, and fork
Chat          Conversations, attachments, @file/@session references, model and permissions, plan/agent mode
Tools         Workspace, iSH terminal, tasks/trajectory, plugins, and settings entry points
Workspace     Private file browsing, import, editing, and agent file tools
Console       Goals/plans/todos, jobs, trajectory, and diagnostics
Settings      Providers, background behavior, phone permissions, plugin marketplace, and plugin settings
```

There is currently no separate persisted Project model. The home screen uses session titles as project names to avoid maintaining two sources of truth at once; opening a project enters the corresponding conversation, while tools and diagnostics remain secondary entry points.

Tool cards have dedicated compact presentations, and long conversations plus streaming output use windowing/incremental rendering so the app does not recompute the entire history view at once. For every model or tool call, the trajectory stores input/output summaries, timing, turn data, cache/usage information, and the plugin processing chain; credential-shaped fields and contents are redacted before persistence.

## Architecture

```text
SwiftUI
  └─ AppModel (@MainActor)
      └─ AgentRuntime (actor)
          ├─ Provider adapters ── HTTPS ──> your model API
          ├─ LocalToolRegistry ────────────> native iOS tools
          ├─ HarnessISH ───────────────────> on-device iSH Alpine
          │                                  └─ Node.js / Cordis Host
          ├─ Workspace + Session + Trace ──> app-private storage
          └─ ActivityKit / notifications ──> iOS task projection
```

For more design trade-offs, see [Architecture and execution boundaries](Docs/ARCHITECTURE.md).

## On-device execution boundaries

Harness Mobile makes one explicit promise: **there is no remote command-execution fallback.**

| Can do | Will not do |
| --- | --- |
| Use your configured model API for inference | Forward shell / plugin commands to a project server |
| Run the Swift agent, native tools, and persistence inside the device process | Launch desktop host subprocesses or a server executor |
| Run Linux commands and host-half JS plugins inside the embedded iSH guest | Dynamically link downloaded Swift frameworks, native addons, or machine code |
| Pass OCR/file and other **approved text results** to the current model | Let the API key enter iSH, plugins, session snapshots, or diagnostic logs |

Model API keys live in the iOS Keychain; neither the plugin host nor iSH can access them. iOS system permissions (Photos, location, NFC, and so on) are still enforced by the system, and Harness permissions cannot bypass system prompts or foreground-interaction requirements.

## Plugins and extensions

Community plugin installation follows a **native-first → iSH host-half → explicit downgrade** path:

1. Source code comes from the marketplace, a GitHub repository/subdirectory, or a local ZIP.
2. Anything that can be mapped to native tool/prompt/native client sidecar capabilities is integrated into the Swift runtime first.
3. Remaining runnable Cordis host-half JavaScript packages run inside the phone's iSH Node host.
4. Browser client-half packages, React slots, native `.node` addons, or downloaded Swift/machine code do not have an equivalent runtime, so the app shows the reason instead of pretending installation succeeded.

Plugins can declare native inspectors, settings links, and slash commands; updates use generations, dispose, and rollback so a failed replacement does not take existing plugins down with it. For protocol and manifest examples, see [Native Client Plugins](Docs/NATIVE_CLIENT_PLUGINS.md); for iSH host details, see [Plugin Host](Docs/ISH_PLUGIN_HOST.md).

## Relationship to desktop Harness

This project is not an official DeepSeek Harness client, and it does not claim to reproduce the desktop web UI 1:1. It reuses, compares against, and continuously tracks upstream agent semantics while providing native iOS replacements.

- **Core paths already covered**: Providers, sessions, tool loop, workspace, trajectories, plans, image input, plugin host-half, jobs/restricted sub-agents, and on-device shell.
- **Still being filled in**: Full desktop information architecture, more workflow/worker contracts, desktop-grade skill registry, LSP, and persistent interactive PTY.
- **Intentionally not provided by default**: Remote executor, server tool fallbacks, arbitrary web/HTTP tools, and downloaded native code execution; e2b/webhook/ACP only advance as explicitly configured capabilities under D-011 and do not exist when unconfigured.

When upgrading from upstream, run `./Scripts/check-upstream-parity.sh` first, then update items one by one using the [upgrade guide](Docs/UPGRADING.md) and the [remediation log](Docs/DESKTOP_PARITY_REMEDIATION.md); do not claim compatibility just because package versions changed.

## Project structure

```text
HarnessMobile/
  App/                 AppModel, launch, lifecycle, agent entry
  Core/Agent/          Agent loop, context, compaction, sub-agents
  Core/Network/        Provider wire format, SSE, model discovery, and retries
  Core/Plugins/        Cordis, Native Agent, iSH host bridge
  Core/Tools/          Files, workspace, iOS capabilities, iSH commands
  Core/Storage/        Sessions, workspace, diagnostics, trajectories
  Features/            SwiftUI Chat / Files / Plugins / Trajectory
  Resources/PluginHost Node/Cordis host inside iSH and marketplace install pipeline
HarnessMobileTests/    XCTest, wire fixtures, Node smoke tests
Docs/                  Architecture, capabilities, compatibility, upgrades, and evidence
Vendor/                Pinned upstream/compatibility implementations and patches
```

`project.yml` is the XcodeGen source of truth for the project; the generated `HarnessMobile.xcodeproj` is also committed, so you can open the project directly in Xcode alone.

## Roadmap

- [x] BYOK providers, multi-protocol streaming, model discovery, and Keychain isolation
- [x] iSH on-device command sandbox and Cordis host-half
- [x] Workspace, file context, image input, trajectories, and diagnostic export
- [x] Community plugin marketplace, native sidecars, and installation/update/rollback infrastructure
- [x] Live Activities, continued processing, long-session rendering, and task recovery
- [ ] Complete remaining desktop web parity for workspace/jobs/inspect information architecture
- [ ] Expand workflow/worker support, skill registry, and more plugin protocol adapters
- [ ] Continuously validate real API, plugin, background, thermal, and memory-pressure scenarios on iPhone 16 Pro

Roadmap status is governed by the [desktop parity checklist](Docs/DESKTOP_PARITY.md) and the [remediation log](Docs/DESKTOP_PARITY_REMEDIATION.md).

## Contributing and feedback

Bug reports, compatibility evidence, plugin adaptations, and UI improvements are welcome. Before you start, please read:

- [CONTRIBUTING.md](CONTRIBUTING.md): build, test, commit, and acceptance rules
- [SECURITY.md](SECURITY.md): boundaries for reporting sensitive issues and credentials
- [AI Engineering Playbook](Docs/AI_ENGINEERING_PLAYBOOK.md): how to work in a large codebase with AI collaboration
- [Third-Party Notices](THIRD_PARTY_NOTICES.md): upstream sources, licenses, and distribution obligations

When filing an Issue, include a redacted `Harness-Diagnostics-*.log`, reproduction steps, device/OS version, chosen provider, and whether it happened after switching between foreground and background; **never attach API keys, Authorization headers, private file contents, or unredacted session exports.**

## License and acknowledgements

This project as a whole is licensed under the [GNU General Public License v3.0](LICENSE). It integrates and modifies GPLv3-licensed on-device iSH and OpenMinis components; iSH's additional distribution terms are in [LICENSES/ISH-LICENSE.IOS](LICENSES/ISH-LICENSE.IOS), and the full upstream notice is in [LICENSES/ISH-LICENSE.md](LICENSES/ISH-LICENSE.md). Before distributing source code or build artifacts, also read [Third-Party Notices](THIRD_PARTY_NOTICES.md) and fulfill the corresponding source-provision and notice obligations.

Special thanks to the open-source work behind [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness), [OpenMinis](https://github.com/OpenMinis/OpenMinis), and [iSH ARM64](https://github.com/OpenMinis/ish-arm64).
