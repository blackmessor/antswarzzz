# Fourmizzz — Resource & Room Mechanics Analysis

> **Game**: Fourmizzz (fourmizzz.fr) — French browser-based ant colony strategy game  
> **Sources**: Official tutorials (fourmizzz.fr/tutorial.php), Toolzzz cost tables (toolzzz.fr/couts.php), community wikis  
> **Date**: August 2026

---

## 1. Resources

Fourmizzz has **two primary resources**: Nourriture (Food) and Matériaux (Materials/Wood).

### 1.1 Resource Generation — Worker Harvesting

Workers (ouvrières) are assigned to harvest on the Terrain de Chasse (TDC, Hunting Ground).

| Parameter | Value |
|-----------|-------|
| Harvest rate | **1 resource per worker per 30 minutes** (0.0333/min) |
| Worker density | **1 worker per cm²** of TDC |
| Assignment | Player allocates workers between food and materials via the Resources page |

**Formula:**
```
resources_per_tick = workers_assigned_to_resource
```
Where a tick = 30 minutes. Workers harvest continuously, even when the player is offline.

**Example:** 100 workers on food + 50 on materials → +100 food and +50 materials every 30 minutes.

### 1.2 Resource Generation — Champignonnière (Mushroom Farm)

The Champignonnière produces food passively every 24 hours.

**Formula (approximate):**
```
daily_food = 122 × 1.7^(level - 1)   (rounded)
```

| Level | Daily Food | Level | Daily Food |
|-------|-----------|-------|-----------|
| 1 | 122 | 10 | 14,515 |
| 2 | 208 | 15 | 206,094 |
| 3 | 354 | 20 | 2,926,247 |
| 4 | 601 | 25 | 41,548,517 |
| 5 | 1,022 | 30 | 589,929,532 |
| 6 | 1,738 | 35 | 8,376,155,759 |
| 7 | 2,954 | 40 | 118,929,433,873 |
| 8 | 5,023 | 45 | 1,688,627,891,904 |
| 9 | 8,538 | 50 | 23,976,101,327,146 |

Growth factor: ~×1.70 per level (compounding).

### 1.3 Resource Consumption — Army Upkeep

Military units consume food daily:
- **Inside the anthill** (fourmilière): **10%** of their food cost per day
- **Outside** (hunting, attacking, TDC defense): **5%** of their food cost per day
- If food runs out: **0.5%** of army dies every 30 minutes

Cost is distributed evenly throughout the day (prorated per tick).

### 1.4 Resource Storage — Entrepôts (Warehouses)

Two separate warehouses with identical mechanics but different resources.

| Parameter | Value |
|-----------|-------|
| Base capacity (level 0) | 1,700 |
| Capacity at level N | 1,700 × 2^N (doubles each level) |
| Cost at level N (materials) | 600 × 2^(N-1) (for N ≥ 1) |
| Time at level N | ~3 min × 1.6^(N-1) |

| Level | Capacity | Material Cost | Build Time |
|-------|----------|--------------|------------|
| 0 | 1,700 | — | — |
| 1 | 2,900 | 600 | 3m |
| 2 | 5,300 | 1,200 | 4m 48s |
| 3 | 10,100 | 2,400 | 7m 41s |
| 5 | 38,900 | 9,600 | 19m 40s |
| 10 | 1,229,300 | 307,200 | 3h 26m |
| 20 | 1,258,291,700 | 314,572,800 | 15d 17h |
| 30 | 1,288,490,189,300 | 322,122,547,200 | 328d 17h |
| 40 | 1,319,413,953,331,700 | 329,853,488,332,800 | 1,544d |
| 50 | 1,351,079,888,211,149,300 | 337,769,972,052,787,200 | 4,796d |

**Formula:** `capacity(level) = 1700 × 2^level`, `cost(level) = 600 × 2^(level-1)`

### 1.5 Resource Pillaging

When attacking another anthill successfully:
- **TDC attack**: Gain 20% of defender's TDC (capped at 1 cm² per attacking ant)
- **Fourmilière attack**: Gain 30% + 1%/level (Étable à pucerons) of defender's stored food and materials (capped at 1 resource per attack point of surviving army)
- **Colonization (Loge Impériale)**: Colonizer receives 20% + 1%/level (Étable à pucerons) of all future resource income of the colonized player

---

## 2. Room/Building Mechanics

### 2.1 Complete Building List (13 buildings)

| # | Building | Function | Scaling |
|---|----------|----------|---------|
| 1 | Champignonnière | Daily passive food | +70% food/level |
| 2 | Entrepôt de nourriture | Food storage capacity | ×2 capacity/level |
| 3 | Entrepôt de matériaux | Material storage capacity | ×2 capacity/level |
| 4 | Couveuse | Laying speed | +10% speed/level |
| 5 | Solarium | Laying speed | +10% speed/level |
| 6 | Laboratoire | Unlocks research | Enables research tree |
| 7 | Salle d'analyse | Research speed | -10% time/level |
| 8 | Salle de combat | Unlocks military units | Progressive unlocks |
| 9 | Caserne | Unlocks military units | Progressive unlocks |
| 10 | Dôme | Defense bonus | 10% + 5%/level |
| 11 | Loge Impériale | Defense bonus + colonization target | 30% + 15%/level |
| 12 | Étable à pucerons | Loot capacity | +1% pillage, +5% trade/level |
| 13 | Étable à cochenilles | Unit XP gain | +10% units progress/level |

### 2.2 Building Leveling Algorithm

Each building level **costs materials only** (no food, no workers), except tier-2 buildings (Salle de combat, Caserne, Dôme, Loge Impériale) which also cost food and workers.

#### 2.2.1 Simple Buildings (Couveuse, Solarium, Laboratoire, etc.)

These follow a clean exponential: **cost doubles each level**.

```
materials_cost(level) = base_cost × 2^(level - 1)
build_time(level)     = base_time × 1.6^(level - 1)
```

| Building | Base Cost (lvl 1) | Base Time (lvl 1) |
|----------|-------------------|-------------------|
| Couveuse | 2,000 materials | 16m 40s |
| Solarium | 1,400 materials | 5m |
| Laboratoire | 300 materials | 2m |
| Salle d'analyse | 800 materials | 3m 20s |
| Étable à pucerons | 100 materials | 3m 20s |
| Étable à cochenilles | 80 materials | 2m |

#### 2.2.2 Champignonnière (Special Scaling)

Uses a higher multiplier than doubling:

```
materials_cost(level) ≈ 90 × 1.85^(level - 1)   (rounded)
build_time(level)     ≈ 2 min × 1.6^(level - 1)
food_production(level) ≈ 122 × 1.70^(level - 1)  (rounded)
```

#### 2.2.3 Tier-2 Buildings (Salle de combat, Caserne, Dôme, Loge Impériale)

These cost materials + food + workers, all doubling each level:

| Building | Mat (lvl 1) | Food (lvl 1) | Workers (lvl 1) | Time (lvl 1) |
|----------|-------------|--------------|-----------------|-------------|
| Salle de combat | 2,500 | 4,000 | 50 | 3m 20s |
| Caserne | 5,000 | 8,000 | 100 | 3m 20s |
| Dôme | 10,000 | 16,000 | 200 | 3m 20s |
| Loge Impériale | 20,000 | 32,000 | 400 | 3m 20s |

All three costs ×2 per level for these buildings.

#### 2.2.4 Entrepôts (Warehouses)

| Parameter | Formula |
|-----------|---------|
| Materials cost | 600 × 2^(level-1) |
| Storage capacity | 1,700 × 2^level |
| Build time | 3 min × 1.6^(level-1) |

### 2.3 Time Formula Detail

Build times use a compound multiplier of approximately ×1.6 per level for all buildings. The game computes time in seconds and displays cumulative durations:

```
time_seconds(level) = base_seconds × 1.6^(level - 1)
```

Reduced by the Architecture research: `effective_time = base_time × (1 - 0.10 × architecture_level)`, capped at some minimum.

### 2.4 Prerequisites

Buildings have warehouse level prerequisites:
- Champignonnière requires Entrepôt de matériaux at least level = Champignonnière_level - 1 above level 5
- Higher-level buildings require progressively higher warehouse levels

### 2.5 Anthill Level Calculation

```
niveau_fourmilière = sum of all building levels across all 13 buildings
```

1 point per building level. This determines ranking and matchmaking.

---

## 3. Research Mechanics

### 3.1 Research List (10 researches)

| # | Research | Effect | Scaling |
|---|----------|--------|---------|
| 1 | Technique de ponte | Laying speed | +10%/level |
| 2 | Bouclier Thoracique | Unit HP | +10%/level |
| 3 | Armes | Unit damage | +10%/level |
| 4 | Architecture | Unlocks buildings, reduces build time | -10% time/level |
| 5 | Vitesse de chasse | Reduces hunt time, +1 simultaneous hunt/level | -10% time/level |
| 6 | Vitesse d'attaque | Reduces attack time, reduces convoy time | -10%/level |
| 7 | Communication animaux | Unlocks units, buildings, researches | Progressive |
| 8 | Génétique | Unlocks units, buildings, researches | Progressive |
| 9 | Acide | Unlocks units, buildings, researches | Progressive |
| 10 | Poison | Unlocks units, buildings, researches | Progressive |

### 3.2 Research Costs

Research costs scale with level using three resources: workers, food, and materials. Using Bouclier Thoracique as a representative example:

```
worker_cost(level) ≈ base_workers × 2^(level - 1)
food_cost(level)   ≈ base_food × 2.5^(level - 1)
materials_cost(level) ≈ base_materials × 1.5^(level - 1)
time(level)        ≈ base_time × 1.6^(level - 1)
```

Research Time is reduced by the Salle d'analyse: `effective_time = base_time × (1 - 0.10 × salle_analyse_level)`.

### 3.3 Technology Points

```
points_technologie = total number of completed research levels
```

Simple count — 1 point per research level completed.

---

## 4. Laying (Ponte) Mechanics

### 4.1 Base Laying Time

Each unit type has a base laying time. The queen lays eggs that hatch after the specified duration.

### 4.2 Laying Speed Bonuses

Two buildings and one research affect laying speed:

- **Couveuse**: +10% speed per level
- **Solarium**: +10% speed per level
- **Technique de ponte**: +10% speed per level

**Formula:**
```
effective_laying_speed = 1 + 0.10 × (couveuse_level + solarium_level + technique_ponte_level)
effective_laying_time = base_time / effective_laying_speed
```

All three bonuses stack additively then divide the base time.

### 4.3 Worker Cost

Workers cost **5 food** each (base). Military units have their own food costs.

---

## 5. Terrain de Chasse (TDC) Mechanics

### 5.1 TDC as Resource Cap

- Starting TDC: 50 cm²
- Max workers working = TDC size (1 worker/cm²)
- TDC directly caps resource income rate

### 5.2 TDC Expansion — Hunting

Hunting sends combat units against wild predators. Success adds the targeted cm² to TDC.

- Hunt time depends on current TDC size and target area
- Reduced by Vitesse de chasse research (-10%/level)
- Multiple simultaneous hunts = 1 + vitesse_de_chasse_level

### 5.3 TDC Expansion — PvP Attack

Attacking another player's TDC:
- Win → gain 20% of defender's TDC (capped at 1 cm² per attacking ant)
- Loss → attacker gains nothing, loses army

### 5.4 TDC Defense Loss

When defending TDC is attacked and army is defeated:
- Lose **20%** of TDC surface
- Same 1 cm² per attacker cap applies

### 5.5 TDC Attack Range

Can only attack players whose TDC is **50% to 300%** of your own TDC.

---

## 6. Defense & Combat Mechanics

### 6.1 Defense Bonuses

| Building | Base Bonus | Per Level |
|----------|-----------|-----------|
| Dôme | 10% | +5% |
| Loge Impériale | 30% | +15% |

```
dome_defense = 10% + 5% × dome_level
loge_defense = 30% + 15% × loge_level
```

Dôme bonus applies when defending the fourmilière. Loge bonus applies when defending the Loge Impériale.

### 6.2 Pillage Capacity

```
pillage_percent = 30% + 1% × etable_pucerons_level
trade_capacity_bonus = 5% × etable_pucerons_level  (per level)
```

Pillage is capped at 1 resource per attack point of surviving army.

### 6.3 Unit XP Gain

```
units_gaining_xp_bonus = 10% × etable_cochenilles_level
```

Increases the number of military units that gain experience from combat each level.

### 6.4 Colonization Income

Colonizer receives from colonized player:
```
colony_tax = 20% + 1% × etable_pucerons_level
```
Applied to all resource income (worker harvest + champignonnière) of the colonized player.

---

## 7. Army Upkeep

| Location | Daily Food Cost |
|----------|----------------|
| Inside anthill | 10% of unit food cost |
| Outside (hunt/attack/TDC) | 5% of unit food cost |
| No food available | 0.5% of army dies per 30 min |

---

## 8. Key Progression Curves Summary

```
┌─────────────────────┬──────────────────────────────────┐
│ Mechanism           │ Formula                          │
├─────────────────────┼──────────────────────────────────┤
│ Worker harvest      │ 1 resource/worker/30min          │
│ Champignonnière     │ 122 × 1.70^(lvl-1) food/day     │
│ Warehouse capacity  │ 1,700 × 2^level                  │
│ Simple building cost│ base × 2^(lvl-1) materials       │
│ Champignonnière cost│ ~90 × 1.85^(lvl-1) materials     │
│ Build time          │ base × 1.6^(lvl-1)               │
│ Research cost       │ workers ×2, food ×2.5, mat ×1.5  │
│ Laying speed        │ 1 + 0.10 × sum(couveuse, solarium, tech_ponte) │
│ Defense (Dôme)      │ 10% + 5% × level                 │
│ Defense (Loge)      │ 30% + 15% × level                │
│ Pillage %           │ 30% + 1% × étab_pucerons_level   │
│ Colony tax %        │ 20% + 1% × étab_pucerons_level   │
│ Anthill level       │ Σ(all building levels)           │
│ Tech points         │ Σ(all research levels)           │
└─────────────────────┴──────────────────────────────────┘
```

---

## 9. Notes & Limitations

- **Server variance**: Cost tables may differ slightly across servers (s1-s4, test). Data from s3 (toolzzz.fr).
- **Rounding**: All game values are integers; formulas produce approximations. The game uses floor/round at each step.
- **Research cost sources**: Research cost formulas are inferred from toolzzz tables; exact server-side formulas are not publicly documented.
- **Architecture research**: Reduces build time by 10%/level but the exact cap/floor is not documented.
- **Maximum levels**: Buildings appear to go to at least level 50; research to at least level 50. No hard cap confirmed.
- **Missing data**: Unit-specific laying times, combat damage formulas, and predator stats are beyond the scope of this analysis (focused on resources and rooms).