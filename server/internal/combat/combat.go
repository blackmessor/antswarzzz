package combat

import (
	"sort"

	"github.com/antswarzzz/server/internal/models"
)

const (
	MaxCombatRounds   = 50
	MinDamage         = 1
	XPPerCombat       = 10
	BaseUnitsGainingXP = 10
	HuntTDCRatio      = 0.20 // 20% of attacker's TDC on successful hunt
	HuntBaseTimer     = 3600 // 1 hour base
)

// ── Unit representation for combat ──

type CombatUnit struct {
	AntTypeID  int
	Count      int64
	BaseHP     int
	BaseAtk    int
	BaseDef    int
	CurrentHP  int
	DeathOrder int
}

// ── Research bonuses to apply ──

type CombatBonuses struct {
	TechArmesLevel       int // +10% attack per level
	TechBouclierLevel    int // +10% HP per level
	DomeLevel            int // +10% + 5%/lvl defense HP
	ImperialLodgeLevel   int // +30% + 15%/lvl defense HP
}

// ── Build combat units from colony ants ──

func BuildCombatUnits(ants []models.ColonyAnt, bonuses CombatBonuses) []CombatUnit {
	// Static ant type stats (matching init.sql)
	stats := map[int]struct{ hp, atk, def, deathOrder int }{
		1:  {8, 3, 2, 2},    // JSN
		2:  {10, 5, 4, 3},   // SN
		3:  {13, 7, 6, 4},   // NE
		4:  {16, 10, 9, 5},  // JS
		5:  {20, 15, 14, 6}, // S
		6:  {27, 24, 23, 12}, // SE
		7:  {30, 1, 25, 7},  // C
		8:  {40, 1, 35, 8},  // CE
		9:  {10, 30, 15, 9}, // A
		10: {12, 35, 18, 10}, // AE
		11: {35, 55, 1, 11}, // Tk
		12: {50, 80, 1, 13}, // TkE
		13: {50, 50, 50, 14}, // Tu
		14: {55, 55, 55, 15}, // TuE
	}

	var units []CombatUnit
	for _, a := range ants {
		if a.Count <= 0 || a.AntTypeID == 0 { // skip workers
			continue
		}
		s, ok := stats[a.AntTypeID]
		if !ok {
			continue
		}

		hp := s.hp
		atk := s.atk
		def := s.def

		// Apply research bonuses
		hp += int(float64(hp) * 0.10 * float64(bonuses.TechBouclierLevel))
		atk += int(float64(atk) * 0.10 * float64(bonuses.TechArmesLevel))

		// Each ant fights individually; Count = number of identical units
		for i := int64(0); i < a.Count; i++ {
			units = append(units, CombatUnit{
				AntTypeID:  a.AntTypeID,
				Count:      1,
				BaseHP:     hp,
				BaseAtk:    atk,
				BaseDef:    def,
				CurrentHP:  hp,
				DeathOrder: s.deathOrder,
			})
		}
	}
	return units
}

// ── Apply defense bonuses (Dôme, Loge Impériale) ──

func ApplyDefenseBonuses(units []CombatUnit, bonuses CombatBonuses) {
	domeMult := 1.0 + 0.10 + 0.05*float64(bonuses.DomeLevel)
	logeMult := 1.0 + 0.30 + 0.15*float64(bonuses.ImperialLodgeLevel)
	totalMult := domeMult + logeMult - 1.0 // additive

	for i := range units {
		units[i].CurrentHP = int(float64(units[i].CurrentHP) * totalMult)
	}
}

// ── Combat resolution ──

type CombatResult struct {
	AttackerWins       bool
	SurvivorsAttackers []CombatUnit
	SurvivorsDefenders []CombatUnit
	RoundsFought      int
}

func resolve(attackers, defenders []CombatUnit) CombatResult {
	atk := cloneUnits(attackers)
	def := cloneUnits(defenders)

	sortUnits(atk)
	sortUnits(def)

	for round := 1; round <= MaxCombatRounds; round++ {
		// Attackers deal damage — target switches when one dies
		for i := range atk {
			if atk[i].CurrentHP <= 0 {
				continue
			}
			def = removeDead(def)
			if len(def) == 0 {
				return CombatResult{
					AttackerWins:        true,
					SurvivorsAttackers:  filterAlive(atk),
					SurvivorsDefenders:  nil,
					RoundsFought:       round,
				}
			}
			target := &def[0]
			damage := atk[i].BaseAtk - target.BaseDef
			if damage < MinDamage {
				damage = MinDamage
			}
			target.CurrentHP -= damage
		}

		def = removeDead(def)
		if len(def) == 0 {
			return CombatResult{
				AttackerWins:        true,
				SurvivorsAttackers:  filterAlive(atk),
				SurvivorsDefenders:  nil,
				RoundsFought:       round,
			}
		}

		// Defenders deal damage — target switches when one dies
		for i := range def {
			if def[i].CurrentHP <= 0 {
				continue
			}
			atk = removeDead(atk)
			if len(atk) == 0 {
				return CombatResult{
					AttackerWins:        false,
					SurvivorsAttackers:  nil,
					SurvivorsDefenders:  filterAlive(def),
					RoundsFought:       round,
				}
			}
			target := &atk[0]
			damage := def[i].BaseAtk - target.BaseDef
			if damage < MinDamage {
				damage = MinDamage
			}
			target.CurrentHP -= damage
		}

		atk = removeDead(atk)
		if len(atk) == 0 {
			return CombatResult{
				AttackerWins:        false,
				SurvivorsAttackers:  nil,
				SurvivorsDefenders:  filterAlive(def),
				RoundsFought:       round,
			}
		}
	}

	return CombatResult{
		AttackerWins:       len(atk) > 0,
		SurvivorsAttackers: filterAlive(atk),
		SurvivorsDefenders: filterAlive(def),
		RoundsFought:      MaxCombatRounds,
	}
}

// ── Hunt resolution ──

// HuntResult returns TDC gained and XP awarded
type HuntResult struct {
	Won         bool
	TDCLost     int64
	TDCLostToWinner int64
	XPRecipients []XPRecipient
	RoundsFought int
}

type XPRecipient struct {
	AntTypeID int
	Count     int64
	XPGained  int64
}

func ResolveHunt(colonyTDC int64, attackUnits []CombatUnit, bonuses CombatBonuses) HuntResult {
	// Hunt enemies: TDC-based difficulty
	// Predator count = TDC / 2 (~25 for TDC 50)
	enemyCount := colonyTDC / 2
	if enemyCount < 5 {
		enemyCount = 5
	}
	if enemyCount > 2000 {
		enemyCount = 2000
	}

	// Create predator units (simplified: HP=5, ATK=3, DEF=1)
	predators := make([]CombatUnit, enemyCount)
	for i := range predators {
		predators[i] = CombatUnit{
			AntTypeID:  0, // predator
			Count:      1,
			BaseHP:     5,
			BaseAtk:    3,
			BaseDef:    1,
			CurrentHP:  5,
			DeathOrder: 0,
		}
	}

	result := resolve(attackUnits, predators)

	if !result.AttackerWins {
		return HuntResult{Won: false, RoundsFought: result.RoundsFought}
	}

	// TDC gain: 20% of colony's current TDC
	tdcGain := int64(float64(colonyTDC) * HuntTDCRatio)
	if tdcGain < 1 {
		tdcGain = 1
	}

	// XP awarded to top performers
	xpSlots := int64(BaseUnitsGainingXP) // simplified; mealybug bonus added later

	var recipients []XPRecipient
	typeCounts := make(map[int]int64)
	for _, u := range result.SurvivorsAttackers {
		typeCounts[u.AntTypeID]++
	}
	// XP is given proportionally to survivors
	for antType, count := range typeCounts {
		if count > xpSlots {
			count = xpSlots
		}
		recipients = append(recipients, XPRecipient{
			AntTypeID: antType,
			Count:     count,
			XPGained:  int64(XPPerCombat),
		})
	}

	return HuntResult{
		Won:            true,
		TDCLost:        enemyCount, // enemies killed = TDC "lost" by predators
		TDCLostToWinner: tdcGain,
		XPRecipients:   recipients,
		RoundsFought:   result.RoundsFought,
	}
}

// ── Helpers ──

func cloneUnits(src []CombatUnit) []CombatUnit {
	dst := make([]CombatUnit, len(src))
	copy(dst, src)
	return dst
}

func sortUnits(units []CombatUnit) {
	sort.Slice(units, func(i, j int) bool {
		return units[i].DeathOrder < units[j].DeathOrder
	})
}

func removeDead(units []CombatUnit) []CombatUnit {
	out := units[:0]
	for _, u := range units {
		if u.CurrentHP > 0 {
			out = append(out, u)
		}
	}
	return out
}

func filterAlive(units []CombatUnit) []CombatUnit {
	return removeDead(units)
}

// CountSurvivors returns total count of surviving units
func CountSurvivors(units []CombatUnit) int64 {
	var c int64
	for _, u := range units {
		if u.CurrentHP > 0 {
			c++
		}
	}
	return c
}

// Aggregated losses by ant type
func LossesByType(original, survivors []CombatUnit) map[int]int64 {
	origCounts := make(map[int]int64)
	survCounts := make(map[int]int64)
	for _, u := range original {
		origCounts[u.AntTypeID]++
	}
	for _, u := range survivors {
		survCounts[u.AntTypeID]++
	}
	losses := make(map[int]int64)
	for k, v := range origCounts {
		diff := v - survCounts[k]
		if diff > 0 {
			losses[k] = diff
		}
	}
	return losses
}