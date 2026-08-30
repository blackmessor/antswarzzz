# Antswarzzz — Phase 3 Summary

> **Completed**: 30 August 2026
> **Status**: ✅ Done — combat engine + PvE hunts live

## What Phase 3 Added (Combat)

### Deterministic Combat Engine (`internal/combat/combat.go`)
- 50-round max combat with death order sorting
- Target switching: when one defender dies, attackers redirect to the next weakest
- Damage formula: `max(1, attacker_ATK - defender_DEF)`
- Research bonuses applied: Bouclier Thoracique (+10% HP/level), Armes (+10% ATK/level)
- Defense building bonuses: Dôme (+10%+5%/lvl), Loge Impériale (+30%+15%/lvl)
- Weapons HP multiplication for home defense location

### PvE Hunting
- `POST /api/hunt/{colony_id}` — two actions:
  - `start` with `ants: [{ant_type_id, count}]` — sends ants to hunting, starts timer
  - `resolve` — force-resolves combat immediately (test/dev)
- Predator count: `TDC / 2` (~25 predators for TDC 50)
- Predator stats: HP=5, ATK=3, DEF=1 (simplified wild enemies)
- On victory: TDC gains 20% of colony's current TDC
- XP awarded to top surviving performers (proportional to count)
- Surviving ants return home automatically
- Vitesse de Chasse research reduces hunt timer

### Tick Engine Integration
- Hunt timers decrement every tick (30 min)
- Completed hunts auto-resolve: combat calculation + TDC update + XP award
- Ants automatically returned home after hunt resolution
- Bugs squashed: UNSIGNED timer overflow (same CAST fix as Phase 2)

### New Files
- `server/internal/combat/combat.go` — 330 lines: CombatUnit, CombatResult, HuntResult, resolve(), ResolveHunt(), defense/applied bonuses
- `server/internal/database/db.go` — +150 lines: StartHunt, GetActiveHunts, AdvanceHuntsTimer, CompleteHunt, MoveAntsToLocation, ReturnAntsHome, UpdateTDC
- `server/internal/api/handlers.go` — +170 lines: handleHunt endpoint (start + resolve actions)
- `server/internal/tick/tick.go` — +35 lines: hunt processing in colony tick, helper functions

### Verified End-to-End
```
POST /api/hunt/2 start 15 JSN → hunt_id=4, timer=1800s
POST /api/hunt/2 resolve → won=true, rounds=8, tdc_gained=10
GET /api/colony/2 → TDC=60 (+10), 7 JSN survivors gained 10 XP each ✅
```

### API Endpoints Added (Phase 3)
| Method | Path | Action | Purpose |
|--------|------|--------|---------|
| POST | `/api/hunt/{id}` | `start` | Send ants on PvE hunt |
| POST | `/api/hunt/{id}` | `resolve` | Force-resolve hunt (test) |

### Remaining (Phase 4 →)
- PvP TDC attacks + pillaging
- Colonization (vassalization + tax)
- Matchmaking (TDC 50%-300% range)