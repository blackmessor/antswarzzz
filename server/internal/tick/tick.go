package tick

import (
	"log"
	"sync"
	"time"

	"github.com/antswarzzz/server/internal/combat"
	"github.com/antswarzzz/server/internal/database"
	"github.com/antswarzzz/server/internal/models"
)

const TickInterval = models.TickIntervalSeconds * time.Second

type Engine struct {
	db        *database.DB
	stopCh    chan struct{}
	wg        sync.WaitGroup
	mu        sync.Mutex
	tickCount int64
}

func NewEngine(db *database.DB) *Engine {
	return &Engine{
		db:     db,
		stopCh: make(chan struct{}),
	}
}

func (e *Engine) Start() {
	e.wg.Add(1)
	go e.loop()
	log.Println("[tick] Engine started (interval: 30min)")
}

func (e *Engine) Stop() {
	close(e.stopCh)
	e.wg.Wait()
	log.Println("[tick] Engine stopped")
}

func (e *Engine) loop() {
	defer e.wg.Done()
	ticker := time.NewTicker(TickInterval)
	defer ticker.Stop()

	for {
		select {
		case <-ticker.C:
			e.processAllColonies()
		case <-e.stopCh:
			return
		}
	}
}

func (e *Engine) processAllColonies() {
	e.mu.Lock()
	e.tickCount++
	e.mu.Unlock()

	ids, err := e.db.GetAllActiveColonyIDs()
	if err != nil {
		log.Printf("[tick] ERROR getting colonies: %v", err)
		return
	}
	if len(ids) == 0 {
		return
	}

	log.Printf("[tick] processing %d colonies...", len(ids))

	sem := make(chan struct{}, 50)
	var wg sync.WaitGroup

	for _, id := range ids {
		wg.Add(1)
		sem <- struct{}{}
		go func(colonyID int64) {
			defer wg.Done()
			defer func() { <-sem }()
			e.processColony(colonyID)
		}(id)
	}

	wg.Wait()
}

func (e *Engine) processColony(colonyID int64) {
	colony, err := e.db.GetColony(colonyID)
	if err != nil {
		log.Printf("[tick] colony %d load error: %v", colonyID, err)
		return
	}

	buildings, err := e.db.GetColonyBuildings(colonyID)
	if err != nil {
		log.Printf("[tick] colony %d buildings error: %v", colonyID, err)
		return
	}

	result := computeTick(colony, buildings)

	// ── Military upkeep ──
	militaryCount, err := e.db.GetMilitaryAntCount(colonyID)
	if err == nil {
		result.FoodUpkeep = militaryCount
	}

	// Apply resources
	newFood := colony.Resources.Food + result.FoodHarvested + result.MushroomFood - result.FoodUpkeep
	newMats := colony.Resources.Materials + result.MaterialsHarvested
	if newFood < 0 {
		newFood = 0
	}
	if newMats < 0 {
		newMats = 0
	}
	if err := e.db.UpdateResources(colonyID, newFood, newMats); err != nil {
		log.Printf("[tick] colony %d resource update error: %v", colonyID, err)
		return
	}

	// ── Building completions ──
	for _, btID := range result.BuildingsDone {
		if err := e.db.CompleteBuilding(colonyID, btID); err != nil {
			log.Printf("[tick] colony %d building %d complete error: %v", colonyID, btID, err)
		}
	}

	// ── Breeding timer ──
	completed, antTypeID, err := e.db.AdvanceBreedTimer(colonyID, models.TickIntervalSeconds)
	if err == nil && completed {
		e.db.CompleteBreed(colonyID, antTypeID)
		result.BreedCompleted = &antTypeID
	}

	// ── Research timer ──
	researchDone, err := e.db.AdvanceResearchTimer(colonyID, models.TickIntervalSeconds)
	if err == nil {
		result.ResearchDone = researchDone
		for _, rtID := range researchDone {
			e.db.CompleteResearch(colonyID, rtID)
		}
	}

	// ── Evolution ──
	ants, _ := e.db.GetColonyAnts(colonyID)
	for _, a := range ants {
		if a.CumulativeXP >= models.XPPerEvolution && a.Location == "home" {
			toID := models.EvolutionTarget(a.AntTypeID)
			if toID > 0 {
				count := a.CumulativeXP / models.XPPerEvolution
				e.db.EvolveAnts(colonyID, a.AntTypeID, toID, count)
				result.Evolutions = append(result.Evolutions, models.EvolutionResult{
					FromTypeID: a.AntTypeID,
					ToTypeID:   toID,
					Count:      count,
				})
			}
		}
	}

	// ── Phase 3: Process hunt timers ──
	huntIDs, err := e.db.AdvanceHuntsTimer(colonyID, models.TickIntervalSeconds)
	if err == nil {
		for _, huntID := range huntIDs {
			colonyID, _ := e.db.GetHuntColonyID(huntID)
			colonyHunt, _ := e.db.GetColony(colonyID)
			ants, _ := e.db.GetColonyAnts(colonyID)
			huntingAnts := filterByLocation(ants, "hunting")

			// Get research bonuses
			researchList, _ := e.db.GetColonyResearch(colonyID)
			bonuses := combatBonusesFromResearch(researchList)
			buildings, _ := e.db.GetColonyBuildings(colonyID)
			addDefenseBonuses(&bonuses, buildings)

			units := combat.BuildCombatUnits(huntingAnts, bonuses)
			result := combat.ResolveHunt(colonyHunt.TDCSize, units, bonuses)

			e.db.CompleteHunt(huntID, result.Won, result.TDCLostToWinner)

			// Award XP
			for _, xp := range result.XPRecipients {
				e.db.AddXPToAnts(colonyID, xp.AntTypeID, xp.XPGained*int64(xp.Count))
			}

			// Return survivors home (all ants of hunting types go back)
			for _, a := range huntingAnts {
				if a.Count > 0 {
					e.db.ReturnAntsHome(colonyID, a.AntTypeID, a.Count, "hunting")
				}
			}
		}
	}

	// ── Phase 4: Process attack timers ──
	attackIDs, err := e.db.AdvanceAttackTimers(models.TickIntervalSeconds)
	if err == nil {
		for _, attackID := range attackIDs {
			e.resolvePvPAttack(attackID)
		}
	}

	if err := e.db.FinalizeTick(colonyID); err != nil {
		log.Printf("[tick] colony %d finalize error: %v", colonyID, err)
	}
}

func computeTick(colony *models.Colony, buildings []models.ColonyBuilding) models.TickResult {
	r := models.TickResult{}

	// Gather building levels
	levels := make(map[int]int)
	for _, b := range buildings {
		levels[b.BuildingTypeID] = b.Level
	}

	// ── 1. Harvest resources ──
	maxWorkers := colony.TDCSize * models.MaxWorkersPerCm2
	foodW := colony.WorkersOnFood
	matW := colony.WorkersOnMaterials
	if foodW+matW > maxWorkers {
		total := foodW + matW
		foodW = foodW * maxWorkers / total
		matW = matW * maxWorkers / total
	}
	r.FoodHarvested = foodW * models.HarvestRate
	r.MaterialsHarvested = matW * models.HarvestRate

	// ── 2. Mushroom farm ──
	if lvl := int64(levels[1]); lvl > 0 {
		r.MushroomFood = models.MushroomFarmDailyFood(lvl) / 48
	}

	// ── 3. Construction timers ──
	// Remaining time is computed dynamically by GetColonyBuildings and expired
	// constructions are completed on read (CompleteExpiredBuildings).
	// Just surface any that hit zero here as a safety net for the tick path.
	for _, b := range buildings {
		if b.IsConstructing && b.ConstructionTimer <= 0 {
			r.BuildingsDone = append(r.BuildingsDone, b.BuildingTypeID)
		}
	}

	return r
}

// ForceTick triggers an immediate tick for a specific colony
func (e *Engine) ForceTick(colonyID int64) error {
	e.mu.Lock()
	e.tickCount++
	e.mu.Unlock()
	e.processColony(colonyID)
	return nil
}

// ForceTickAll triggers an immediate tick for all colonies
func (e *Engine) ForceTickAll() error {
	e.processAllColonies()
	return nil
}

// TickCount returns current tick number
func (e *Engine) TickCount() int64 {
	e.mu.Lock()
	defer e.mu.Unlock()
	return e.tickCount
}

// ── Phase 3 helpers ──

func filterByLocation(ants []models.ColonyAnt, loc string) []models.ColonyAnt {
	var out []models.ColonyAnt
	for _, a := range ants {
		if a.Location == loc {
			out = append(out, a)
		}
	}
	return out
}

func combatBonusesFromResearch(research []struct {
	ResearchTypeID  int
	Level           int
	IsResearching   bool
	ResearchingLevel int
	ResearchTimer   int64
}) combat.CombatBonuses {
	var b combat.CombatBonuses
	for _, r := range research {
		switch r.ResearchTypeID {
		case 2: // Bouclier Thoracique
			b.TechBouclierLevel = r.Level
		case 3: // Armes
			b.TechArmesLevel = r.Level
		}
	}
	return b
}

func addDefenseBonuses(b *combat.CombatBonuses, buildings []models.ColonyBuilding) {
	for _, bld := range buildings {
		switch bld.BuildingTypeID {
		case 10: // Dôme
			b.DomeLevel = bld.Level
		case 11: // Loge Impériale
			b.ImperialLodgeLevel = bld.Level
		}
	}
}

// ── Phase 4: PvP attack resolution in tick ──

func (e *Engine) resolvePvPAttack(attackID int64) {
	// Load attack details
	var attID, defID int64
	err := e.db.DB.QueryRow(`SELECT attacker_colony_id, defender_colony_id FROM attacks WHERE id = ?`, attackID).Scan(&attID, &defID)
	if err != nil {
		log.Printf("[tick-pvp] attack %d load error: %v", attackID, err)
		return
	}

	attackerColony, _ := e.db.GetColony(attID)
	defenderColony, _ := e.db.GetColony(defID)
	if attackerColony == nil || defenderColony == nil {
		return
	}

	attAnts, _ := e.db.GetColonyAnts(attID)
	defAnts, _ := e.db.GetColonyAnts(defID)

	attackingUnits := filterByLocation(attAnts, "attacking")

	// Research bonuses
	attResearch, _ := e.db.GetColonyResearch(attID)
	defResearch, _ := e.db.GetColonyResearch(defID)
	attBonuses := combatBonusesFromResearch(attResearch)
	defBonuses := combatBonusesFromResearch(defResearch)

	// Defense buildings
	defBuildings, _ := e.db.GetColonyBuildings(defID)
	addDefenseBonuses(&defBonuses, defBuildings)
	attBuildings, _ := e.db.GetColonyBuildings(attID)

	attUnits := combat.BuildCombatUnits(attackingUnits, attBonuses)
	defUnits := combat.BuildCombatUnits(defAnts, defBonuses)
	combat.ApplyDefenseBonuses(defUnits, defBonuses)

	aphidLevel := 0
	for _, bld := range attBuildings {
		if bld.BuildingTypeID == 12 {
			aphidLevel = bld.Level
		}
	}

	result := combat.ResolvePvPAttack(
		attUnits, defUnits,
		defenderColony.TDCSize,
		defenderColony.Resources.Food,
		defenderColony.Resources.Materials,
		aphidLevel,
		false, 0,
	)

	e.db.ResolveAttack(attackID, result.AttackerWins, result.TDCLostToAttacker, result.FoodStolen, result.MaterialsStolen, result.ColonyCaptured)

	// Return survivors
	for _, a := range attackingUnits {
		if a.Count > 0 {
			e.db.ReturnAntsHome(attID, a.AntTypeID, a.Count, "attacking")
		}
	}

	// Auto-colonize if colony captured
	if result.ColonyCaptured {
		e.db.Colonize(attID, defID, combat.ColonizationTax(aphidLevel))
	}
}