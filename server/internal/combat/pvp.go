package combat

// ── Phase 4: PvP attack resolution ──

import (
	"github.com/antswarzzz/server/internal/models"
)

type PvPAttackResult struct {
	AttackerWins        bool
	SurvivorsAttackers  []CombatUnit
	SurvivorsDefenders  []CombatUnit
	RoundsFought        int

	// If attacker wins:
	TDCLost            int64  // TDC lost by defender
	TDCLostToAttacker  int64  // TDC gained by attacker
	FoodStolen         int64
	MaterialsStolen    int64
	ColonyCaptured     bool   // if defender had 0 TDC after loss

	// If defender wins:
	TDCLostByAttacker  int64
}

// ResolvePvPAttack executes PvP combat with pillage + TDC transfer
func ResolvePvPAttack(
	attackUnits []CombatUnit,
	defenderUnits []CombatUnit,
	defenderTDC int64,
	defenderFood int64,
	defenderMats int64,
	aphidFarmLevel int,
	attackerHasLodge bool,
	lodgeLevel int,
) PvPAttackResult {
	// Phase 1: Combat
	combatResult := resolve(attackUnits, defenderUnits)

	result := PvPAttackResult{
		SurvivorsAttackers: combatResult.SurvivorsAttackers,
		SurvivorsDefenders: combatResult.SurvivorsDefenders,
		RoundsFought:       combatResult.RoundsFought,
	}

	if !combatResult.AttackerWins {
		// Defender wins: attacker loses combat ants (already lost in resolve)
		attackerSurvivors := CountSurvivors(combatResult.SurvivorsAttackers)
		_ = attackerSurvivors // tracked via survivors list
		return result
	}

	result.AttackerWins = true

	// Phase 2: TDC transfer (20% of defender TDC, capped at 1cm² per surviving attacker)
	survivorCount := CountSurvivors(combatResult.SurvivorsAttackers)
	tdcGain := int64(float64(defenderTDC) * 0.20)
	if tdcGain < 1 {
		tdcGain = 1
	}
	if tdcGain > survivorCount {
		tdcGain = survivorCount
	}
	result.TDCLost = tdcGain
	result.TDCLostToAttacker = tdcGain

	// Check if defender loses all TDC → colony captured
	result.ColonyCaptured = (defenderTDC - tdcGain <= 0)

	// Phase 3: Pillage (30% + 1%/aphid level)
	pillagePercent := 0.30 + 0.01*float64(aphidFarmLevel)
	result.FoodStolen = int64(float64(defenderFood) * pillagePercent)
	result.MaterialsStolen = int64(float64(defenderMats) * pillagePercent)

	// Capped by surviving army total attack
	totalAttack := int64(0)
	for _, u := range combatResult.SurvivorsAttackers {
		totalAttack += int64(u.BaseAtk)
	}
	if result.FoodStolen > totalAttack {
		result.FoodStolen = totalAttack
	}
	if result.MaterialsStolen > totalAttack {
		result.MaterialsStolen = totalAttack
	}

	return result
}

// ── Matchmaking ──

const (
	TDCRatioMin    = 0.50
	TDCRatioMax    = 3.00
	CooldownHours  = 24
)

// CanAttack returns true if attacker can target defender based on TDC range
func CanAttack(attackerTDC, defenderTDC int64) bool {
	minTDC := int64(float64(attackerTDC) * TDCRatioMin)
	maxTDC := int64(float64(attackerTDC) * TDCRatioMax)
	return defenderTDC >= minTDC && defenderTDC <= maxTDC
}

// AttackTravelTime returns seconds until attack resolves (simplified formula)
func AttackTravelTime(attackerTDC, defenderTDC int64, vitesseAttaqueLevel int) int64 {
	base := int64(60 + abs(defenderTDC-attackerTDC)*2)
	reduction := 1.0 - 0.10*float64(vitesseAttaqueLevel)
	if reduction < 0.10 {
		reduction = 0.10
	}
	return int64(float64(base) * reduction)
}

func abs(x int64) int64 {
	if x < 0 {
		return -x
	}
	return x
}

// ── Colonization tax ──

const (
	ColonyTaxBase      = 0.20
	ColonyTaxPerLevel  = 0.01
)

func ColonizationTax(aphidFarmLevel int) float64 {
	return ColonyTaxBase + ColonyTaxPerLevel*float64(aphidFarmLevel)
}

// ── Apply colony tax to harvester income ──

func ApplyTax(foodHarvested, matHarvested int64, taxRate float64) (taxFood, taxMats int64) {
	taxFood = int64(float64(foodHarvested) * taxRate)
	taxMats = int64(float64(matHarvested) * taxRate)
	return
}

// BuildCombatUnitsFromDB takes colony ants and builds CombatUnits with research bonuses
func BuildCombatUnitsFromDB(
	ants []models.ColonyAnt,
	bouclierLevel, armesLevel int,
) []CombatUnit {
	bonuses := CombatBonuses{
		TechBouclierLevel: bouclierLevel,
		TechArmesLevel:    armesLevel,
	}
	return BuildCombatUnits(ants, bonuses)
}