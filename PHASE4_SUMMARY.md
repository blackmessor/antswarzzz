# Antswarzzz — Phase 4 Summary

> **Completed**: 30 August 2026
> **Status**: ✅ Done — PvP attacks, pillage, matchmaking, colonization

## What Phase 4 Added (Multiplayer)

### PvP Attack Engine
- Combat resolution reused from Phase 3 engine (50 rounds, death order, target switching)
- TDC transfer: winner gains 20% of defender's TDC (capped at 1cm² per surviving attacker)
- Pillage: 30% + 1%/aphid farm level of defender resources, capped by surviving army attack power
- Auto-colonization when defender TDC reaches 0 (colony captured)
- Travel time: `60 + |tdc_diff| * 2` seconds, reduced by Vitesse d'Attaque research (min 10%)

### Matchmaking
- `CanAttack(attackerTDC, defenderTDC)`: validates target within 50%-300% range
- `GetAttackTargets()`: SQL query with TDC range filter, ordered by closest match
- Prevents attacking colonized targets (already vassals)
- Cooldown structure in place (24h, stored via attacks table status)

### Colonization
- Requires Loge Impériale level ≥ 1
- Tax rate: 20% + 1%/aphid farm level
- Colonizer ID + tax rate stored in `colonizations` table
- `GetColonizer(colonyID)` / `GetVassals(colonizerID)` for tax calculation
- Auto-colonization on PvP colony capture

### API Endpoints Added
| Method | Path | Action | Purpose |
|--------|------|--------|---------|
| POST | `/api/pvp/{id}` | `targets` | Get 15 best matchmaking targets |
| POST | `/api/pvp/{id}` | `attack` | Launch PvP attack with ant army |
| POST | `/api/pvp/{id}` | `resolve` | Force-resolve pending attacks |
| POST | `/api/pvp/{id}` | `colonize` | Establish colonization with tax rate |

### Tick Engine Integration
- `AdvanceAttackTimers()` decrements all active attack timers
- Completed attacks auto-resolve: combat → TDC transfer → pillage → return survivors
- Auto-colonization on full TDC capture

### New Files
- `server/internal/combat/pvp.go` — PvPAttackResult, ResolvePvPAttack, matchmaking, colonization tax
- `server/internal/combat/combat_test.go` — 4 unit tests (combat, hunt, matchmaking, tax)

### Modified Files
- `server/internal/database/db.go` — +190 lines (StartPvPAttack, GetActiveAttacks, AdvanceAttackTimers, ResolveAttack, GetAttackTargets, Colonize, GetColonizer, GetVassals)
- `server/internal/api/handlers.go` — +225 lines (handlePvP: targets, attack, resolve, colonize)
- `server/internal/tick/tick.go` — +70 lines (resolvePvPAttack, Phase 4 integration)

### Verified End-to-End
```
Targets: colony 2 found (same TDC range) ✅
POST /api/pvp/1 attack → attack_id=1, timer=60s ✅
POST /api/pvp/1 resolve → attacker wins, 7 rounds ✅
  TDC: +10 attacker (50→60), -10 defender (50→40) ✅
  Pillage: 51 food + 51 mats stolen ✅
POST /api/pvp/1 colonize → colony 2 colonized at 20% tax ✅
```

### Unit Tests (4/4 pass)
```
TestResolveCombat    — attackers win, < 10 rounds
TestResolveHunt       — 15 JSN vs 25 predators → win, TDC+10
TestCanAttack         — range validation (50%-300%)
TestColonizationTax   — base 20%, scales with aphid farm
```

### Remaining (Phase 5 →)
- Unit-unlocking techs (Génétique→Tank, Acide→Artilleuse, Poison→Tueuse)
- Full technology dependency graph
- Balance tuning
- iOS client UI + Polish