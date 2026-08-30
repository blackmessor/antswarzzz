# Antswarzzz — iOS Client Stack Proposal

> **Document type**: Technical stack recommendation for AI-assisted iOS development
> **Version**: 1.0 — August 2026
> **Game**: Antswarzzz — persistent ant colony strategy (see `specs/cahier_des_charges.md`)

---

## Table of Contents

1. [Game Engine / Framework](#1-game-engine--framework)
2. [Graphics Asset Pipeline & Tools](#2-graphics-asset-pipeline--tools)
3. [Development & CI Tools](#3-development--ci-tools)
4. [Project Structure & Dependency Management](#4-project-structure--dependency-management)

---

## 1. Game Engine / Framework

### Recommendation: SwiftUI + Combine (no game engine)

**Antswarzzz is not a game-engine game.** It has no physics, no real-time 3D rendering, no sprite collision, no frame-rate-dependent animation loop. It is a data-driven persistent strategy app whose UI is built from lists, grids, progress bars, timers, and forms — exactly the domain SwiftUI was designed for.

### Comparison

| Criterion | SwiftUI + Combine | SpriteKit | Unity |
|-----------|-------------------|-----------|-------|
| UI complexity (lists, forms, nav) | Native, first-class | Must be hand-built on top of SKScene | uGUI, usable but foreign on iOS |
| Data binding & state | @Published / @Observable | Manual polling | Manual or Unity-specific |
| Timer/background processing | Combine Timer + BGTaskScheduler | SKAction sequences | Coroutines + platform plugins |
| Testability of game logic | Pure Swift models testable with XCTest | Coupled to SKNode lifecycle | Coupled to MonoBehaviour |
| App Store size overhead | ~5-10 MB (no engine runtime) | Built into iOS (no overhead) | ~30-50 MB runtime |
| Swift interoperability | Native | Native (same language) | Via C# bridge, painful |
| Learning curve for AI tools | LLMs know SwiftUI extremely well | LLMs know SpriteKit well | LLMs know Unity C# but less iOS-specific |
| Future-proofing | Apple's primary UI framework | Maintained but secondary | Third-party, licensing risk |

### What about SpriteKit?

SpriteKit is the right tool when you need a 2D scene graph with physics bodies, collision detection, particle emitters, and frame-by-frame updates. Antswarzzz has none of these needs. The closest it gets to "graphics" are:

- Ant unit illustrations (static images)
- Building icons (static images)
- Resource bars (SwiftUI `ProgressView` or custom shapes)
- Breeding timer (SwiftUI text + `Timer.publish`)
- Colony view (a static or lightly-animated illustration, not an interactive scene)

If Phase 5 polish demands an animated isometric anthill view with ants walking through tunnels, SpriteKit can be embedded as a `SpriteView` inside a SwiftUI hierarchy for that one screen. The rest of the app stays SwiftUI. This is the standard hybrid pattern Apple recommends.

### Key frameworks within SwiftUI

| Framework | Purpose |
|-----------|---------|
| **SwiftUI** | All UI: dashboard, building list, breeding queue, research tree, combat results |
| **Combine** | Reactive pipelines: timer ticks, resource deltas, countdowns, state observation |
| **SwiftData** | Local persistence: colony state, ant inventory, building levels (replaces CoreData boilerplate) |
| **BGTaskScheduler** | Background tick processing when app is suspended |
| **UserNotifications** | Local notifications for completed builds, breed completions, attacks |
| **StoreKit 2** | In-app purchases (if monetized) |

### Architecture: MVVM with pure Engine layer

```
┌─────────────────────────────────────────┐
│ SwiftUI Views (stateless, declarative)  │
├─────────────────────────────────────────┤
│ ViewModels (@Published, Combine pipes)  │
├─────────────────────────────────────────┤
│ Engine (pure Swift, zero UI deps)       │
│ TickEngine, BreedingEngine, CombatEngine│
├─────────────────────────────────────────┤
│ Services (persistence, notifications)   │
├─────────────────────────────────────────┤
│ Models (Colony, Building, Ant, etc.)    │
└─────────────────────────────────────────┘
```

The Engine layer is the game's source of truth: it holds all state, applies all formulas from the spec, and exposes Combine publishers. Views never touch Engine directly — they read through ViewModels. This makes the entire game logic testable in XCTest without spinning up any UI.

---

## 2. Graphics Asset Pipeline & Tools

### Asset categories

| Category | Format | Count (est.) | Notes |
|----------|--------|-------------|-------|
| Ant portraits | PNG, @1x/@2x/@3x | 15 units | Static illustrations per ant type |
| Building icons | PNG + SF Symbols fallback | 13 buildings | Consistent icon style |
| Resource icons | SF Symbols primarily | 3-5 | Use `leaf.fill`, `cube.fill`, etc. |
| UI chrome | PDF vectors or PNG | ~20 elements | Buttons, panels, progress bars |
| Backgrounds | PNG, device-adaptive | 3-5 | Anthill interior, TDC surface, loading |
| Lottie animations | .json (Lottie) | 5-10 | Queen laying, ant marching, building sparkle |
| Sound effects | .caf / .m4a | ~15 | Building complete, combat, breeding done |

### Toolchain

```
Design (Figma)
  │
  ├─→ UI components → export as PDF/SVG
  │     └─→ Xcode Asset Catalog (preserve vector for scaling)
  │
  ├─→ Raster illustrations → export @1x/@2x/@3x PNG
  │     └─→ pngquant (lossy compression, ~70% size reduction)
  │     └─→ Xcode Asset Catalog
  │
  └─→ Animations → LottieFiles plugin → export .json
        └─→ Xcode bundle (loaded via Lottie-iOS at runtime)
```

### Asset management in Xcode

- Single `.xcassets` catalog with folders: `Ants/`, `Buildings/`, `UI/`, `Backgrounds/`
- Use **SF Symbols 6** for all standard icons (resources, navigation, actions) — free, Apple-designed, scales perfectly, zero asset maintenance
- Custom icons only where SF Symbols doesn't have a good match (building-specific icons, ant types)
- Lottie animations stored in a `.lottie` bundle or plain `.json` files in the app bundle

### Build-time optimization

- Xcode automatically compresses PNGs in the asset catalog (default `PNG` compression in build settings)
- For further reduction: `pngquant --quality=65-80` as a build script phase on custom raster assets
- App thinning: Xcode slices @1x/@2x/@3x per device automatically via asset catalog

### Recommended tools

| Tool | Purpose | Cost |
|------|---------|------|
| **Figma** | UI design, vector illustrations, asset export | Free tier sufficient |
| **SF Symbols** | System icons, included with Xcode | Free |
| **LottieFiles for Figma** | Export animations as Lottie JSON | Free |
| **pngquant** | PNG compression (build phase or manual) | Free (OSS) |
| **ImageOptim** | GUI batch PNG/JPEG optimization | Free (OSS) |

---

## 3. Development & CI Tools

### Development environment

| Tool | Version | Role |
|------|---------|------|
| **Xcode** | 16+ | IDE, compiler, simulator, profiling |
| **Swift** | 6.0 | Language (iOS 18+ deployment target) |
| **iOS SDK** | 18+ | Minimum deployment (covers ~90% of active devices by launch) |
| **macOS** | 15 Sequoia+ | Required for Xcode 16 (Apple Silicon strongly preferred) |
| **Git** | 2.x | Version control |

### Testing

| Tool | Scope |
|------|-------|
| **XCTest** | Unit tests for Engine layer (formulas, tick logic, combat resolution) |
| **XCTest + Combine** | Test publishers with `XCTestExpectation` for async tick processing |
| **XCUITest** | Smoke tests for critical flows (breed ant, build warehouse, complete research) — keep minimal, UI tests are brittle |
| **Swift Testing** (optional) | New Swift 6 testing framework with `#expect` macro — consider for new tests |

Testing strategy: >90% coverage on Engine layer (pure logic, no mocks needed). Light coverage on ViewModels. No coverage target on Views.

### Linting & formatting

| Tool | Config | Purpose |
|------|--------|---------|
| **SwiftLint** | `.swiftlint.yml` at project root | Enforce style rules, catch anti-patterns |
| **SwiftFormat** | `.swiftformat` at project root | Auto-format on build or pre-commit |
| **Periphery** | Run in CI | Detect unused code (dead types, functions, imports) |

Recommended SwiftLint rules beyond defaults:
- `force_unwrapping: error` (never force-unwrap; use guard-let)
- `closure_body_length: warning: 50`
- `file_length: warning: 400`

### CI / CD

**Recommendation: Xcode Cloud** (primary) with **GitHub Actions** as fallback.

| Capability | Xcode Cloud | GitHub Actions (macOS runner) |
|------------|-------------|-------------------------------|
| Build | Native, fast, parallel | Works, slower cold start |
| Test | Parallel simulator matrix | Simpler, single-device |
| Archive | One-click App Store Connect | Fastlane `build_app` |
| TestFlight | Built-in workflow | Fastlane `pilot` |
| Code signing | Automatic via App Store Connect API | Fastlane `match` |
| Cost | 25 compute hours/month free | 3× macOS minutes cost on paid plans |

**Xcode Cloud workflow** (`.ci/xcodecloud.yml`):
1. On push to `main` or PR: build + test
2. On tag `release/*`: archive → TestFlight → notify
3. Nightly: full test suite + Periphery scan

**Fastlane** for local scripting (not required on CI if using Xcode Cloud):
- `fastlane screenshots` — capture App Store screenshots
- `fastlane refresh_dsyms` — upload dSYMs to Crashlytics

### Crash reporting & analytics

| Tool | Purpose | Privacy note |
|------|---------|-------------|
| **Firebase Crashlytics** | Crash reporting, non-fatals | Disable automatic IP collection; use privacy manifest |
| **Firebase Analytics** | Light event tracking (building built, ant bred, combat won) | Opt-in IDFA only; minimal events |
| **MetricKit** | Battery, hang rate, disk writes (built-in, free) | Zero third-party, always on |

Crashlytics and Analytics come via the Firebase Apple SDK (SPM). Use the privacy manifests Apple requires — Firebase provides them.

### Push notifications

For multiplayer notifications (Phase 4): **Firebase Cloud Messaging (FCM)**. For single-player: **UserNotifications** framework for local notifications (building complete, breed cycle done).

---

## 4. Project Structure & Dependency Management

### Package manager: Swift Package Manager (SPM)

SPM is the only package manager that matters for modern iOS development. CocoaPods and Carthage are legacy and should not be introduced in a greenfield project.

### Dependencies

Keep the dependency tree shallow. Every dependency is a liability — it needs updates, can break on Xcode upgrades, and adds binary size.

**Core (non-negotiable):**

| Package | Version | Purpose | Why not alternative |
|---------|---------|---------|---------------------|
| `firebase-ios-sdk` (Crashlytics + Analytics) | Latest stable | Crashes and analytics | Industry standard, free |
| `lottie-ios` | Latest stable | Vector animations | AirBnB, 25k stars, trivially simple API |

**Optional / Phase-dependent:**

| Package | Phase | Purpose |
|---------|-------|---------|
| `firebase-ios-sdk` (Firestore) | Phase 4 | Multiplayer backend |
| `firebase-ios-sdk` (Cloud Messaging) | Phase 4 | Push for attacks/raids |

**Not needed:**
- No networking library (URLSession is sufficient for any REST calls)
- No reactive framework beyond Combine (built in)
- No image loading library (assets are bundled, not remote)
- No key-value store beyond SwiftData (built in)

### Project directory structure

```
Antswarzzz/
│
├── Antswarzzz.xcodeproj
├── Package.swift                      # SPM manifest (if using package-based setup)
│
├── App/
│   ├── AntswarzzzApp.swift            # @main, app lifecycle
│   ├── AppDelegate.swift              # Firebase configure, push registration
│   └── Info.plist                     # BGTaskScheduler identifiers, etc.
│
├── Models/                            # Pure data types, Codable, Identifiable
│   ├── Colony.swift
│   ├── Resources.swift
│   ├── Building.swift                 # + BuildingCategory enum
│   ├── AntType.swift                  # Static catalog of 15 types
│   ├── AntInstance.swift              # Runtime ant with HP, XP, location
│   ├── Research.swift                 # 10 tech definitions
│   ├── CombatResult.swift
│   └── BreedingQueue.swift
│
├── Engine/                            # Pure game logic — NO UIKit/SwiftUI imports
│   ├── TickEngine.swift               # 30-min resource loop (§6.1 of spec)
│   ├── BreedingEngine.swift           # Queue, speed bonuses, completion
│   ├── BuildingEngine.swift           # Prereqs, cost calc, timers
│   ├── ResearchEngine.swift           # Dependency graph, cost, timers
│   ├── CombatEngine.swift             # Deterministic round-by-round resolution
│   ├── EvolutionEngine.swift          # XP allocation, evolution thresholds
│   ├── HarvestEngine.swift            # Worker assignment, TDC caps, taxes
│   └── UpkeepEngine.swift             # Starvation, army food consumption
│
├── Services/                          # Side effects: disk, network, notifications
│   ├── PersistenceService.swift       # SwiftData stack (ModelContainer, ModelContext)
│   ├── TickSchedulerService.swift     # BGTaskScheduler registration + Timer.publish (foreground)
│   ├── NotificationService.swift      # Local + remote notification scheduling
│   └── AnalyticsService.swift         # Thin wrapper around Firebase Analytics
│
├── ViewModels/                        # @Observable classes, one per major screen
│   ├── DashboardViewModel.swift
│   ├── BuildingViewModel.swift
│   ├── BreedingViewModel.swift
│   ├── ResearchViewModel.swift
│   ├── CombatViewModel.swift
│   └── ColonyOverviewViewModel.swift
│
├── Views/                             # SwiftUI, organized by screen
│   ├── Dashboard/
│   │   ├── DashboardView.swift        # Main colony status screen
│   │   ├── ResourceBar.swift          # Food + materials display
│   │   └── ActiveTimersView.swift     # Construction, breeding countdowns
│   ├── Buildings/
│   │   ├── BuildingListView.swift
│   │   ├── BuildingDetailView.swift
│   │   └── BuildingRow.swift
│   ├── Breeding/
│   │   ├── BreedingView.swift
│   │   ├── BreedQueueView.swift
│   │   └── AntTypePicker.swift
│   ├── Research/
│   │   ├── ResearchTreeView.swift
│   │   └── ResearchDetailView.swift
│   ├── Combat/
│   │   ├── HuntView.swift
│   │   ├── AttackView.swift
│   │   └── CombatResultView.swift
│   ├── Components/                    # Reusable across screens
│   │   ├── TimerBadge.swift
│   │   ├── AntIcon.swift
│   │   ├── BuildingIcon.swift
│   │   ├── LevelIndicator.swift
│   │   └── ResourceDeltaAnimator.swift
│   └── Root/
│       ├── ContentView.swift          # TabView or NavigationSplitView root
│       └── LoadingView.swift
│
├── Extensions/                        # Swift extensions on standard types
│   ├── Int+Formatted.swift            # 1,234,567 formatting
│   ├── TimeInterval+Display.swift     # "3h 26m" display strings
│   └── Array+DeathOrder.swift         # Sort ants by death order (§4.3)
│
├── Resources/
│   ├── Assets.xcassets/               # Images, colors, app icon
│   │   ├── Ants/                      # 15 unit portraits @1x/@2x/@3x
│   │   ├── Buildings/                 # 13 building icons
│   │   ├── UI/                        # Custom chrome elements
│   │   ├── Backgrounds/               # Scene backgrounds
│   │   └── AppIcon.appiconset/
│   ├── Lottie/                        # .json animation files
│   │   ├── queen_laying.json
│   │   ├── ant_marching.json
│   │   ├── building_construct.json
│   │   └── combat_clash.json
│   ├── Sounds/                        # .caf audio files
│   │   ├── build_complete.caf
│   │   ├── breed_complete.caf
│   │   ├── combat_start.caf
│   │   └── research_done.caf
│   └── Localizable.xcstrings/         # String catalog (i18n-ready from day 1)
│
├── Tests/
│   ├── EngineTests/                   # Unit tests for pure game logic
│   │   ├── TickEngineTests.swift
│   │   ├── BreedingEngineTests.swift
│   │   ├── BuildingEngineTests.swift
│   │   ├── CombatEngineTests.swift
│   │   ├── EvolutionEngineTests.swift
│   │   └── SpecValidationTests.swift  # Verify formulas match spec
│   └── ModelTests/
│       ├── ResourcesTests.swift
│       ├── BuildingCostTests.swift
│       └── AntStatsTests.swift
│
├── UITests/                           # Smoke tests for critical flows
│   ├── BreedAntUITests.swift
│   └── BuildWarehouseUITests.swift
│
├── .swiftlint.yml
├── .swiftformat
└── .ci/
    └── xcodecloud.yml                 # CI workflow definition
```

### SwiftData persistence design

```swift
// Simplified schema — one @Model class per persistent entity
@Model final class PersistentColony {
    var food: Int
    var materials: Int
    var tdcSize: Double
    @Relationship(deleteRule: .cascade) var buildings: [PersistentBuilding]
    @Relationship(deleteRule: .cascade) var ants: [PersistentAntInstance]
    // ... lastTickTimestamp for catch-up on app launch
}
```

SwiftData is the right choice over CoreData for a greenfield iOS 18+ app:
- No `.xcdatamodeld` file — schema is code
- `@Model` macro auto-synthesizes Codable, Observable, and CloudKit sync support
- `ModelContext` replaces `NSManagedObjectContext` with async/await
- iCloud sync is a one-line opt-in (`NSPersistentCloudKitContainer` equivalent is automatic)

For multiplayer (Phase 4), the server becomes authoritative. At that point, SwiftData stores local cache only, and Firestore holds canonical state. The two are kept in sync via a `SyncService` that listens to Firestore snapshots and writes to SwiftData.

---

## Summary of decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| UI framework | SwiftUI (iOS 18+) | Data-driven UI, native, LLM-friendly |
| Reactive framework | Combine | Built-in, sufficient, no third-party |
| Game engine | None (optional SpriteKit for Phase 5 polish) | No physics/real-time rendering needed |
| Persistence | SwiftData | Modern, code-first, iCloud-ready |
| Package manager | SPM | Only first-class option for modern iOS |
| CI | Xcode Cloud | Zero-config iOS CI, free tier |
| Design tool | Figma (free tier) | Industry standard, Lottie export |
| Animations | Lottie (via lottie-ios) | Lightweight vectors, designer-friendly |
| Crash reporting | Firebase Crashlytics | Free, best-in-class |
| Architecture | MVVM + pure Engine | Testable logic, clean separation |
| Minimum iOS | 18.0 | Access to SwiftData, Swift 6, latest SwiftUI |
| Language | Swift 6 | Concurrency safety, Swift Testing support |
| Icons | SF Symbols 6 primary, custom where needed | Zero maintenance, perfect system fit |