# Antswarzzz

An iOS ant colony strategy game inspired by Foumizzz — a real-time, tick-based simulation
where players manage an underground anthill, breed worker and military ants, harvest
resources, research technologies, and expand territory through PvE hunts and PvP combat.

## Project Summary

Antswarzzz is a persistent mobile strategy game built around the classic Foumizzz formula:

- **Resources**: Food and materials, harvested by worker ants assigned to hunting territory (TDC)
- **13 Buildings**: Hatchery, solarium, lab, warehouses, mushroom farm, combat rooms, barracks, defense structures, and more — each with exponential scaling formulas
- **15 Ant Types**: From basic Ouvriere workers through elite Tanks and Tueuse assassins, with an XP-based evolution system
- **10 Research Technologies**: Breeding speed, unit stats, building time, combat, and unit unlocks — gated by a dependency tree
- **Combat**: Deterministic round-based combat with death-order targeting and defense bonuses
- **Multiplayer**: TDC attacks, pillaging, colonization with tax mechanics
- **Tick Engine**: Every 30 minutes the server processes resource generation, construction timers, breeding progress, research, and upkeep

The game is specified for iOS implementation in Swift, structured for iterative development
across 5 implementation phases (Core Loop → Expansion → Combat → Multiplayer → Polish).

## Workspace Structure

```
antswarzzz/
├── README.md                       # This file — project overview and developer guide
├── specs/
│   └── cahier_des_charges.md       # Complete game design specification (974 lines)
│                                   #   All formulas, constants, algorithms, and data models
└── analysis/
    ├── resources_rooms.md          # Resource mechanics and building system analysis
    └── ants_tech.md                # Ant types and technology tree analysis
```

## How to Use This Specification for iOS Development

### 1. Start Here

Read `specs/cahier_des_charges.md` in full before writing any code. Every game mechanic
is documented with:
- Explicit formulas using named constants
- `floor()` rounding applied to all computed values
- Trigger conditions (when a mechanic fires)
- Input parameters and output effects
- Pseudocode algorithms for the tick engine, combat, breeding, and evolution

### 2. Reference Materials

The `analysis/` directory contains the original Fourmizzz research that informed the spec:
- `resources_rooms.md` — deeper data tables and progression curves for cross-referencing
- `ants_tech.md` — unit stat sources and technology dependency chain documentation

### 3. Implementation Order

Follow the 5-phase roadmap in Appendix B of the specification:

| Phase | Focus | Key Deliverables |
|-------|-------|-----------------|
| 1 — Core Loop (MVP) | Resources, workers, TDC, simple buildings, basic ants, tick engine | Playable colony simulation |
| 2 — Expansion | All 13 buildings, remaining ant types, research, evolution, upkeep | Full simulation breadth |
| 3 — Combat | Combat engine, PvE hunts, death order, defense bonuses | Single-player combat |
| 4 — Multiplayer | PvP attacks, pillaging, colonization, matchmaking | Networked gameplay |
| 5 — Polish | Unit-unlocking techs, balance tuning, UI/UX | Ship-quality product |

### 4. Key Technical Decisions

- **All resource math uses integers**: Every formula applies `floor()`. No floats for currency.
- **Tick interval is 30 minutes (1800s)**: The heartbeat. All timers decrement by this amount.
- **Construction and research timers are real-time**: Players wait. Architecture and Analysis Room research reduce them.
- **Combat is deterministic**: No RNG. Damage = max(1, attacker_atk − defender_def).
- **Death order is fixed**: Weakest units die first. JSN is the cheapest meat shield.

### 5. Swift Data Models

Appendix A of the specification provides suggested Swift structs (`Resources`, `Building`,
`AntType`, `Ant`, `Research`, `Colony`). Use `Codable` for persistence and network
serialization. Expect to augment with CloudKit or a custom backend for multiplayer sync.

### 6. Formula Verification

Every formula in the spec can be verified by computing the example data tables (e.g.,
warehouse capacity at level 10 should be 1,229,300). Before building the tick engine,
write unit tests that assert known values at sample levels.

---

*Specification version 1.0 — August 2026. Last reviewed for correctness 2026-08-30.*