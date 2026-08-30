# Antswarzzz — Server Architecture & Multiplayer Design

> **Project**: Antswarzzz iOS game — multiplayer server design
> **Date**: August 2026
> **Status**: Proposal

---

## Table of Contents

1. [Server Technology Choice](#1-server-technology-choice)
2. [Real-Time Protocol (WebSocket)](#2-real-time-protocol-websocket)
3. [Matchmaking Flow](#3-matchmaking-flow)
4. [State Synchronization Strategy](#4-state-synchronization-strategy)
5. [Docker & Docker Compose Integration](#5-docker--docker-compose-integration)
6. [Deployment Architecture Diagram](#6-deployment-architecture-diagram)
7. [Security & Anti-Cheat Considerations](#7-security--anti-cheat-considerations)

---

## 1. Server Technology Choice

### Recommendation: Go (Golang) — game server core

**Rationale:**

| Criterion | Go | Node.js | Vapor (Swift) |
|-----------|-----|---------|---------------|
| Tick engine throughput | Excellent — goroutines, native concurrency | Moderate — single event loop, worker threads needed | Good but smaller ecosystem |
| Memory footprint | Low (~15-50 MB) | Medium (~50-150 MB) | Medium-High |
| Deployment | Single static binary, no runtime | Needs Node runtime + node_modules | Needs Swift runtime on Linux |
| Docker image size | ~5 MB (scratch) | ~150 MB (alpine) | ~200 MB+ |
| Concurrency model | Goroutines (lightweight, M:N scheduling) | Async/await (single-threaded event loop) | SwiftNIO async/await |
| JSON/WebSocket perf | Excellent (std lib) | Good (ws, uWebSockets) | Good |
| Community & tooling | Mature, huge cloud-native ecosystem | Largest ecosystem | Small for server-side |
| iOS dev alignment | Neutral | Neutral | Same language as client |

**Why Go wins for this game:**

1. **Tick engine is the critical path.** Antswarzzz processes 48 ticks/day for every active player. At scale (10k+ players), that's 480k tick evaluations daily. Each tick evaluates harvesting, upkeep, construction timers, breeding, research, hunt/attack resolution, and colony tax. Go's goroutine-per-player model maps naturally — each colony runs its tick handler concurrently without blocking others.

2. **Deterministic combat is CPU-bound.** Combat resolution loops through up to 50 rounds of damage calculation for every PvP attack. Go's compiled performance handles this without the overhead of a JIT or interpreter.

3. **Single binary deployment.** A `go build` produces one static binary containing the entire server. Docker image from `scratch` is ~6 MB. No runtime, no package manager, no `node_modules`.

4. **Standard library covers 90% of needs.** `net/http` for REST, `gorilla/websocket` or `nhooyr.io/websocket` for WebSocket, `database/sql` with `go-sql-driver/mysql` for MariaDB, `encoding/json` for serialization. Minimal dependency tree.

5. **Graceful shutdown.** The tick engine needs to flush in-progress ticks before shutdown. Go's `context.Context` and `signal.NotifyContext` make this straightforward.

**Vapor (Swift) was considered** for sharing types between client and server, but the operational complexity (Swift on Linux Docker, larger images, smaller server ecosystem) outweighs the type-sharing benefit. Instead, we maintain a shared JSON schema contract — both sides validate against it.

### Architectural split

```
┌─────────────────────────────────────────────────┐
│                  Go Game Server                  │
│                                                  │
│  ┌──────────┐  ┌──────────┐  ┌───────────────┐  │
│  │ REST API │  │WebSocket │  │  Tick Engine   │  │
│  │  (:8080) │  │  (:8081) │  │  (internal)    │  │
│  └────┬─────┘  └────┬─────┘  └───────┬───────┘  │
│       │             │                │           │
│  ┌────┴─────────────┴────────────────┴───────┐   │
│  │              Game Logic Layer              │   │
│  │  (combat, economy, matchmaking, breeding)  │   │
│  └────────────────────┬──────────────────────┘   │
│                       │                          │
│  ┌────────────────────┴──────────────────────┐   │
│  │           Data Access Layer (SQL)          │   │
│  └────────────────────┬──────────────────────┘   │
└───────────────────────┼──────────────────────────┘
                        │
              ┌─────────┴─────────┐
              │     MariaDB       │
              │  (persistent)     │
              └───────────────────┘
              ┌─────────┴─────────┐
              │      Redis        │
              │  (cache/sessions) │
              └───────────────────┘
```

### Technology stack summary

| Component | Technology | Purpose |
|-----------|-----------|---------|
| Game server | Go 1.22+ | Tick engine, combat, matchmaking, API |
| Database | MariaDB 11.x | Persistent colony state, player accounts |
| Cache / pub-sub | Redis 7.x | Session state, matchmaking queues, hot data |
| Client protocol | WebSocket (JSON) | Real-time bidirectional communication |
| Container runtime | Docker + Docker Compose | Local dev and production deployment |
| Reverse proxy (prod) | Caddy or Nginx | TLS termination, rate limiting |

---

## 2. Real-Time Protocol (WebSocket)

### Why WebSocket over alternatives

| Protocol | Suitability | Verdict |
|----------|------------|---------|
| **WebSocket** | Bidirectional, persistent, low overhead after handshake. Native on iOS (`URLSessionWebSocketTask`). Perfect for push notifications (attack incoming, building complete) and live state sync. | **Use this** |
| HTTP polling | High overhead per request. 30-min tick doesn't need sub-second polling, but combat results and matchmaking need near-instant delivery. | Wasteful |
| gRPC streaming | Excellent performance but heavier iOS client setup. No native first-class iOS support without extra deps. | Overkill |
| Server-Sent Events | Unidirectional (server→client only). Can't send player actions. | Insufficient |
| UDP / custom | Not needed — Antswarzzz is not an action game requiring frame-perfect timing. | Unnecessary |

### WebSocket message protocol

All messages are JSON. Every message has a `type` field and a `payload`.

#### Client → Server messages

```json
// Authenticate
{"type": "auth", "payload": {"token": "jwt...", "player_id": "uuid"}}

// Request colony snapshot (full state)
{"type": "colony:get", "payload": {}}

// Assign workers to food/materials
{"type": "workers:assign", "payload": {"food": 120, "materials": 80}}

// Start building upgrade
{"type": "building:upgrade", "payload": {"building_id": "hatchery"}}

// Queue ant breeding
{"type": "breed:queue", "payload": {"ant_type_id": 1, "count": 10}}

// Start research
{"type": "research:start", "payload": {"tech_id": "tech_ponte"}}

// Initiate hunt (PvE)
{"type": "hunt:start", "payload": {"ant_ids": ["uuid1", "uuid2", ...]}}

// Search for PvP targets
{"type": "pvp:search", "payload": {}}

// Attack a specific player
{"type": "pvp:attack", "payload": {"target_player_id": "uuid", "ant_ids": ["uuid1", ...]}}

// Request matchmaking targets
{"type": "matchmaking:targets", "payload": {}}
```

#### Server → Client messages

```json
// Colony state snapshot (sent on connect + after each tick)
{"type": "colony:state", "payload": {"resources": {...}, "buildings": [...], "ants": [...], "research": [...], "tdc_size": 50}}

// Tick processed (incremental delta)
{"type": "tick", "payload": {"tick_id": 12345, "resources_delta": {"food": 120, "materials": 80}, "completed": {"building": "hatchery", "level": 5}}}

// Building completed
{"type": "building:completed", "payload": {"building_id": "hatchery", "new_level": 5}}

// Breed completed (batch)
{"type": "breed:completed", "payload": {"ants": [{"type_id": 1, "count": 10}]}}

// Research completed
{"type": "research:completed", "payload": {"tech_id": "tech_ponte", "new_level": 3}}

// Hunt result
{"type": "hunt:result", "payload": {"won": true, "tdc_gained": 12, "xp_gained": [...], "survivors": [...], "casualties": [...]}}

// PvP attack incoming alert
{"type": "pvp:incoming", "payload": {"attacker_name": "FourmiKing", "arrives_at": "2026-08-30T19:00:00Z"}}

// PvP attack result
{"type": "pvp:result", "payload": {"won": true, "tdc_gained": 35, "pillaged": {"food": 5000, "materials": 2000}, "survivors": [...], "casualties": [...]}}

// Matchmaking targets list
{"type": "matchmaking:targets", "payload": {"targets": [{"player_id": "uuid", "name": "...", "tdc_size": 120, "anthill_level": 45}]}}

// Error
{"type": "error", "payload": {"code": "INSUFFICIENT_RESOURCES", "message": "Not enough materials"}}

// Server heartbeat (keepalive)
{"type": "ping", "payload": {}}
```

### Connection lifecycle

```
iOS Client                          Go Server
    │                                    │
    │──── WS Connect (wss://) ──────────►│
    │◄─── Connection accepted ───────────│
    │──── auth {token} ─────────────────►│
    │◄─── colony:state (full snapshot) ──│  ← client renders UI
    │                                    │
    │  ... player actions via WS ...     │
    │                                    │
    │◄─── tick / event push ────────────│  ← every 30 min + real-time events
    │──── pong ─────────────────────────►│  ← keepalive every 30s
```

The WebSocket stays open for the entire session. On disconnect, the client reconnects with exponential backoff (1s, 2s, 4s, 8s, max 60s) and requests a fresh snapshot.

---

## 3. Matchmaking Flow

### Design goals

- Fair fights: players can only attack others within 50%–300% of their TDC size
- Fresh targets: results change as players grow
- No waiting: attacks are asynchronous (attacker sends army, result resolves after travel time)
- Anti-griefing: cooldowns prevent repeated attacks on the same target

### Target discovery

When a player opens the attack screen, the server generates a list of valid targets:

```
MATCHMAKING ALGORITHM:

Input:  player (tdc_size, anthill_level)
Output: list of 10–20 valid targets

1. Query MariaDB for players WHERE:
     - tdc_size BETWEEN player.tdc_size * 0.50 AND player.tdc_size * 3.00
     - player_id != requesting_player
     - last_attacked_by(player) > COOLDOWN (24h default)
     - player is not colonized_by requesting_player
     - player is active (logged in within 7 days)

2. Sort candidates by:
     - Primary: abs(tdc_size_difference) ASC  (closest TDC = fairest)
     - Secondary: anthill_level_difference ASC

3. Return top 20, with basic info:
     - player_id, display_name, tdc_size, anthill_level

4. Cache the target list in Redis (TTL: 5 min) so re-requests are fast.
```

### Attack flow

```
 Attacker                          Server                         Defender
    │                                 │                               │
    │── pvp:attack {target, ants} ──►│                               │
    │                                 │── validate:                   │
    │                                 │   - ants not busy             │
    │                                 │   - target in range           │
    │                                 │   - cooldown not active       │
    │                                 │── mark ants as "attacking"    │
    │◄── attack:started {eta} ───────│                               │
    │                                 │── pvp:incoming ──────────────►│
    │                                 │                               │
    │                                 │  ... travel time ...          │
    │                                 │  (based on distance,          │
    │                                 │   reduced by vitesse_attaque) │
    │                                 │                               │
    │                                 │── resolve_combat(             │
    │                                 │   attacker_ants,              │
    │                                 │   defender_tdc_army,          │
    │                                 │   location="tdc")             │
    │                                 │                               │
    │◄── pvp:result ─────────────────│                               │
    │◄── colony:state (updated) ─────│                               │
    │                                 │── pvp:result ────────────────►│
    │                                 │── colony:state (updated) ────►│
```

### Travel time formula

```
base_travel_seconds = 60 + (abs(attacker_tdc - defender_tdc) * 2)
  // Closer players = faster attacks
  // Base 60 seconds minimum, +2s per TDC cm² difference

effective_travel = base_travel * max(0.10, 1.0 - 0.10 * attacker.vitesse_attaque_level)
  // Vitesse d'Attaque research reduces travel time
  // Floor at 10% of base (level 9+)
```

### Cooldown system

```
Attack cooldown per target: 24 hours
  - Same attacker cannot hit the same defender again for 24h
  - Stored in Redis: "cooldown:{attacker_id}:{defender_id}" → TTL 86400s

Colonization lock: cannot attack a player you already colonize
  - You already collect tax from them; no double-dipping
```

### Edge cases

- **Target went offline mid-attack**: Combat still resolves (defending army is always present; TDC defense is automatic).
- **Target TDC changed before attack lands**: Use target state at attack launch time (snapshot).
- **Target under simultaneous attack**: Each attack resolves independently against the defender's army snapshot. If army A kills defenders, army B faces an empty defense (both win).
- **Attacker cancels**: Not allowed after launch — army is committed.

---

## 4. State Synchronization Strategy

### Authority model: server-authoritative

The server is the **single source of truth**. The client holds a **read-only cache** for display. Every state mutation goes through the server.

```
┌──────────────┐         ┌──────────────┐
│  iOS Client  │         │  Go Server   │
│              │         │              │
│  UI State    │  ◄───►  │  Game State  │──► MariaDB
│  (cache)     │  WS     │  (authority) │
│              │         │              │
│  Display     │         │  Validates   │
│  only —      │         │  all actions │
│  never       │         │              │
│  mutates     │         │              │
└──────────────┘         └──────────────┘
```

### Synchronization modes

#### Mode 1: Full snapshot (on connect / reconnect)

On WebSocket connect + auth, the server sends a complete `colony:state` message with every colony attribute. This is the canonical state. The client replaces its entire local cache.

**Size estimate:** A late-game colony with 500 buildings (13 types × levels), 10,000 ants, and 10 research trees serializes to roughly 50–100 KB JSON. At connection time this is acceptable. For bandwidth-constrained connections, we can compress with `permessage-deflate` (RFC 7692, built into most WebSocket libraries).

#### Mode 2: Incremental delta (after each tick)

Instead of re-sending the full state every 30 minutes, the server computes and sends only what changed:

```json
{
  "type": "tick",
  "payload": {
    "tick_id": 12345,
    "resources": {"food": 11420, "materials": 8340},
    "deltas": {
      "food": +120,
      "materials": +80,
      "upkeep_food": -45,
      "buildings_completed": [],
      "breeds_completed": [{"type_id": 1, "count": 3}],
      "research_progress": {"tech_ponte": {"timer_remaining": 5400}},
      "hunts_completed": [],
      "attacks_resolved": []
    }
  }
}
```

The client applies deltas to its local cache. If the client detects drift (e.g., resource totals don't match after applying delta), it requests a full snapshot.

#### Mode 3: Real-time event push

Instant notifications for events that don't wait for the tick:

- Incoming PvP attack alert
- Attack result (resolved mid-tick)
- Building/breed/research completion (when timer expires between ticks)

These are pushed immediately via the same WebSocket.

### Conflict resolution for player actions

When the player performs an action (assign workers, start build, etc.):

```
1. Client optimistically updates UI (shows button as "pressed," dims resources)
2. Client sends action via WebSocket
3. Server validates:
     - Does the player have enough resources?
     - Is the building prerequisite met?
     - Are the workers available (not already assigned)?
     - Is there already a construction in progress?
4a. If valid: server applies mutation, persists to MariaDB, broadcasts updated state
4b. If invalid: server sends error, client rolls back optimistic update
```

**Why not pure optimistic?** Resources are shared across concurrent actions. A player could queue a building and a research that both consume the same materials. Server-side validation is the only safe approach.

### Tick engine design

The tick engine runs on a **cron-like scheduler** inside the Go server. Every 30 minutes, it iterates all active colonies and processes the tick algorithm from the specification (§6.1).

```
TICK ENGINE DESIGN:

┌──────────────────────────────────────────┐
│            Tick Scheduler                │
│  time.Ticker(30 * time.Minute)           │
└────────────────┬─────────────────────────┘
                 │ fires every 30 min
                 ▼
┌──────────────────────────────────────────┐
│         Colony Fan-Out                   │
│  For each active colony (goroutine):     │
│    1. Acquire colony-level mutex         │
│    2. Execute tick algorithm             │
│    3. Compute delta from previous state  │
│    4. Persist to MariaDB                 │
│    5. Push delta to connected WS client  │
│    6. Release mutex                      │
└──────────────────────────────────────────┘

Performance: 10,000 colonies × ~2ms tick processing = 20 seconds.
With 50 goroutines processing in parallel: ~400ms wall time.
```

**Tick offset:** Colonies are sharded across the 30-minute window to avoid a thundering herd. Each colony gets a random offset (0–1799 seconds) assigned at creation — their tick fires at `next_tick = floor((now - offset) / 1800) * 1800 + offset`. This distributes the load evenly.

### Redis as hot cache

MariaDB is the durable store, but querying it for every tick is expensive. Redis sits in front for hot data:

```
WRITE PATH:  Game action → validate in Redis → persist to MariaDB → update Redis
READ PATH:   Client request → check Redis → miss? → load from MariaDB → cache in Redis

Redis data (per colony):
  - resources:{colony_id}  →  {"food": 12000, "materials": 5000}  (TTL: 1h, refreshed on tick)
  - colony:state:{colony_id}  →  full JSON snapshot  (TTL: 35 min, refreshed every tick)
  - session:{player_id}  →  WebSocket connection mapping
  - matchmaking:pool  →  sorted set of players for target discovery
```

---

## 5. Docker & Docker Compose Integration

### Service architecture

Three services in Docker Compose:

1. **mariadb** — persistent database
2. **redis** — cache and pub-sub
3. **antswarzzz-server** — Go game server

### Dockerfile (Go server)

```dockerfile
# ---- Build stage ----
FROM golang:1.22-alpine AS builder

RUN apk add --no-cache git ca-certificates

WORKDIR /build
COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /server ./cmd/server

# ---- Runtime stage ----
FROM scratch

COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /server /server

EXPOSE 8080 8081

ENTRYPOINT ["/server"]
```

Image size: ~6 MB.

### docker-compose.yml

```yaml
version: "3.9"

services:
  mariadb:
    image: mariadb:11.4
    container_name: antswarzzz-db
    restart: unless-stopped
    environment:
      MARIADB_ROOT_PASSWORD: ${MARIADB_ROOT_PASSWORD:-antswarzzz_dev}
      MARIADB_DATABASE: antswarzzz
      MARIADB_USER: antswarzzz
      MARIADB_PASSWORD: ${MARIADB_PASSWORD:-antswarzzz_dev}
    ports:
      - "3306:3306"
    volumes:
      - mariadb_data:/var/lib/mysql
      - ./db/init.sql:/docker-entrypoint-initdb.d/01-init.sql:ro
    healthcheck:
      test: ["CMD", "healthcheck.sh", "--connect", "--innodb_initialized"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    container_name: antswarzzz-redis
    restart: unless-stopped
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 3s
      retries: 5

  server:
    build: .
    container_name: antswarzzz-server
    restart: unless-stopped
    ports:
      - "8080:8080"   # REST API
      - "8081:8081"   # WebSocket
    environment:
      - DB_DSN=antswarzzz:${MARIADB_PASSWORD:-antswarzzz_dev}@tcp(mariadb:3306)/antswarzzz?parseTime=true
      - REDIS_ADDR=redis:6379
      - TICK_INTERVAL=1800
      - LOG_LEVEL=info
    depends_on:
      mariadb:
        condition: service_healthy
      redis:
        condition: service_healthy

volumes:
  mariadb_data:
  redis_data:
```

### Database initialization (db/init.sql)

```sql
-- Players table
CREATE TABLE IF NOT EXISTS players (
    id          CHAR(36) PRIMARY KEY,          -- UUID
    username    VARCHAR(32) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,        -- bcrypt
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_login  TIMESTAMP,
    last_tick   TIMESTAMP,                      -- last tick processed for this player
    tick_offset INT DEFAULT 0                   -- seconds offset within 30-min window
);

-- Colonies (one per player)
CREATE TABLE IF NOT EXISTS colonies (
    player_id           CHAR(36) PRIMARY KEY REFERENCES players(id),
    food                BIGINT NOT NULL DEFAULT 0,
    materials           BIGINT NOT NULL DEFAULT 0,
    tdc_size            DOUBLE NOT NULL DEFAULT 50.0,
    workers_on_food     INT NOT NULL DEFAULT 0,
    workers_on_materials INT NOT NULL DEFAULT 0,
    anthill_level       INT NOT NULL DEFAULT 0,
    colonized_by        CHAR(36) REFERENCES players(id),
    updated_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Buildings
CREATE TABLE IF NOT EXISTS buildings (
    id              BIGINT AUTO_INCREMENT PRIMARY KEY,
    player_id       CHAR(36) NOT NULL REFERENCES players(id),
    building_id     VARCHAR(32) NOT NULL,        -- 'hatchery', 'solarium', etc.
    level           INT NOT NULL DEFAULT 0,
    is_constructing BOOLEAN NOT NULL DEFAULT FALSE,
    timer_remaining INT NOT NULL DEFAULT 0,       -- seconds left, 0 = idle
    UNIQUE KEY uq_player_building (player_id, building_id)
);

-- Ants (one row per ant — for large colonies, batch into type+count or use summary)
-- Option A: individual rows (for XP tracking)
CREATE TABLE IF NOT EXISTS ants (
    id          CHAR(36) PRIMARY KEY,             -- UUID per ant
    player_id   CHAR(36) NOT NULL REFERENCES players(id),
    type_id     INT NOT NULL,                     -- 0-14 per roster
    current_hp  INT NOT NULL,
    max_hp      INT NOT NULL,
    xp          INT NOT NULL DEFAULT 0,
    location    ENUM('home', 'tdc', 'hunting', 'attacking') NOT NULL DEFAULT 'home',
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Option B: summary table (for scale — count by type)
CREATE TABLE IF NOT EXISTS ant_counts (
    player_id   CHAR(36) NOT NULL REFERENCES players(id),
    type_id     INT NOT NULL,
    count       INT NOT NULL DEFAULT 0,
    location    ENUM('home', 'tdc', 'hunting', 'attacking') NOT NULL DEFAULT 'home',
    PRIMARY KEY (player_id, type_id, location)
);

-- Research
CREATE TABLE IF NOT EXISTS research (
    player_id       CHAR(36) NOT NULL REFERENCES players(id),
    tech_id         VARCHAR(32) NOT NULL,
    level           INT NOT NULL DEFAULT 0,
    is_researching  BOOLEAN NOT NULL DEFAULT FALSE,
    timer_remaining INT NOT NULL DEFAULT 0,
    PRIMARY KEY (player_id, tech_id)
);

-- Breeding queue
CREATE TABLE IF NOT EXISTS breed_queue (
    player_id   CHAR(36) NOT NULL REFERENCES players(id),
    position    INT NOT NULL,                       -- queue order
    ant_type_id INT NOT NULL,
    count       INT NOT NULL,
    PRIMARY KEY (player_id, position)
);

-- Active breed (the one currently in progress)
CREATE TABLE IF NOT EXISTS active_breed (
    player_id       CHAR(36) PRIMARY KEY REFERENCES players(id),
    ant_type_id     INT NOT NULL,
    timer_remaining INT NOT NULL DEFAULT 0
);

-- PvP attack log
CREATE TABLE IF NOT EXISTS attacks (
    id              CHAR(36) PRIMARY KEY,
    attacker_id     CHAR(36) NOT NULL REFERENCES players(id),
    defender_id     CHAR(36) NOT NULL REFERENCES players(id),
    launched_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    arrives_at      TIMESTAMP NOT NULL,
    resolved_at     TIMESTAMP,
    result          ENUM('pending', 'attacker_wins', 'defender_wins') DEFAULT 'pending',
    tdc_gained      DOUBLE,
    food_pillaged   BIGINT,
    mat_pillaged    BIGINT
);

-- Indexes for matchmaking queries
CREATE INDEX idx_colonies_tdc ON colonies(tdc_size);
CREATE INDEX idx_colonies_anthill ON colonies(anthill_level);
CREATE INDEX idx_attacks_cooldown ON attacks(attacker_id, defender_id, resolved_at);
```

### .env file (development)

```bash
MARIADB_ROOT_PASSWORD=antswarzzz_dev_root
MARIADB_PASSWORD=antswarzzz_dev
```

### Startup commands

```bash
# First time
docker compose up -d mariadb redis    # start databases first
docker compose run --rm server --migrate  # run schema migrations
docker compose up -d                  # start everything

# Rebuild after code changes
docker compose build server
docker compose up -d server
```

---

## 6. Deployment Architecture Diagram

```
                        INTERNET
                           │
                    ┌──────┴──────┐
                    │   Caddy     │  (TLS termination, rate limiting)
                    │   :443      │
                    └──────┬──────┘
                           │
              ┌────────────┼────────────┐
              │            │            │
         wss://        https://        (health)
         :8081          :8080          checks
              │            │            │
    ┌─────────┴────────────┴────────────┴─────────┐
    │           Go Game Server (:8080, :8081)      │
    │                                               │
    │  ┌─────────────────────────────────────────┐  │
    │  │  Colony Handlers (goroutine per player)  │  │
    │  │  - Tick processing                       │  │
    │  │  - Combat resolution                     │  │
    │  │  - Matchmaking                           │  │
    │  └─────────────────────────────────────────┘  │
    │                                               │
    │  ┌──────────────┐    ┌──────────────────┐     │
    │  │  SQL Layer   │    │  Redis Layer     │     │
    │  └──────┬───────┘    └────────┬─────────┘     │
    └─────────┼─────────────────────┼───────────────┘
              │                     │
    ┌─────────┴─────────┐  ┌────────┴─────────┐
    │     MariaDB       │  │      Redis       │
    │  (persistent)     │  │  (cache/session) │
    │  Colony state     │  │  Hot data        │
    │  Player accounts  │  │  Matchmaking     │
    │  Attack logs      │  │  Cooldowns       │
    └───────────────────┘  └──────────────────┘
```

### Scaling path

For a single server (up to ~50k active players):

- 1 Go server instance handles all WebSocket connections
- MariaDB with proper indexing handles queries
- Redis reduces DB load for hot paths

For horizontal scaling (>50k players):

- Multiple Go server instances behind a load balancer
- MariaDB read replicas for matchmaking queries
- Redis Cluster for cache distribution
- Consistent hashing by player_id to pin players to specific server instances (avoids cross-server WebSocket routing)

---

## 7. Security & Anti-Cheat Considerations

### Authentication

- JWT tokens issued on login (email/password or Sign in with Apple)
- Tokens expire after 7 days, refreshable
- WebSocket auth: client sends token as first message after connect

### Anti-cheat principles

Since the server is fully authoritative, most cheat vectors are eliminated:

1. **Resource injection impossible** — all resource math runs server-side
2. **Speed hacking irrelevant** — tick engine runs on server clock, not client
3. **Combat manipulation impossible** — combat resolution is server-side only
4. **Building/buying with insufficient funds** — validated server-side before any mutation

Remaining attack surface:

| Vector | Mitigation |
|--------|-----------|
| Replay attacks | Each action message includes a monotonically increasing `seq` number; server rejects out-of-order or duplicate seqs |
| Credential stuffing | Rate-limit login attempts (5/min per IP) |
| WebSocket flood | Per-connection message rate limit (30 msg/sec) |
| SQL injection | Parameterized queries only (Go `database/sql` enforces this) |
| Timing attacks on matchmaking | Randomize response order slightly; no timing signal leaks |

### Data validation

All client messages are validated against JSON schemas before processing. The server rejects any message with unexpected fields or invalid value ranges (e.g., negative resources, ant_type_id > 14).

---

## Summary

| Decision | Choice | Key reason |
|----------|--------|-----------|
| Language | **Go 1.22+** | Goroutines for parallel tick processing, single binary, 6 MB Docker image |
| Protocol | **WebSocket (JSON)** | Bidirectional, native iOS support, perfect for push + request/response |
| Database | **MariaDB 11.x** | Already available, proven for persistent relational state |
| Cache | **Redis 7.x** | Hot colony state, matchmaking pools, cooldowns |
| Matchmaking | **TDC range 50%–300%** | Per spec, closest TDC first, 24h cooldown per target |
| State sync | **Server-authoritative + delta push** | Full snapshot on connect, incremental on tick |
| Deployment | **Docker Compose (3 services)** | mariadb + redis + go-server, single `docker compose up` |
| Tick distribution | **Per-colony random offset** | Avoids thundering herd on the hour |

All design decisions are grounded in the Antswarzzz game specification (cahier_des_charges.md). The architecture prioritizes operational simplicity (few moving parts), correctness (server-authoritative), and the existing constraint of Docker + MariaDB availability.