# Antswarzzz — Phase 5 Summary

> **Completed**: 30 August 2026
> **Status**: ✅ Done — tech tree, prerequisites, missing formulas

## What Phase 5 Added (Polish)

### Full Technology Dependency Graph
- 10 research types all accessible (was 6 in Phase 2)
- Prerequisites enforced before research can start:
  - **Communication Animaux (7)** → requires Architecture level 1
  - **Génétique (8)** → requires Armes level 5
  - **Acide (9)** → requires Génétique level 3
  - **Poison (10)** → requires Acide level 5
- Validation in API: `models.CheckTechPrerequisites(techID, level, currentResearch)`

### Unit Unlock System
- Techs unlock ant types for breeding:
  - Communication Animaux → Concierge (C)
  - Génétique → Tank (Tk)
  - Acide → Artilleuse (A) + Artilleuse d'Élite (AE)
  - Poison → Tueuse (Tu)
- Building prerequisites also validated:
  - JSN: combat_room 1
  - SN: combat_room 3
  - JS: combat_room 5
  - S: barracks 1
  - Tk: barracks 22
- `CheckAntBreedingAllowed()` validates both building + research requirements

### Missing Formulas Added
- Outside upkeep: 5% per day (0.10/48 per tick) for hunting/attacking ants
- Starvation: 0.5% of military ants die per tick when food=0
- Mealybug farm XP bonus: +10% units gaining XP per level
- XP slots formula: `BaseUnitsGainingXP × (1 + 0.10 × mealybug_level)`
- Building slug→ID mapping for prerequisite lookups

### Files Modified
- `server/internal/api/handlers.go` — research limit 6→10, prerequisite validation in research + breeding
- `server/internal/models/models.go` — +130 lines: TechPrerequisites, TechUnlocks, CheckTechPrerequisites, IsUnitUnlocked, CheckAntBreedingAllowed, XPSlots, StarvationDeaths, OutsideUpkeepFood, InsideUpkeepFood, BuildingSlugToID

### Verified Tests
```
JSN breed after combat_room 1 → ✅ unlocked
Tank breed without barracks 22 → ❌ "building requirement not met" ✅
Tank breed without Génétique → ❌ "research requirement not met" ✅
Génétique without Armes 5 → ❌ "prerequisites not met" ✅
Acide without Génétique 3 → ❌ "prerequisites not met" ✅
After Armes 5 → Génétique 1 → Tank breed → ✅ unlocked ✅
```

### All 5 Phases Complete

| Phase | Content | Status |
|-------|---------|--------|
| 1 | Harvest + 4 buildings + tick engine | ✅ |
| 2 | 13 buildings + breeding + 6 techs + evolution + upkeep | ✅ |
| 3 | Combat engine + PvE hunts + death order + defense bonuses | ✅ |
| 4 | PvP attacks + pillage + colonization + matchmaking | ✅ |
| 5 | Full tech tree (10) + unit unlocks + prerequisites + polish formulas | ✅ |

### Server Stats
- 8 Go source files, ~3,500 lines
- 13 REST API endpoints
- 4 unit tests passing
- 18 MariaDB tables
- Tick engine: harvest, breeding, research, construction, hunts, attacks, evolution, upkeep, colonization tax
- All formulas from spec implemented with explicit constants and floor rounding