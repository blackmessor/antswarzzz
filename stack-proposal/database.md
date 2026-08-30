# Antswarzzz — Database Schema Proposal

> **Database**: MariaDB (MySQL-compatible)
> **Version**: 1.0 — August 2026
> **Design philosophy**: Normalized relational schema with static reference tables for game data and per-colony tables for mutable player state. All game math uses integers (floor rounding), so resource and timer columns are INTEGER.

---

## 1. Entity List

### 1.1 Static Reference Tables (Game Data)

These tables define the game's immutable rules — ant types, building types, research types. They are seeded once at deployment and rarely change (only for balance patches).

#### `players`
Player accounts. One player can have multiple colonies (alts, different servers). In MVP (single iOS device), player_id may map 1:1 to a device; in multiplayer, this is the central account table.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | INT UNSIGNED | PK, AUTO_INCREMENT | Unique player ID |
| `username` | VARCHAR(32) | UNIQUE, NOT NULL | Display name |
| `email` | VARCHAR(255) | UNIQUE, NOT NULL | Login email |
| `password_hash` | VARCHAR(255) | NOT NULL | bcrypt hash |
| `created_at` | DATETIME | NOT NULL, DEFAULT UTC_TIMESTAMP | Account creation |
| `last_login` | DATETIME | NULL | Last login timestamp |
| `is_active` | TINYINT(1) | NOT NULL, DEFAULT 1 | Soft-delete flag |

#### `ant_types`
The 15 ant type definitions. Static game data.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | TINYINT UNSIGNED | PK | Ant type ID (0-14, matches spec) |
| `slug` | VARCHAR(32) | UNIQUE, NOT NULL | Machine name (e.g. `ouvriere`, `jsn`, `tank`) |
| `name` | VARCHAR(64) | NOT NULL | Display name (e.g. "Jeune Soldate Naine") |
| `abbreviation` | VARCHAR(8) | NOT NULL | Short code (e.g. "JSN") |
| `base_hp` | SMALLINT UNSIGNED | NOT NULL | Base hit points (0 for workers) |
| `base_attack` | SMALLINT UNSIGNED | NOT NULL | Base damage (0 for workers) |
| `base_defense` | SMALLINT UNSIGNED | NOT NULL | Base damage reduction (0 for workers) |
| `breed_time_seconds` | INT UNSIGNED | NULL | Time to breed one unit; NULL = evolution-only |
| `food_cost` | INT UNSIGNED | NOT NULL | Food consumed at breed start |
| `is_worker` | TINYINT(1) | NOT NULL, DEFAULT 0 | True for Ouvrière only |
| `is_breedable` | TINYINT(1) | NOT NULL, DEFAULT 1 | False for evolution-only units |
| `evolves_to_id` | TINYINT UNSIGNED | NULL, FK → ant_types.id | Which elite form this evolves into |
| `death_order` | TINYINT UNSIGNED | NOT NULL | Sort priority in combat death (1 = dies first) |
| `unlock_building_id` | VARCHAR(32) | NULL | Building slug required to breed (e.g. "combat_room") |
| `unlock_building_level` | INT UNSIGNED | NULL | Minimum building level |
| `unlock_research_id` | VARCHAR(32) | NULL | Research slug required (e.g. "acide", "poison") |

#### `building_types`
The 13 building type definitions. Static game data.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | TINYINT UNSIGNED | PK | Building type ID |
| `slug` | VARCHAR(32) | UNIQUE, NOT NULL | Machine name (e.g. `hatchery`, `dome`) |
| `name` | VARCHAR(64) | NOT NULL | Display name (e.g. "Couveuse") |
| `category` | ENUM('A','B','C','D') | NOT NULL | Cost scaling category |
| `base_cost_materials` | INT UNSIGNED | NOT NULL | Materials for level 1 (0 if N/A) |
| `base_cost_food` | INT UNSIGNED | NULL | Food for level 1 (category C only) |
| `base_cost_workers` | INT UNSIGNED | NULL | Workers consumed for level 1 (category C only) |
| `base_time_seconds` | INT UNSIGNED | NOT NULL | Build time for level 1 |
| `effect_description` | VARCHAR(255) | NOT NULL | Human-readable effect |

#### `research_types`
The 10 research types. Static game data.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | TINYINT UNSIGNED | PK | Research type ID |
| `slug` | VARCHAR(32) | UNIQUE, NOT NULL | Machine name (e.g. `tech_ponte`, `poison`) |
| `name` | VARCHAR(64) | NOT NULL | Display name |
| `base_cost_workers` | INT UNSIGNED | NOT NULL | Workers for level 1 |
| `base_cost_food` | INT UNSIGNED | NOT NULL | Food for level 1 |
| `base_cost_materials` | INT UNSIGNED | NOT NULL | Materials for level 1 |
| `base_time_seconds` | INT UNSIGNED | NOT NULL | Research time for level 1 |
| `prerequisite_research_id` | TINYINT UNSIGNED | NULL, FK → research_types.id | Required research before this one unlocks |
| `prerequisite_building_slug` | VARCHAR(32) | NULL | Required building (e.g. "lab") |
| `effect_type` | VARCHAR(32) | NOT NULL | Effect category: `breeding_speed`, `unit_hp`, `unit_damage`, `build_time`, `hunt_time`, `attack_time`, `unlock_only` |

### 1.2 Mutable State Tables (Per-Colony)

#### `colonies`
One row per player's colony. This is the root entity that all game state hangs from.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | INT UNSIGNED | PK, AUTO_INCREMENT | Unique colony ID |
| `player_id` | INT UNSIGNED | FK → players.id, NOT NULL | Owner |
| `name` | VARCHAR(64) | NOT NULL | Colony name |
| `tdc_size` | INT UNSIGNED | NOT NULL, DEFAULT 50 | TDC surface in cm² (starting: 50) |
| `workers_on_food` | INT UNSIGNED | NOT NULL, DEFAULT 0 | Workers assigned to food harvest |
| `workers_on_materials` | INT UNSIGNED | NOT NULL, DEFAULT 0 | Workers assigned to material harvest |
| `last_tick_at` | DATETIME | NOT NULL, DEFAULT UTC_TIMESTAMP | Last time the tick engine ran for this colony |
| `created_at` | DATETIME | NOT NULL, DEFAULT UTC_TIMESTAMP | |
| `updated_at` | DATETIME | NOT NULL, DEFAULT UTC_TIMESTAMP ON UPDATE | |

#### `colony_resources`
Separated from `colonies` to keep resource mutations isolated (hot path during tick processing).

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `colony_id` | INT UNSIGNED | PK, FK → colonies.id | One row per colony |
| `food` | BIGINT UNSIGNED | NOT NULL, DEFAULT 0 | Current food stock (integer; all math uses floor) |
| `materials` | BIGINT UNSIGNED | NOT NULL, DEFAULT 0 | Current materials stock |

Using BIGINT because warehouse capacity at level 50 reaches ~10^18.

#### `colony_buildings`
One row per building per colony (13 rows per colony at minimum).

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | INT UNSIGNED | PK, AUTO_INCREMENT | |
| `colony_id` | INT UNSIGNED | FK → colonies.id, NOT NULL | |
| `building_type_id` | TINYINT UNSIGNED | FK → building_types.id, NOT NULL | |
| `level` | INT UNSIGNED | NOT NULL, DEFAULT 0 | Current level (0 = built but level 0) |
| `is_constructing` | TINYINT(1) | NOT NULL, DEFAULT 0 | True while build timer is active |
| `construction_timer` | INT UNSIGNED | NOT NULL, DEFAULT 0 | Seconds remaining; decremented by tick engine |

Unique constraint: `(colony_id, building_type_id)`.

#### `colony_research`
One row per research type per colony.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | INT UNSIGNED | PK, AUTO_INCREMENT | |
| `colony_id` | INT UNSIGNED | FK → colonies.id, NOT NULL | |
| `research_type_id` | TINYINT UNSIGNED | FK → research_types.id, NOT NULL | |
| `level` | INT UNSIGNED | NOT NULL, DEFAULT 0 | Current completed level |
| `is_researching` | TINYINT(1) | NOT NULL, DEFAULT 0 | True while research timer is active |
| `researching_level` | INT UNSIGNED | NOT NULL, DEFAULT 0 | Target level being researched |
| `research_timer` | INT UNSIGNED | NOT NULL, DEFAULT 0 | Seconds remaining |

Unique constraint: `(colony_id, research_type_id)`.

#### `colony_ants`
Aggregated ant counts per type per colony. Military ants are tracked by type and location (not individual rows — to keep the tick engine efficient at scale). Workers are tracked in `colonies.workers_on_food` / `workers_on_materials`.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | INT UNSIGNED | PK, AUTO_INCREMENT | |
| `colony_id` | INT UNSIGNED | FK → colonies.id, NOT NULL | |
| `ant_type_id` | TINYINT UNSIGNED | FK → ant_types.id, NOT NULL | |
| `location` | ENUM('home','tdc','hunting','attacking') | NOT NULL, DEFAULT 'home' | Current deployment |
| `count` | INT UNSIGNED | NOT NULL, DEFAULT 0 | Number of ants of this type at this location |
| `cumulative_xp` | BIGINT UNSIGNED | NOT NULL, DEFAULT 0 | Total XP pool for evolution (evolve `floor(cumulative_xp / threshold)` units) |

Unique constraint: `(colony_id, ant_type_id, location)`.

#### `breed_queue`
The queen's breeding queue. Only one entry is active (`position = 1`); the rest are queued.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | INT UNSIGNED | PK, AUTO_INCREMENT | |
| `colony_id` | INT UNSIGNED | FK → colonies.id, NOT NULL | |
| `position` | INT UNSIGNED | NOT NULL | 1-based: position 1 = active breed |
| `ant_type_id` | TINYINT UNSIGNED | FK → ant_types.id, NOT NULL | |

Unique constraint: `(colony_id, position)`.

#### `active_breed`
Current breeding progress, separated from the queue for cleaner tick processing.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `colony_id` | INT UNSIGNED | PK, FK → colonies.id | One active breed per colony |
| `ant_type_id` | TINYINT UNSIGNED | FK → ant_types.id, NOT NULL | What's being bred |
| `timer` | INT UNSIGNED | NOT NULL | Seconds remaining on current egg |
| `queue_position` | INT UNSIGNED | NOT NULL, DEFAULT 1 | Current position in breed_queue being processed |

#### `hunts`
Active PvE hunts against wild predators.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | INT UNSIGNED | PK, AUTO_INCREMENT | |
| `colony_id` | INT UNSIGNED | FK → colonies.id, NOT NULL | Attacker |
| `target_area` | INT UNSIGNED | NOT NULL | cm² of TDC to gain on success |
| `timer` | INT UNSIGNED | NOT NULL | Seconds remaining |
| `status` | ENUM('active','completed','failed') | NOT NULL, DEFAULT 'active' | |

#### `attacks`
Active PvP attacks.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | INT UNSIGNED | PK, AUTO_INCREMENT | |
| `attacker_colony_id` | INT UNSIGNED | FK → colonies.id, NOT NULL | |
| `defender_colony_id` | INT UNSIGNED | FK → colonies.id, NOT NULL | |
| `attack_type` | ENUM('tdc','colony') | NOT NULL | TDC attack or full colony attack |
| `timer` | INT UNSIGNED | NOT NULL | Seconds remaining |
| `status` | ENUM('active','resolved_attacker_win','resolved_defender_win') | NOT NULL, DEFAULT 'active' | |
| `created_at` | DATETIME | NOT NULL, DEFAULT UTC_TIMESTAMP | |

#### `hunt_armies`
Many-to-many: which ants are on each hunt. References `colony_ants` rows.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `hunt_id` | INT UNSIGNED | FK → hunts.id, ON DELETE CASCADE | |
| `colony_ant_id` | INT UNSIGNED | FK → colony_ants.id | |
| `count` | INT UNSIGNED | NOT NULL | How many of this ant group are in the hunt |

Composite PK: `(hunt_id, colony_ant_id)`.

#### `attack_armies`
Many-to-many: which ants are on each attack.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `attack_id` | INT UNSIGNED | FK → attacks.id, ON DELETE CASCADE | |
| `colony_ant_id` | INT UNSIGNED | FK → colony_ants.id | |
| `count` | INT UNSIGNED | NOT NULL | |

Composite PK: `(attack_id, colony_ant_id)`.

#### `combat_logs`
Immutable history of resolved combats.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | INT UNSIGNED | PK, AUTO_INCREMENT | |
| `attacker_colony_id` | INT UNSIGNED | FK → colonies.id, NOT NULL | |
| `defender_colony_id` | INT UNSIGNED | FK → colonies.id, NOT NULL | |
| `combat_type` | ENUM('tdc_attack','colony_attack','hunt') | NOT NULL | |
| `winner_colony_id` | INT UNSIGNED | NULL | NULL if hunt (PvE); colony ID if PvP |
| `tdc_gained` | INT UNSIGNED | NOT NULL, DEFAULT 0 | cm² transferred |
| `tdc_lost` | INT UNSIGNED | NOT NULL, DEFAULT 0 | cm² lost by defender |
| `food_pillaged` | BIGINT UNSIGNED | NOT NULL, DEFAULT 0 | |
| `materials_pillaged` | BIGINT UNSIGNED | NOT NULL, DEFAULT 0 | |
| `attacker_losses` | JSON | NULL | Breakdown of attacker ants lost by type |
| `defender_losses` | JSON | NULL | Breakdown of defender ants lost by type |
| `resolved_at` | DATETIME | NOT NULL, DEFAULT UTC_TIMESTAMP | |

#### `colonizations`
Colonization / vassal relationships.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `colonizer_colony_id` | INT UNSIGNED | FK → colonies.id, NOT NULL | The overlord |
| `colonized_colony_id` | INT UNSIGNED | FK → colonies.id, NOT NULL | The vassal |
| `tax_rate` | DECIMAL(4,4) | NOT NULL | Fraction of income transferred (0.20 base + aphid farm bonus) |
| `started_at` | DATETIME | NOT NULL, DEFAULT UTC_TIMESTAMP | |

Composite PK: `(colonizer_colony_id, colonized_colony_id)`.

### 1.3 Supporting Tables

#### `colony_events`
Audit log for significant colony actions (construction started/completed, research completed, combat resolved, evolution triggered). Useful for debugging, analytics, and player activity feeds.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | BIGINT UNSIGNED | PK, AUTO_INCREMENT | High-volume, BIGINT for safety |
| `colony_id` | INT UNSIGNED | FK → colonies.id, NOT NULL | |
| `event_type` | VARCHAR(32) | NOT NULL | `build_start`, `build_complete`, `research_complete`, `combat_resolved`, `evolution`, `breed_complete` |
| `payload` | JSON | NULL | Event-specific data |
| `created_at` | DATETIME | NOT NULL, DEFAULT UTC_TIMESTAMP | |

Index: `(colony_id, created_at)`.

---

## 2. Entity Relationship Diagram

```
┌──────────┐       1:N       ┌──────────┐
│  players │────────────────▶│ colonies │
└──────────┘                 └────┬─────┘
                                  │
                                  │ 1:1
                                  ▼
                        ┌──────────────────┐
                        │ colony_resources  │
                        └──────────────────┘
                                  │
                                  │ 1:N
            ┌─────────────────────┼─────────────────────┐
            ▼                     ▼                     ▼
   ┌────────────────┐   ┌────────────────┐   ┌──────────────────┐
   │colony_buildings│   │ colony_research │   │   colony_ants     │
   └───────┬────────┘   └───────┬────────┘   └────────┬─────────┘
           │                    │                      │
           │ N:1               │ N:1                  │ N:1
           ▼                    ▼                      ▼
   ┌──────────────┐   ┌──────────────┐       ┌──────────────┐
   │building_types│   │research_types│       │  ant_types   │
   │  (static)    │   │  (static)    │       │  (static)    │
   └──────────────┘   └──────┬───────┘       └──────┬───────┘
                             │                      │
                             │ self-ref             │ self-ref (evolves_to)
                             ▼                      ▼
                      ┌──────────────┐       ┌──────────────┐
                      │research_types│       │  ant_types   │
                      │(prerequisite)│       │  (elite)     │
                      └──────────────┘       └──────────────┘

┌──────────┐
│ colonies │ (breed queue)
└────┬─────┘
     │ 1:N                   1:1
     ├──────────────────────▶┌──────────────┐
     │                       │  breed_queue │
     │                       └──────────────┘
     │ 1:1
     └──────────────────────▶┌──────────────┐
                             │ active_breed │
                             └──────────────┘

┌──────────┐        1:N       ┌──────────┐        N:M       ┌──────────────┐
│ colonies │─────────────────▶│  hunts   │◀────────────────│ colony_ants  │
│(attacker)│                  └────┬─────┘   hunt_armies   │  (military)  │
└────┬─────┘                       │                        └──────────────┘
     │                             │
     │ 1:N                         │ N:M
     ├──────────────────▶┌─────────┴─────┐   attack_armies
     │                   │   attacks     │◀────────────────── colony_ants
     │                   └───────────────┘
     │
     │ N:N (self-ref through colonizations)
     ├──────────────────────────┐
     ▼                          ▼
┌──────────────────────────────────────┐
│           colonizations              │
│  colonizer_colony_id                 │
│  colonized_colony_id                 │
└──────────────────────────────────────┘

┌──────────┐        N:N        ┌──────────────┐
│ colonies │──────────────────▶│ combat_logs  │
│          │◀──────────────────│              │
└──────────┘   (attacker +     └──────────────┘
                defender)
```

---

## 3. Docker Compose Snippet

```yaml
# docker-compose.yml — MariaDB for Antswarzzz development
version: "3.8"

services:
  mariadb:
    image: mariadb:11.4
    container_name: antswarzzz-db
    restart: unless-stopped
    environment:
      MARIADB_ROOT_PASSWORD: ${DB_ROOT_PASSWORD:-antswarzzz_root_dev}
      MARIADB_DATABASE: antswarzzz
      MARIADB_USER: antswarzzz_app
      MARIADB_PASSWORD: ${DB_APP_PASSWORD:-antswarzzz_app_dev}
    ports:
      - "3306:3306"
    volumes:
      - mariadb_data:/var/lib/mysql
      - ./stack-proposal/init.sql:/docker-entrypoint-initdb.d/01-schema.sql:ro
    healthcheck:
      test: ["CMD", "healthcheck.sh", "--connect", "--innodb_initialized"]
      interval: 10s
      timeout: 5s
      retries: 5
    command: >
      --character-set-server=utf8mb4
      --collation-server=utf8mb4_unicode_ci
      --max_connections=200
      --innodb_buffer_pool_size=256M

volumes:
  mariadb_data:
    driver: local
```

**Usage:**

```bash
# Start MariaDB
cd antswarzzz/
docker compose up -d

# Connect with CLI
docker exec -it antswarzzz-db mariadb -u antswarzzz_app -p antswarzzz

# Stop
docker compose down

# Reset (destroy data)
docker compose down -v && docker compose up -d
```

---

## 4. Initialization SQL

The file `stack-proposal/init.sql` (auto-mounted by Docker Compose above) creates the full schema and seeds static reference data for all 15 ant types, 13 building types, and 10 research types.

See: [stack-proposal/init.sql](./init.sql)

---

## 5. Design Decisions & Rationale

### Why aggregated ants instead of individual rows?
A colony can have thousands of military ants. Individual rows would mean 10,000+ inserts/updates per combat tick. Aggregating by `(colony_id, ant_type_id, location)` keeps per-colony queries bounded to ~60 rows (15 types x 4 locations) regardless of army size. Evolution is handled by tracking cumulative XP per group and evolving `floor(cumulative_xp / threshold)` units in one update.

### Why separate `colony_resources` from `colonies`?
Resources are the hottest write path (every tick, every combat, every build). Isolating them in a narrow table reduces lock contention and allows the tick engine to update resources without touching the wider colony row.

### Why `ENUM` for fixed-set columns?
`location`, `category`, `attack_type`, `status`, `event_type` — all have a small, well-defined set of values that won't change between deploys. ENUM enforces validity at the database level and stores as 1 byte.

### Why `BIGINT` for resources and XP?
Warehouse capacity at level 50 reaches ~1.35 x 10^18 (1.35 quintillion). INT (2.1 billion) overflows at level ~21. BIGINT (9.2 x 10^18) handles up to level ~50 without risk.

### Why JSON for combat losses?
`combat_logs.attacker_losses` and `defender_losses` store `{ "ant_type_id": count_lost }` maps. This is write-once, read-rarely data — JSON avoids a separate junction table and keeps the combat log self-contained for display.

### Tick engine isolation
All timer decrements (`construction_timer`, `research_timer`, `active_breed.timer`, `hunts.timer`, `attacks.timer`) are integer seconds updated by subtracting `TICK_INTERVAL` (1800) per tick. The tick engine processes colonies in batches and wraps each colony's tick in a transaction to ensure atomicity.

### Indexing strategy (not exhaustive, critical paths)
- `colony_buildings`: index on `(colony_id, building_type_id)` UNIQUE
- `colony_research`: index on `(colony_id, research_type_id)` UNIQUE
- `colony_ants`: index on `(colony_id, ant_type_id, location)` UNIQUE
- `colony_events`: index on `(colony_id, created_at DESC)`
- `breed_queue`: index on `(colony_id, position)` UNIQUE
- `attacks`: index on `(defender_colony_id, status)` for finding pending defenses
- `colonizations`: index on `(colonized_colony_id)` for tax calculation

---

*Schema version 1.0. Designed for MariaDB 11.4+. All formulas and constants reference Antswarzzz Cahier des Charges v1.0.*