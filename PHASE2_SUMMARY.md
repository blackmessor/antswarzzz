# Antswarzzz — Phase 2 Summary

> **Completed**: 30 August 2026
> **Status**: ✅ Done — all Phase 2 features live

## What Phase 2 Added (Expansion)

### All 13 Buildings
- Colonies now start with all 13 building types at level 0
- `POST /api/colony/{id}` action `upgrade_building` with `building_type_id`
- Cost formulas implemented per category:
  - **A** (simple): materials × 2^(level-1)
  - **B** (mushroom): materials × 1.85^(level-1), production × 1.70^(level-1)
  - **C** (combat/dome/barracks): materials + food + workers, ×2 per level
  - **D** (warehouse): capacity 1700 + 1200×(2^level-1), cost 600×2^(level-1)

### Breeding System
- `POST /api/breeding/{colony_id}` action `queue` with `ant_type_id`
- Active breed position 1 starts immediately (deducts food, sets timer)
- Queue support: position 2+ wait for active breed to complete
- Tick engine decrements breed timer and auto-hatches ants
- Auto-advances queue after hatch
- Verified: JSN bred successfully (300s timer → 0 after 1800s tick)

### Research System (first 6 techs)
- `POST /api/research/{colony_id}` action `start` with `research_type_id`
- Techs available: 1=Tecnique de Ponte, 2=Bouclier Thoracique, 3=Armes, 4=Architecture, 5=Vitesse de Chasse, 6=Vitesse d'Attaque
- Cost scaling per level: workers ×2, food ×2.5, materials ×1.5, time ×1.6
- Tick engine decrements research timer and auto-completes
- Verified: tech_ponte completed (600s timer → 0 after 1800s tick)

### Evolution Engine
- XP pool tracked per ant type per colony
- XPPerEvolution = 100
- SN→NE, S→SE, C→CE, Tk→TkE, Tu→TuE
- Tick engine auto-evolves ants when cumulative_xp ≥ 100

### Army Upkeep
- 1 food per military ant per tick
- Tick engine deducts upkeep from food resources
- Famine: food clamped to 0 (never negative)

### Bugfix: UNSIGNED timer overflow
- All timer columns (`INT UNSIGNED`) now use `CAST(timer AS SIGNED)` before subtraction
- Fixes MariaDB error 1690 when 300 - 1800 overflows

### API Endpoints Added
| Method | Path | Action | Purpose |
|--------|------|--------|---------|
| POST | `/api/colony/{id}` | `upgrade_building` | Start building construction |
| POST | `/api/breeding/{id}` | `queue` | Queue ant for breeding |
| POST | `/api/research/{id}` | `start` | Start research project |
| POST | `/api/tick` | (unchanged) | Now processes breed+research+evolution+upkeep |

### Enriched GET /api/colony/{id}
Now returns: `breed_queue`, `active_breed`, `research`, `military_count` in addition to previous fields.

### Files Modified
- `server/internal/database/db.go` — +285 lines (breed, research, evolution, upkeep methods)
- `server/internal/tick/tick.go` — merged processColony with full Phase 2 logic
- `server/internal/models/models.go` — EvolutionResult, EvolutionTarget, ResearchCost/Time, CategoryC formulas
- `server/internal/api/handlers.go` — rewritten: breeding + research endpoints added
- `server/internal/database/db.go` — colony creation now seeds all 13 buildings + 10 research slots

### Verified Tests
```
POST /api/player/register → colony with 13 buildings + 10 research slots ✅
POST /api/colony/1 upgrade_building (mushroom farm) → level 1 ✅
POST /api/breeding/1 queue JSN → active breed, timer 300s ✅
POST /api/tick colony 1 → JSN hatched (0→1 ant) ✅
POST /api/research/1 start tech_ponte → cost 200 food, 100 mats ✅
POST /api/tick colony 1 → tech_ponte level 1 ✅
GET /api/colony/1 → full state with breed_queue, research, military ✅
```

### Remaining (Phase 3 →)
- Combat engine (50-round deterministic)
- TDC hunting (PvE)
- Death order + defense bonuses
- No iOS client yet