# Antswarzzz — Complete Technical Stack Proposal

> **Project**: Antswarzzz — persistent ant colony strategy game for iOS
> **Date**: August 2026
> **Status**: Final proposal — ready for implementation
> **Based on**: Cahier des charges v1.0 (specs/cahier_des_charges.md)

---

## Executive Summary

Antswarzzz is a data-driven persistent strategy game where players manage an ant colony across 30-minute ticks. Resources tick automatically, buildings and research timers count down, and armies fight in deterministic combat rounds. There is no real-time rendering, no physics, and no frame-rate-dependent loop — this is a UI-heavy strategy app, not an action game.

The proposed stack is deliberately lean: **SwiftUI + Combine** on iOS with no game engine (pure MVVM architecture), a **Go game server** handling ticks and multiplayer via WebSocket, **MariaDB** for persistent state with a 18-table normalized schema, and **Redis** as a hot cache. Everything orchestrates under **Docker Compose** with 3 services. The entire stack can be developed with free tools (Figma, Xcode Cloud, SF Symbols) and deployed on a single VPS for up to ~50k active players.

---

## Architecture Overview

```
┌──────────────────────────────────────────────────────────────────┐
│                         iOS CLIENT                                │
│                                                                    │
│  SwiftUI Views (stateless, declarative)                            │
│       │                                                            │
│  ViewModels (@Published, Combine pipes)                            │
│       │                                                            │
│  Engine Layer (pure Swift, zero UI deps)                           │
│  TickEngine ─ BreedingEngine ─ BuildingEngine ─ CombatEngine       │
│  ResearchEngine ─ EvolutionEngine ─ HarvestEngine ─ UpkeepEngine   │
│       │                                                            │
│  Services: SwiftData (local cache) ─ Notifications ─ Analytics     │
│       │                                                            │
│  Models: Colony, Building, AntType, Research, CombatResult, ...    │
│       │                                                            │
│       │  URLSessionWebSocketTask (wss://)                          │
│       │  + REST (https://) for auth                                │
└───────┼────────────────────────────────────────────────────────────┘
        │
        ▼
┌──────────────────────────────────────────────────────────────────┐
│                        INTERNET                                    │
│                    Caddy (TLS, rate limit)                         │
└──────────────────────────────────────────────────────────────────┘
        │
        ▼
┌──────────────────────────────────────────────────────────────────┐
│                     GO GAME SERVER                                 │
│                                                                    │
│  ┌──────────┐  ┌───────────┐  ┌────────────────────────────────┐  │
│  │ REST API │  │ WebSocket │  │       Tick Engine               │  │
│  │  :8080   │  │  :8081    │  │  per-colony goroutine           │  │
│  │          │  │  JSON     │  │  30-min tick w/ random offset   │  │
│  └────┬─────┘  └─────┬─────┘  └──────────────┬─────────────────┘  │
│       │              │                        │                    │
│  ┌────┴──────────────┴────────────────────────┴────────────────┐  │
│  │                   Game Logic Layer                           │  │
│  │  Combat (50-round deterministic) ─ Economy (harvest/upkeep) │  │
│  │  Matchmaking (TDC 50%-300%) ─ Breeding (queue + timer)     │  │
│  │  Evolution (XP pool) ─ Colonization (vassal tax)           │  │
│  └───────────────────────────┬─────────────────────────────────┘  │
│                              │                                     │
│  ┌───────────────────────────┴─────────────────────────────────┐  │
│  │  Data Access Layer (SQL, parameterized queries)              │  │
│  └───────────────────────────┬─────────────────────────────────┘  │
└──────────────────────────────┼────────────────────────────────────┘
                               │
                 ┌─────────────┴─────────────┐
                 │                           │
    ┌────────────┴──────────┐   ┌────────────┴──────────┐
    │      MariaDB 11.4     │   │       Redis 7.x       │
    │   (persistent state)  │   │   (hot cache / pub)   │
    │                       │   │                       │
    │  18 tables            │   │  colony:state:{id}    │
    │  15 ant types seeded  │   │  resources:{id}       │
    │  13 building types    │   │  matchmaking:pool     │
    │  10 research types    │   │  cooldown:{a}:{d}     │
    │  BIGINT for resources │   │  session:{player_id}  │
    └───────────────────────┘   └───────────────────────┘
```

### Data Flow Summary

| Direction | Protocol | When | What |
|-----------|----------|------|------|
| Server → Client | WebSocket push | On connect | Full colony snapshot (50-100 KB JSON) |
| Server → Client | WebSocket push | Every 30-min tick | Incremental delta (resources, timers, completed items) |
| Server → Client | WebSocket push | Real-time events | Attack alerts, combat results |
| Client → Server | WebSocket send | Player actions | Assign workers, queue breed, start research, launch attack |
| Client → Server | REST POST | Auth only | Login/register, token refresh |

---

## Consolidated Autonomy Checklist

Everything needed to develop and deploy Antswarzzz independently, organized by layer.

### 1. Infrastructure & Hosting

| Item | Specific Version | Purpose | Acquisition |
|------|-----------------|---------|-------------|
| **Docker** | 24+ (Docker Engine + Compose v2) | Container orchestration for all services | Already available |
| **VPS or local machine** | 2+ vCPU, 4 GB RAM, 20 GB SSD | Run the Docker Compose stack | VPS (~$10-20/mo) or local Mac/Linux |
| **Domain name** | Optional | TLS certificate for production WebSocket (wss://) | Any registrar |
| **Caddy** or **Nginx** | Latest stable | Reverse proxy: TLS termination, rate limiting, WebSocket upgrade | Docker image or system package |

### 2. Server Stack (3 Docker services)

| Service | Image | Version | Port | Role |
|---------|-------|---------|------|------|
| **Go Game Server** | Custom `Dockerfile` (multi-stage, ~6 MB scratch image) | Go 1.22+ | 8080 (REST), 8081 (WS) | Tick engine, combat, matchmaking, WebSocket hub |
| **MariaDB** | `mariadb:11.4` | 11.4+ | 3306 | Persistent colony/player state, 18 tables |
| **Redis** | `redis:7-alpine` | 7.x | 6379 | Hot cache, session tracking, cooldowns, matchmaking pool |

### 3. Database Setup

| Item | Details |
|------|---------|
| **Schema** | 18 tables: players, colonies, colony_resources, ant_types, building_types, research_types, colony_buildings, colony_research, colony_ants, breed_queue, active_breed, hunts, hunt_armies, attacks, attack_armies, combat_logs, colonizations, colony_events |
| **Init script** | `init.sql` (338 lines) — creates all tables with constraints and seeds 15 ant types, 13 building types, 10 research types |
| **Charset** | `utf8mb4_unicode_ci` |
| **Key design** | Aggregated ant storage (by type+location), BIGINT for resources (~10^18), JSON for combat loss logs, separate colony_resources for hot path |

### 4. iOS Client Stack

| Category | Tool / Framework | Version | Purpose |
|----------|-----------------|---------|---------|
| **Language** | Swift | 6.0 | Primary development language |
| **UI Framework** | SwiftUI | iOS 18+ | All screens: dashboard, buildings, breeding, research, combat |
| **Reactive** | Combine | Built-in | Timer ticks, resource deltas, countdowns, state observation |
| **Local Persistence** | SwiftData | Built-in | Offline colony cache (CloudKit sync ready) |
| **Package Manager** | Swift Package Manager (SPM) | Built-in | All dependencies |
| **IDE** | Xcode | 16+ | Development, compilation, simulator, profiling |
| **CI/CD** | Xcode Cloud | Free tier (25h/mo) | Build, test, archive, TestFlight deploy |
| **Linting** | SwiftLint | Latest | Code style enforcement |
| **Formatting** | SwiftFormat | Latest | Auto-format on build |

### 5. Client Dependencies (SPM)

| Package | When | Purpose |
|---------|------|---------|
| `firebase-ios-sdk` (Crashlytics + Analytics) | Day 1 | Crash reporting, light analytics |
| `lottie-ios` | Day 1 | Vector animations (queen laying, ant marching, combat) |
| `firebase-ios-sdk` (Cloud Messaging) | Phase 4 | Push notifications for attacks |
| `firebase-ios-sdk` (Firestore) | Phase 4 | Multiplayer backend (optional, if not using Go server) |

### 6. Graphics & Asset Tools

| Tool | Purpose | Cost |
|------|---------|------|
| **Figma** (free tier) | UI design, vector illustrations, asset export | Free |
| **SF Symbols 6** | System icons (resources, navigation, actions) — included with Xcode | Free |
| **LottieFiles for Figma** | Export animations as Lottie JSON | Free |
| **pngquant** | PNG compression (build phase script) | Free (OSS) |
| **ImageOptim** | GUI batch PNG/JPEG optimization | Free (OSS) |

### 7. Testing & Quality

| Tool | Scope |
|------|-------|
| **XCTest** | Unit tests for Engine layer (>90% coverage target) |
| **XCTest + Combine** | Async pipeline testing with XCTestExpectation |
| **XCUITest** | Critical flow smoke tests (breed, build, combat) — minimal |
| **Swift Testing** (optional) | New Swift 6 testing framework with `#expect` macro |
| **Periphery** | Detect unused code in CI |
| **Go testing** (`go test`) | Server-side unit + integration tests |
| **Docker health checks** | MariaDB + Redis uptime monitoring |

### 8. Monitoring & Analytics

| Tool | Layer | Purpose |
|------|-------|---------|
| **Firebase Crashlytics** | iOS | Crash reporting, non-fatal errors |
| **Firebase Analytics** | iOS | Light event tracking (builds, breeds, combats) |
| **MetricKit** | iOS (built-in) | Battery, hang rate, disk writes |
| **Server logs** (structured JSON) | Go server | Request logs, tick performance, errors |
| **colony_events table** | MariaDB | Audit log: builds, research, combat, evolution |

### 9. One-Command Startup

```bash
# Clone and start everything
git clone <repo-url> antswarzzz && cd antswarzzz
docker compose up -d
```

**What this does:**
1. Pulls `mariadb:11.4` and `redis:7-alpine` images
2. Builds the Go server from the Dockerfile (~6 MB image)
3. Mounts `init.sql` to auto-create the schema + seed data on first run
4. MariaDB available on :3306, Redis on :6379, server on :8080/:8081
5. Health checks ensure DB and Redis are ready before the server starts

**To reset:**
```bash
docker compose down -v && docker compose up -d
```

### 10. Development Workflow

```bash
# iOS (on macOS with Xcode 16+)
open Antswarzzz.xcodeproj     # Open in Xcode
⌘R                             # Build & run on simulator

# Server (local dev)
docker compose up -d mariadb redis    # Start databases
cd server && go run ./cmd/server       # Run server directly (hot reload)
# or
docker compose up -d                   # Everything in Docker

# Rebuild server after changes
docker compose build server && docker compose up -d server
```

---

## Key Technical Decisions

### Why SwiftUI + Combine (no game engine)?
Antswarzzz has no physics, no 3D rendering, no sprite collision, no frame-rate loop. Its UI is lists, grids, progress bars, timers, and forms — SwiftUI's exact domain. The Engine layer (TickEngine, CombatEngine, etc.) is pure Swift with zero UI imports, making it fully testable with XCTest. If Phase 5 polish demands an animated isometric anthill, SpriteKit can be embedded as a `SpriteView` inside SwiftUI for that one screen.

### Why Go for the server?
The critical path is parallel tick processing (480k evaluations/day at 10k players). Go's goroutines map naturally to per-colony tick handlers. Single static binary, 6 MB Docker image from scratch, no runtime. The standard library covers HTTP, WebSocket (via `gorilla/websocket` or `nhooyr.io/websocket`), JSON, and SQL.

### Why aggregated ant storage?
A colony can have thousands of military ants. Individual rows mean 10,000+ updates per combat tick. Aggregating by `(colony_id, ant_type_id, location)` bounds per-colony queries to ~60 rows regardless of army size. Evolution uses cumulative XP pool: `floor(cumulative_xp / threshold)` units evolve in one update.

### Why BIGINT for resources?
Warehouse capacity at level 50 reaches ~1.35 × 10^18. INT (2.1 billion) overflows at level ~21. BIGINT handles level 50+ without risk.

### Why server-authoritative state sync?
All resource math, combat resolution, and timer processing run server-side. The iOS client holds a read-only cache. This eliminates resource injection, speed hacking, and combat manipulation as cheat vectors.

---

## Scaling Path

| Player Count | Architecture |
|-------------|-------------|
| < 1,000 | Single VPS, all 3 services on one machine |
| 1,000 – 50,000 | Single Go server instance, MariaDB with proper indexing, Redis cache |
| > 50,000 | Multiple Go instances behind load balancer, MariaDB read replicas, Redis Cluster, consistent hashing by player_id |

---

## Document Map

This README synthesizes three detailed proposals. For full rationale, data tables, formulas, and code samples:

| Document | Contents |
|----------|----------|
| [database.md](./database.md) | Complete 18-table MariaDB schema, entity relationships, Docker Compose snippet with health checks, design rationale (BIGINT, JSON logs, aggregated ants) |
| [server-multiplayer.md](./server-multiplayer.md) | Go server architecture, WebSocket JSON protocol (20 message types), TDC-range matchmaking algorithm, state synchronization (full snapshot + incremental delta), tick engine design with random offsets, security & anti-cheat, scaling path, Docker Compose with 3 services |
| [client-tools.md](./client-tools.md) | iOS framework comparison (SwiftUI vs SpriteKit vs Unity), graphics asset pipeline (Figma → xcassets + Lottie), CI/CD (Xcode Cloud), project structure (MVVM + pure Engine), SPM dependencies, SwiftData persistence design |
| [init.sql](./init.sql) | Full DDL + seed data: 15 ant types with stats, 13 buildings with cost/time scaling, 10 research types with prerequisites |

---

*Stack proposal v1.0. All decisions grounded in `specs/cahier_des_charges.md` (974 lines, 30.6 KB). Ready for Phase 1: Core Loop (MVP) implementation.*