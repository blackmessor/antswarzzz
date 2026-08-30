# Antswarzzz — Phase 1 Summary

> **Completed**: 30 August 2026
> **Status**: ✅ Done — server running on localhost:8080

## What Phase 1 Delivers (Core Loop MVP)

### Server (Go)
- **Tick engine**: processes all colonies every 30 minutes
  - Resource harvesting (food + materials per worker)
  - Mushroom farm passive food production (formula: `floor(122 * 1.70^(level-1))` per day, divided into 48 ticks)
  - Construction timer countdown
  - 50 concurrent colony goroutines max
  - `POST /api/tick` for manual/forced tick

- **REST API**:
  - `GET /health` — server status
  - `POST /api/player/register` — creates player + colony + 5 workers + 4 buildings (level 0)
  - `GET /api/colony/{id}` — full colony state (resources, buildings, ants)
  - `POST /api/colony/{id}` — actions: `assign_workers`

- **Database**: MariaDB 12.3, 18 tables seeded
  - 15 ant types (ouvrière, JSN, SN, NE, JS, S, SE, C, CE, A, AE, Tk, TkE, Tu, TuE)
  - 13 building types with cost/time formulas per category (A/B/C/D)
  - 10 research types with prerequisites
  - Static data seeded, mutable tables ready for Phase 2+

- **Building cost formulas implemented**:
  - Category A: `cost × 2^(level-1)`
  - Category B (mushroom): `cost × 1.85^(level-1)`, production `122 × 1.70^(level-1)`
  - Category D (warehouse): capacity `1700 + 1200 × (2^level - 1)`, cost `600 × 2^(level-1)`, time `180 × 1.6^(level-1)`

- **Infrastructure**:
  - `docker-compose.yml` with 3 services (MariaDB + Redis + Go server)
  - `Dockerfile` multi-stage (~6 MB scratch image)
  - `go.mod` / `go.sum` ready
  - Local dev: MariaDB + Redis via Homebrew, Go server direct

### What Phase 1 Does NOT Cover (→ Phase 2+)
- Building upgrades beyond level 0 (no construction start API)
- Breeding queue and active breed timers
- Research system (cost, timers, effects)
- Ant evolution (XP pool → elite units)
- Army upkeep (food cost per military ant) and starvation
- Combat engine (PvE or PvP)
- Any iOS client UI

### Files Delivered
```
antswarzzz/
├── docker-compose.yml
├── db/init.sql                     (338 lines, 18 tables + seed data)
├── specs/cahier_des_charges.md     (977 lines, game design)
├── stack-proposal/
│   ├── README.md                   (full technical stack proposal)
│   ├── database.md                 (schema + rationale)
│   ├── server-multiplayer.md       (Go server + WebSocket design)
│   ├── client-tools.md             (iOS stack proposal)
│   └── init.sql                    (original seed)
└── server/
    ├── Dockerfile
    ├── go.mod / go.sum
    ├── cmd/server/main.go
    └── internal/
        ├── models/models.go        (structs, formulas, constants)
        ├── database/db.go          (CRUD operations)
        ├── tick/tick.go            (tick engine)
        └── api/handlers.go         (REST endpoints)
```

### Verified End-to-End
```
$ curl http://localhost:8080/health
{"service":"antswarzzz-server","status":"ok"}

$ curl -X POST .../api/player/register -d '{"username":"test"}'
{"colony_id":1,"player_id":1,"username":"test"}

$ curl .../api/colony/1
→ 5 workers (ant_type=0), 4 buildings level 0, 100 food, 100 materials

$ curl -X POST .../api/colony/1 -d '{"action":"assign_workers","workers_on_food":3,"workers_on_materials":2}'
→ workers updated

$ curl -X POST .../api/tick -d '{"colony_id":1}'
→ Resources: food=103, materials=102 (3 food + 2 materials harvested)
```