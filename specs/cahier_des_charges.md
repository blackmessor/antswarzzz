# Antswarzzz — Cahier des Charges (Game Design Specification)

> **Project**: Antswarzzz — an iOS ant colony strategy game inspired by Fourmizzz
> **Document type**: Technical game design specification for AI-assisted development
> **Version**: 1.0 — August 2026
> **Sources**: Fourmizzz (fourmizzz.fr), community guides, Fourmizzz Calculator v1.2

---

## Table of Contents

1. [Game Overview](#1-game-overview)
2. [Resources](#2-resources)
3. [Rooms & Buildings](#3-rooms--buildings)
4. [Ant Types](#4-ant-types)
5. [Game Mechanics](#5-game-mechanics)
6. [Algorithms](#6-algorithms)
7. [Appendix A: Swift Data Models](#appendix-a-data-model-suggested-swift-structs)
8. [Appendix B: Implementation Phases](#appendix-b-implementation-phases)

---

## 1. Game Overview

Antswarzzz is a persistent ant colony management game. The player controls a queen ant that builds an underground anthill, breeds worker and military ants, harvests resources, researches technologies, and expands territory through hunting and PvP combat.

**Core loop**: Harvest resources → build rooms → breed ants → research tech → expand territory → repeat.

**Time model**: Real-time with tick-based resource accumulation (30-minute ticks). Building, breeding, and research use countdown timers.

---

## 2. Resources

### 2.1 Resource Types

The game has two resources:

| Resource | Internal ID | Description |
|----------|-------------|-------------|
| **Food** (Nourriture) | `food` | Consumed by ant upkeep and breeding. Produced by workers and mushroom farms. |
| **Materials** (Matériaux) | `materials` | Used for building construction and research. Produced only by workers. |

### 2.2 Resource Generation — Worker Harvesting

Workers assigned to the Terrain de Chasse (TDC) harvest resources continuously.

**Constants:**
- `HARVEST_RATE = 1` resource per worker per tick
- `TICK_INTERVAL = 1800` seconds (30 minutes)
- `MAX_WORKERS_PER_CM2 = 1`

**Algorithm:**
```
per_tick:
  food_harvested = workers_on_food
  materials_harvested = workers_on_materials
  
  // Capped by TDC size
  max_total_workers = tdc_size_in_cm2
```

The player allocates workers between food and materials via a percentage slider or explicit count input. Total workers assigned cannot exceed `tdc_size_cm2`.

### 2.3 Resource Generation — Champignonnière (Mushroom Farm)

Passive daily food production from the mushroom farm building.

**Formula:**
```
daily_food = floor(122 * 1.70^(level - 1))
```

Applied once per 24 hours. In practice, implement per-tick:
```
food_per_tick = daily_food / 48   // 48 ticks per day
```

Example values (daily):

| Level | Food/Day | Level | Food/Day |
|-------|----------|-------|----------|
| 1 | 122 | 10 | 14,515 |
| 2 | 208 | 15 | 206,094 |
| 3 | 354 | 20 | 2,926,247 |
| 4 | 601 | 25 | 41,548,517 |
| 5 | 1,022 | 30 | 589,929,532 |

### 2.4 Resource Storage — Warehouses

Two separate warehouse buildings: food warehouse and materials warehouse. Identical mechanics.

**Formulas:**
```
capacity(level) = 1700 + 1200 * (2^level - 1)     // verified against original game data
materials_cost(level) = 600 * 2^(level - 1)       // for level >= 1
build_time_seconds(level) = 180 * 1.6^(level - 1)  // 3 min base
```

| Level | Capacity | Material Cost | Build Time |
|-------|----------|--------------|------------|
| 0 | 1,700 | — | — |
| 1 | 2,900 | 600 | 3m 00s |
| 2 | 5,300 | 1,200 | 4m 48s |
| 3 | 10,100 | 2,400 | 7m 41s |
| 5 | 38,900 | 9,600 | 19m 40s |
| 10 | 1,229,300 | 307,200 | 3h 26m |
| 20 | 1,258,291,700 | 314,572,800 | 15d 17h |

**Overflow rule**: If `food + incoming > food_warehouse_capacity`, excess is lost. Same for materials.

### 2.5 Resource Consumption — Army Upkeep

Military ants consume food daily.

**Constants:**
- `UPKEEP_INSIDE = 0.10` — 10% of ant's food cost per day when inside the anthill
- `UPKEEP_OUTSIDE = 0.05` — 5% per day when outside (hunting, attacking, TDC defense)
- `STARVATION_DEATH_RATE = 0.005` — 0.5% of army dies per tick when food is zero

**Per-tick algorithm:**
```
total_upkeep = 0
for each ant in colony:
    if ant.location == "inside":
        total_upkeep += ant.food_cost * UPKEEP_INSIDE / 48
    else:
        total_upkeep += ant.food_cost * UPKEEP_OUTSIDE / 48

food -= total_upkeep

if food <= 0 and total_upkeep > 0:
    food = 0
    kill_count = floor(total_army_count * STARVATION_DEATH_RATE)
    kill weakest ants first (by death order)
```

---

## 3. Rooms & Buildings

### 3.1 Build Categories

Buildings fall into three scaling categories.

#### Category A: Simple Buildings (materials cost only)

Doublers: cost doubles each level, time multiplies by 1.6.

**Formula:**
```
cost_materials(level) = base_cost * 2^(level - 1)
time_seconds(level) = base_time_seconds * 1.6^(level - 1)
```

Buildings in this category:

| Building | ID | Function | Base Cost (lvl 1) | Base Time |
|----------|-----|----------|--------------------|-----------|
| Couveuse | `hatchery` | +10% laying speed/level | 2,000 mat | 1,000s (16m 40s) |
| Solarium | `solarium` | +10% laying speed/level | 1,400 mat | 300s (5m) |
| Laboratoire | `lab` | Enables research | 300 mat | 120s (2m) |
| Salle d'analyse | `analysis_room` | -10% research time/level | 800 mat | 200s (3m 20s) |
| Étable à pucerons | `aphid_farm` | +1% pillage, +5% trade/level | 100 mat | 200s (3m 20s) |
| Étable à cochenilles | `mealybug_farm` | +10% evolution rate/level | 80 mat | 120s (2m) |

#### Category B: Champignonnière (Special Scaling)

**Formulas:**
```
cost_materials(level) = floor(90 * 1.85^(level - 1))
time_seconds(level) = 120 * 1.6^(level - 1)           // 2 min base
food_production_per_day(level) = floor(122 * 1.70^(level - 1))
```

| Building | ID | Function |
|----------|-----|----------|
| Champignonnière | `mushroom_farm` | Passive daily food |

#### Category C: Tier-2 Buildings (materials + food + workers)

All three costs double each level.

**Formula:**
```
cost_materials(level) = base_materials * 2^(level - 1)
cost_food(level) = base_food * 2^(level - 1)
cost_workers(level) = base_workers * 2^(level - 1)
time_seconds(level) = base_time_seconds * 1.6^(level - 1)
```

Workers spent are **consumed** (not returned).

Buildings in this category:

| Building | ID | Function | Mat (lvl 1) | Food (lvl 1) | Workers (lvl 1) | Time |
|----------|-----|----------|-------------|--------------|-----------------|------|
| Salle de combat | `combat_room` | Unlocks military units | 2,500 | 4,000 | 50 | 200s (3m 20s) |
| Caserne | `barracks` | Unlocks advanced units | 5,000 | 8,000 | 100 | 200s (3m 20s) |
| Dôme | `dome` | Defense: 10%+5%/lvl | 10,000 | 16,000 | 200 | 200s (3m 20s) |
| Loge Impériale | `imperial_lodge` | Defense: 30%+15%/lvl | 20,000 | 32,000 | 400 | 200s (3m 20s) |

#### Category D: Warehouses

See §2.4 for full formulas.

### 3.2 Complete Building List (13 buildings)

| # | Building | ID | Category | Function |
|---|----------|-----|----------|----------|
| 1 | Champignonnière | `mushroom_farm` | B | Daily passive food |
| 2 | Entrepôt de nourriture | `food_warehouse` | D | Food storage capacity |
| 3 | Entrepôt de matériaux | `mat_warehouse` | D | Material storage capacity |
| 4 | Couveuse | `hatchery` | A | +10% laying speed/level |
| 5 | Solarium | `solarium` | A | +10% laying speed/level |
| 6 | Laboratoire | `lab` | A | Enables research |
| 7 | Salle d'analyse | `analysis_room` | A | -10% research time/level |
| 8 | Salle de combat | `combat_room` | C | Unlocks military units |
| 9 | Caserne | `barracks` | C | Unlocks advanced units |
| 10 | Dôme | `dome` | C | Defense bonus |
| 11 | Loge Impériale | `imperial_lodge` | C | Defense + colonization target |
| 12 | Étable à pucerons | `aphid_farm` | A | +1% pillage, +5% trade/level |
| 13 | Étable à cochenilles | `mealybug_farm` | A | +10% evolution rate/level |

### 3.3 Building Prerequisites

| Building | Prerequisites |
|----------|--------------|
| Champignonnière | Materials warehouse level >= 1 |
| Champignonnière level > 5 | Materials warehouse level >= Champignonnière level - 1 |
| Salle de combat | Lab level >= 1 |
| Caserne | Salle de combat level >= 5 (approx.) |
| Laboratoire | None (starter building) |
| Loge Impériale | Architecture research |
| Dôme | Architecture research level >= 3 |

### 3.4 Anthill Level

```
anthill_level = sum of all building levels across all 13 buildings
```

1 point per building level. Used for matchmaking and ranking display.

---

## 4. Ant Types

### 4.1 Complete Unit Roster (15 types)

Each ant type has base stats that are modified by research and building bonuses.

| ID | Unit | Abbr. | HP | Atk | Def | Breed Time (s) | Food Cost | Unlock |
|----|------|-------|----|-----|-----|-----------------|-----------|--------|
| 0 | **Ouvrière** | Wrk | 0 | 0 | 0 | 60 | 5 | Default |
|| 1 | **Jeune Soldate Naine** | JSN | 8 | 3 | 2 | 300 | 10 | Salle de Combat lvl 1 |
|| 2 | **Soldate Naine** | SN | 10 | 5 | 4 | 450 | 14 | Salle de Combat lvl 3 |
|| 3 | **Naine d'Élite** | NE | 13 | 7 | 6 | — | 18 | **Evolution only** (from SN) |
|| 4 | **Jeune Soldate** | JS | 16 | 10 | 9 | 740 | 16 | Salle de Combat higher lvl |
|| 5 | **Soldate** | S | 20 | 15 | 14 | 1,000 | 22 | Caserne |
|| 6 | **Soldate d'Élite** | SE | 27 | 24 | 23 | — | 28 | **Evolution only** (from S) |
|| 7 | **Concierge** | C | 30 | 1 | 25 | 1,410 | 30 | Research/building unlock |
|| 8 | **Concierge d'Élite** | CE | 40 | 1 | 35 | — | 38 | **Evolution only** (from C) |
|| 9 | **Artilleuse** | A | 10 | 30 | 15 | 1,440 | 28 | Acide research |
|| 10 | **Artilleuse d'Élite** | AE | 12 | 35 | 18 | 1,520 | 35 | Acide research (breed or evolve) |
|| 11 | **Tank** | Tk | 35 | 55 | 1 | 1,860 | 45 | Génétique lvl ~14 + Caserne lvl ~22 |
|| 12 | **Tank d'Élite** | TkE | 50 | 80 | 1 | — | 55 | **Evolution only** (from Tk) |
|| 13 | **Tueuse** | Tu | 50 | 50 | 50 | 2,740 | 60 | Poison research |
|| 14 | **Tueuse d'Élite** | TuE | 55 | 55 | 55 | — | 72 | **Evolution only** (from Tu) |

Notes:
- Food costs for originally missing units (SN, S, NE, SE, CE, A, Tk, TkE, Tu, TuE) have been interpolated from known values following the game's cost progression curve.
- "-" for breed time on evolution-only units means they cannot be bred directly.
- Stats are base values before bonuses (Armes, Bouclier, Dôme, Loge).

### 4.2 Worker (Ouvrière) Special Rules

- Workers have 0 HP, 0 Atk, 0 Def — they cannot fight.
- Workers are assigned to food or materials harvesting.
- Workers count against TDC capacity (1 per cm²).
- Worker food cost is 5 (consumed once at breeding).

### 4.3 Combat Death Order

When units die in combat, the weakest are eliminated first. The order matches the breeding list:

```
JSN → SN → NE → JS → S → C → CE → A → AE → SE → Tk → TkE → Tu → TuE
```

Implication: JSN is the cheapest "meat shield" — bred fast, dies first, absorbs losses.

### 4.4 Effective Stats After Bonuses

```
effective_HP = base_HP * (1 + bouclier_thoracique_level * 0.10)

effective_ATK = base_ATK * (1 + armes_level * 0.10)

effective_DEF = base_DEF
  // Defense is not directly scaled by research.
  // It reduces incoming damage: damage_taken = max(0, attacker_atk - defender_def)
```

For defending anthill:
```
defense_HP_multiplier = 1 + (dome_bonus + loge_bonus)
  where dome_bonus = 0.10 + 0.05 * dome_level
  and   loge_bonus = 0.30 + 0.15 * loge_level
```

### 4.5 Evolution System

Units gain XP from combat. When a unit accumulates enough XP, it evolves to its elite form.

**Evolution paths:**
```
Soldate Naine (SN)  →  Naine d'Élite (NE)
Soldate (S)         →  Soldate d'Élite (SE)
Concierge (C)       →  Concierge d'Élite (CE)
Tank (Tk)           →  Tank d'Élite (TkE)
Tueuse (Tu)         →  Tueuse d'Élite (TuE)
```

**Mechanic:**
- Each combat, a subset of participating units gains XP.
- Base: top N units per combat gain XP (where N is a system constant, e.g. 10).
- Étable à Cochenilles: each level adds +10% more units gaining XP.
  ```
  units_gaining_xp = base_N * (1 + 0.10 * mealybug_farm_level)
  ```
- When a unit's XP reaches its evolution threshold, it upgrades instantly (replace unit entry with elite version).

**XP threshold** (to be tuned): ~100 XP for first evolution, scaling with tier.

---

## 5. Game Mechanics

### 5.1 Laying (Breeding)

The queen lays eggs continuously. The player selects which ant type to breed.

**Breeding time formula:**
```
effective_speed = 1 + 0.10 * (hatchery_level + solarium_level + technique_ponte_level)
effective_time = base_breed_time / effective_speed
```

**Breeding cost:**
- Food cost as specified per ant type (consumed at start of breeding).
- Workers cost 5 food each.

**Queue**: The player sets a breed queue. Only one breed active at a time (queen lays one egg type at a time).

### 5.2 Building

**Start construction:**
1. Check prerequisites (building level, warehouse capacity, required research).
2. Deduct costs (materials, food, workers if applicable) instantly.
3. Start countdown timer with `time_seconds(level)`.
4. Building is inactive during construction.
5. On timer expiry, building activates at the new level.

**Time reduction from Architecture research:**
```
effective_time = base_time * max(0.1, 1 - 0.10 * architecture_level)
```
Minimum 10% of base time (cap at architecture level 9).

### 5.3 Research

**Available only when Laboratoire exists** (level >= 1).

**Research list (10 technologies):**

| ID | Research | Effect Per Level |
|----|----------|------------------|
| `tech_ponte` | Technique de Ponte | -10% breeding time |
| `bouclier` | Bouclier Thoracique | +10% unit HP |
| `armes` | Armes | +10% unit damage |
| `architecture` | Architecture | Unlocks buildings, -10% building time |
| `vitesse_chasse` | Vitesse de Chasse | -10% hunt time, +1 simultaneous hunt |
| `vitesse_attaque` | Vitesse d'Attaque | -10% attack time, -10% convoy time |
| `comm_animaux` | Communication Animaux | Unlocks Étable à pucerons, other buildings |
| `genetique` | Génétique | Unlocks Tank, other units |
| `acide` | Acide | Unlocks Artilleuse |
| `poison` | Poison | Unlocks Tueuse |

**Research cost formulas (representative):**
```
worker_cost(level)    = base_workers * 2^(level - 1)
food_cost(level)      = base_food * 2.5^(level - 1)
materials_cost(level) = base_materials * 1.5^(level - 1)
time_seconds(level)   = base_time * 1.6^(level - 1)
```

Costs are deducted instantly when research starts.

**Research time reduction:**
```
effective_time = base_time * max(0.1, 1 - 0.10 * analysis_room_level)
```

**Technology points:**
```
tech_points = sum of all completed research levels across all technologies
```

**Dependency graph:**
```
Laboratoire (building) enables all research.

Initial (no prereq): Technique Ponte, Bouclier, Armes, Architecture,
                     Vitesse Chasse, Vitesse Attaque

Architecture → Communication Animaux
Lab + Armes   → Génétique
Génétique     → Acide
Acide         → Poison
```

### 5.4 Terrain de Chasse (TDC) — Hunting Territory

TDC is the surface territory measured in cm².

**Properties:**
- Starting TDC: 50 cm²
- Max worker capacity: `tdc_size_cm2` (1 worker per cm²)
- Max resource income per tick: `tdc_size_cm2` (one resource per assigned worker)

**TDC Expansion — Hunting:**
- Player sends combat ants on hunts against wild predators.
- On success: TDC increases by the hunt's territory gain.
- Hunt time scales with current TDC size and target size.
- Simultaneous hunts: `1 + vitesse_chasse_level`.
- Hunt time reduction: `effective_hunt_time = base_hunt_time * max(0.1, 1 - 0.10 * vitesse_chasse_level)`.

**TDC Expansion — PvP Attack:**
- Attack another player's TDC with combat army.
- Win: Gain 20% of defender's TDC, capped at `1 cm² per attacking ant`.
- Loss: Attacker army is destroyed, no TDC gained.

**TDC Defense Loss:**
- When defending army is defeated: lose 20% of TDC, capped at `1 cm² per surviving attacker ant`.

**TDC Attack Range:**
- Can only attack players whose TDC is 50% to 300% of your TDC:
  ```
  can_attack = (target_tdc >= 0.50 * my_tdc) AND (target_tdc <= 3.00 * my_tdc)
  ```

### 5.5 Combat System

Combat is deterministic (no randomness). Two armies clash; damage is calculated per round.

**Per-round damage:**
```
for each attacking ant:
    damage = max(1, attacker_effective_atk - defender_effective_def)
    target HP -= damage
```

**Combat flow:**
1. Both sides deal damage simultaneously each round.
2. Ants with HP <= 0 are removed at end of round.
3. Death order: weakest ant type first (per §4.3).
4. Combat ends when one side has zero ants remaining.
5. Winner is the side with ants still alive.

**Defense bonuses (home advantage):**
When defending own anthill:
```
defender_HP *= (1 + dome_bonus + loge_bonus)
```

**Pillage calculation on fourmilière attack win:**
```
pillage_percent = 0.30 + 0.01 * aphid_farm_level
food_stolen = min(defender_food * pillage_percent, surviving_army_total_attack)
mat_stolen = min(defender_materials * pillage_percent, surviving_army_total_attack)
```

### 5.6 Colonization

Building and upgrading the Loge Impériale unlocks colonization.

Colonizer applies tax to colonized player:
```
colony_tax = 0.20 + 0.01 * colonizer_aphid_farm_level
```

Tax applies to all resource income (worker harvest + mushroom farm).

Colonized player loses `colony_tax` of their income; colonizer gains it.

### 5.7 Army Upkeep

Per tick (every 30 minutes):
```
for each ant:
    if ant.is_military:
        if ant.location == "home":
            food_consumed += ant.food_cost * 0.10 / 48
        else:  // outside on hunt, attack, or TDC
            food_consumed += ant.food_cost * 0.05 / 48

food -= food_consumed

if food <= 0:
    food = 0
    ants_to_kill = floor(total_military * 0.005)
    kill weakest ants first
```

---

## 6. Algorithms

### 6.1 Resource Tick Engine

Executed every 30 minutes (1,800 seconds). This is the heartbeat of the game.

```
TICK:
  // 1. Worker harvesting
  max_workers = min(tdc_size_cm2, total_workers)
  food_workers = min(workers_assigned_food, max_workers - workers_assigned_materials)
  mat_workers = min(workers_assigned_materials, max_workers - food_workers)
  food += food_workers
  materials += mat_workers

  // 2. Mushroom farm passive
  food += floor(daily_mushroom_food / 48)

  // 3. Colony tax (if colonized)
  if colonized_by:
      tax_food = floor((food_workers + floor(daily_mushroom_food / 48)) * colony_tax)
      tax_mat = floor(mat_workers * colony_tax)
      food -= tax_food
      materials -= tax_mat
      colonizer.food += tax_food
      colonizer.materials += tax_mat

  // 4. Army upkeep
  apply_upkeep()   // see §5.7

  // 5. Cap resources to warehouse
  food = min(food, food_warehouse_capacity)
  materials = min(materials, materials_warehouse_capacity)

  // 6. Process construction timers
  for each building under construction:
      building.timer -= 1800
      if building.timer <= 0:
          complete_building(building)

  // 7. Process breeding
  breed_queue.timer -= 1800
  if breed_queue.timer <= 0:
      add_ant(breed_queue.type)
      advance_queue()

  // 8. Process research
  if active_research:
      research.timer -= 1800
      if research.timer <= 0:
          complete_research(research)

  // 9. Process hunt/attack timers
  for each active_hunt:
      hunt.timer -= 1800
      if hunt.timer <= 0:
          resolve_hunt(hunt)
  for each active_attack:
      attack.timer -= 1800
      if attack.timer <= 0:
          resolve_combat(attack)
```

### 6.2 Building Leveling Algorithm

```
function start_construction(building_id):
    building = colony.buildings[building_id]
    next_level = building.level + 1

    // Validate prerequisites
    if not check_prerequisites(building_id, next_level):
        return error

    // Calculate costs based on building category
    if building.category == "A":  // Simple
        mat_cost = floor(building.base_cost * pow(2, next_level - 1))
        time = floor(building.base_time * pow(1.6, next_level - 1))
        food_cost = 0
        worker_cost = 0
    elif building.category == "B":  // Champignonnière
        mat_cost = floor(90 * pow(1.85, next_level - 1))
        time = floor(120 * pow(1.6, next_level - 1))
        food_cost = 0
        worker_cost = 0
    elif building.category == "C":  // Tier-2
        mat_cost = floor(building.base_mat * pow(2, next_level - 1))
        food_cost = floor(building.base_food * pow(2, next_level - 1))
        worker_cost = floor(building.base_workers * pow(2, next_level - 1))
        time = floor(building.base_time * pow(1.6, next_level - 1))
    elif building.category == "D":  // Warehouse
        mat_cost = floor(600 * pow(2, next_level - 1))
        time = floor(180 * pow(1.6, next_level - 1))
        food_cost = 0
        worker_cost = 0

    // Apply architecture bonus
    time = floor(time * max(0.1, 1.0 - 0.10 * architecture_level))

    // Check affordability
    if materials < mat_cost or food < food_cost or workers < worker_cost:
        return error

    // Deduct costs
    materials -= mat_cost
    food -= food_cost
    workers -= worker_cost

    // Start construction timer
    building.constructing = true
    building.timer = time
```

### 6.3 Technology Progression Algorithm

```
function start_research(tech_id):
    tech = research[tech_id]
    next_level = tech.level + 1

    // Check prerequisites
    if not check_tech_prerequisites(tech_id, next_level):
        return error

    // Calculate costs
    worker_cost = floor(tech.base_workers * pow(2, next_level - 1))
    food_cost = floor(tech.base_food * pow(2.5, next_level - 1))
    mat_cost = floor(tech.base_materials * pow(1.5, next_level - 1))
    time = floor(tech.base_time * pow(1.6, next_level - 1))

    // Apply analysis room bonus
    time = floor(time * max(0.1, 1.0 - 0.10 * analysis_room_level))

    // Check affordability
    if materials < mat_cost or food < food_cost or workers < worker_cost:
        return error

    // Deduct costs
    materials -= mat_cost
    food -= food_cost
    workers -= worker_cost

    // Start research
    active_research = { tech_id, level: next_level, timer: time }
```

### 6.4 Combat Resolution Algorithm

```
function resolve_combat(attackers, defenders, location):
    // Copy armies (combat is non-destructive to source until resolution)
    atk_army = deep_copy(attackers)
    def_army = deep_copy(defenders)

    // Apply defense bonuses if defending home
    if location == "home":
        dome_mult = 1.0 + 0.10 + 0.05 * dome_level
        loge_mult = 1.0 + 0.30 + 0.15 * imperial_lodge_level
        for ant in def_army:
            ant.hp = floor(ant.hp * (dome_mult + loge_mult - 1.0))
    else if location == "imperial_lodge":
        loge_mult = 1.0 + 0.30 + 0.15 * imperial_lodge_level
        for ant in def_army:
            ant.hp = floor(ant.hp * loge_mult)

    // Sort by death order (weakest first)
    sort_by_death_order(atk_army)
    sort_by_death_order(def_army)

    // Combat rounds
    max_rounds = 50
    for round in 1..max_rounds:
        // Attackers deal damage
        for atk_ant in atk_army where atk_ant.hp > 0:
            if def_army is empty: break
            target = def_army[0]  // weakest defender
            damage = max(1, atk_ant.effective_atk - target.effective_def)
            target.hp -= damage

        // Remove dead defenders
        def_army = [ant for ant in def_army if ant.hp > 0]

        if def_army is empty: break  // attackers win

        // Defenders deal damage
        for def_ant in def_army where def_ant.hp > 0:
            if atk_army is empty: break
            target = atk_army[0]  // weakest attacker
            damage = max(1, def_ant.effective_atk - target.effective_def)
            target.hp -= damage

        // Remove dead attackers
        atk_army = [ant for ant in atk_army if ant.hp > 0]

        if atk_army is empty: break  // defenders win

    // Determine winner
    attacker_wins = len(atk_army) > 0
    defender_wins = len(def_army) > 0

    return {
        attacker_wins: attacker_wins,
        surviving_attackers: atk_army,
        surviving_defenders: def_army
    }
```

### 6.5 Breeding Queue Algorithm

```
function tick_breeding():
    if not breed_queue.active:
        return

    breed_queue.timer -= TICK_INTERVAL

    if breed_queue.timer <= 0:
        // Current breed finished
        ant_type = breed_queue.current_type
        colony.add_ant(ant_type)

        // Advance to next queued type
        breed_queue.position += 1
        if breed_queue.position < len(breed_queue.types):
            next_type = breed_queue.types[breed_queue.position]
            breed_queue.current_type = next_type   // set before computing timer
            speed = 1 + 0.10 * (hatchery_level + solarium_level + technique_ponte_level)
            breed_queue.timer = floor(next_type.base_breed_time / speed)
        else:
            breed_queue.active = false  // queue exhausted
```

### 6.6 Evolution Algorithm

```
function process_combat_xp(participating_ants):
    // Determine how many units gain XP
    base_count = 10
    xp_slots = floor(base_count * (1 + 0.10 * mealybug_farm_level))

    // Top performers get XP (strongest surviving units first)
    // Power = effective_HP + effective_ATK + effective_DEF (total combat strength)
    sorted = sort_by_power_desc(participating_ants)
    for i in 0..min(xp_slots, len(sorted)):
        ant = sorted[i]
        ant.xp += COMBAT_XP_GAIN  // constant, e.g. 10

        // Check evolution
        if ant.type in EVOLUTION_PATHS:
            elite_type = EVOLUTION_PATHS[ant.type]
            threshold = evolution_threshold(ant.type)
            if ant.xp >= threshold:
                ant.type = elite_type
                ant.xp = 0  // reset for next tier
```

### 6.7 Key Constants Summary

```
// Time
TICK_INTERVAL       = 1800    // seconds (30 min)
TICKS_PER_DAY       = 48

// Workers
HARVEST_RATE        = 1.0     // resource per worker per tick
MAX_WORKERS_PER_CM2 = 1

// Warehouses
WAREHOUSE_BASE_CAP  = 1700
WAREHOUSE_BASE_COST = 600

// Champignonnière
MUSHROOM_BASE_FOOD  = 122
MUSHROOM_FOOD_GROWTH = 1.70
MUSHROOM_COST_BASE   = 90
MUSHROOM_COST_GROWTH = 1.85

// Building scaling
BUILD_TIME_GROWTH    = 1.6
SIMPLE_COST_GROWTH   = 2.0

// Upkeep
UPKEEP_INSIDE_RATE   = 0.10 / 48   // per tick
UPKEEP_OUTSIDE_RATE  = 0.05 / 48   // per tick
STARVATION_DEATH     = 0.005       // fraction per tick

// Defense
DOME_BASE            = 0.10
DOME_PER_LEVEL       = 0.05
LOGE_BASE            = 0.30
LOGE_PER_LEVEL       = 0.15

// Pillage
PILLAGE_BASE         = 0.30
PILLAGE_PER_LEVEL    = 0.01

// Colony
COLONY_TAX_BASE      = 0.20
COLONY_TAX_PER_LEVEL = 0.01

// Laying
LAYING_SPEED_PER_LEVEL = 0.10  // per hatchery/solarium/tech_ponte level

// Research time/building time reductions
TIME_REDUCTION_PER_LEVEL = 0.10
MIN_TIME_FACTOR = 0.10

// XP
BASE_UNITS_GAINING_XP = 10
XP_GAIN_PER_COMBAT    = 10
EVOLUTION_XP_THRESHOLD = 100  // base, tune per unit type

// TDC
STARTING_TDC          = 50     // cm²
TDC_GAIN_PERCENT      = 0.20
TDC_LOSS_PERCENT      = 0.20
TDC_ATTACK_MIN_RATIO  = 0.50
TDC_ATTACK_MAX_RATIO  = 3.00
```

---

## Appendix A: Data Model (Suggested Swift Structs)

For iOS implementation in Swift, here are suggested data models:

```swift
// Resource model
struct Resources: Codable {
    var food: Int        // always whole numbers; all game math uses floor()
    var materials: Int
}

// Building
struct Building: Codable, Identifiable {
    let id: String
    let name: String
    let category: BuildingCategory
    var level: Int
    var isConstructing: Bool
    var constructionTimer: TimeInterval
    let baseCost: Double          // materials (category A)
    let baseTime: TimeInterval
    let baseFoodCost: Double?     // category C only
    let baseWorkerCost: Int?      // category C only

    func costForLevel(_ level: Int) -> Resources { ... }
    func timeForLevel(_ level: Int) -> TimeInterval { ... }
}

enum BuildingCategory: String, Codable {
    case simple      // A: materials only, cost ×2/level
    case mushroom    // B: special 1.85x cost, 1.70x production
    case tier2       // C: materials + food + workers
    case warehouse   // D: capacity ×2/level
}

// Ant type definition
struct AntType: Codable, Identifiable {
    let id: Int
    let name: String
    let abbreviation: String
    let baseHP: Int
    let baseAttack: Int
    let baseDefense: Int
    let breedTime: TimeInterval?
    let foodCost: Int
    let unlockRequirement: UnlockCondition
    let evolvesTo: Int?           // ant type ID it evolves into
}

// Ant instance
struct Ant: Codable, Identifiable {
    let id: UUID
    let typeID: Int
    var currentHP: Int
    var xp: Int
    var location: AntLocation
}

enum AntLocation: String, Codable {
    case home       // inside anthill
    case tdc        // defending TDC
    case hunting    // on a hunt
    case attacking  // on PvP attack
}

// Research
struct Research: Codable, Identifiable {
    let id: String
    let name: String
    var level: Int
    let effectPerLevel: ResearchEffect
    let prerequisites: [String: Int]  // tech ID → min level
}

enum ResearchEffect {
    case breedingSpeed(Double)       // -10% per level
    case unitHP(Double)              // +10% per level
    case unitDamage(Double)          // +10% per level
    case buildTime(Double)           // -10% per level
    case huntTime(Double)            // -10% per level
    case attackTime(Double)          // -10% per level
    case unlockOnly                  // gates access
}

// Colony (top-level)
struct Colony: Codable {
    var resources: Resources
    var tdcSize: Double              // cm²
    var buildings: [Building]
    var ants: [Ant]
    var research: [Research]
    var breedQueue: BreedQueue
    var workersOnFood: Int
    var workersOnMaterials: Int
}
```

---

## Appendix B: Implementation Phases

Suggested order for iterative iOS development:

**Phase 1 — Core Loop** (MVP)
- Resource model (food, materials)
- Workers + TDC + harvesting
- Simple buildings (Couveuse, warehouse, mushroom farm)
- Basic ant types (worker, JSN, SN)
- Breeding queue
- Tick engine

**Phase 2 — Expansion**
- All 13 buildings
- Remaining ant types (JS through Tu)
- Research system (first 6 techs)
- Evolution system
- Army upkeep + starvation

**Phase 3 — Combat**
- Combat resolution engine
- TDC hunting (PvE)
- Death order
- Defense bonuses

**Phase 4 — Multiplayer**
- PvP TDC attacks
- Pillaging
- Colonization
- Matchmaking (TDC range)

**Phase 5 — Polish**
- Unit-unlocking techs (Génétique, Acide, Poison)
- Full technology dependency graph
- Balance tuning
- UI/UX for all mechanics

---

*End of specification. All formulas are expressed with explicit constants and floor rounding. Every mechanic includes trigger conditions, input parameters, and output effects so an AI or developer can implement them without external reference.*