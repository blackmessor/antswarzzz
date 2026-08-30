package models

import "time"

// ── Resources ──

type Resources struct {
	Food      int64 `json:"food"`
	Materials int64 `json:"materials"`
}

// ── Colony state (top-level) ──

type Colony struct {
	ID                 int64     `json:"id"`
	PlayerID           int64     `json:"player_id"`
	Name               string    `json:"name"`
	TDCSize            int64     `json:"tdc_size"`
	WorkersOnFood      int64     `json:"workers_on_food"`
	WorkersOnMaterials int64     `json:"workers_on_materials"`
	LastTickAt         time.Time `json:"last_tick_at"`
	CreatedAt          time.Time `json:"created_at"`
	Resources          Resources `json:"resources"`
}

// ── Static data models ──

type AntType struct {
	ID             int    `json:"id"`
	Slug           string `json:"slug"`
	Name           string `json:"name"`
	Abbreviation   string `json:"abbreviation"`
	BaseHP         int    `json:"base_hp"`
	BaseAttack     int    `json:"base_attack"`
	BaseDefense    int    `json:"base_defense"`
	BreedTimeSecs  *int   `json:"breed_time_seconds"`
	FoodCost       int    `json:"food_cost"`
	IsWorker       bool   `json:"is_worker"`
	IsBreedable    bool   `json:"is_breedable"`
	EvolvesToID    *int   `json:"evolves_to_id"`
	DeathOrder     int    `json:"death_order"`
}

type BuildingType struct {
	ID                 int     `json:"id"`
	Slug               string  `json:"slug"`
	Name               string  `json:"name"`
	Category           string  `json:"category"`
	BaseCostMaterials  int64   `json:"base_cost_materials"`
	BaseCostFood       *int64  `json:"base_cost_food"`
	BaseCostWorkers    *int64  `json:"base_cost_workers"`
	BaseTimeSeconds    int64   `json:"base_time_seconds"`
	EffectDescription  string  `json:"effect_description"`
}

type ColonyBuilding struct {
	ID                int64 `json:"id"`
	ColonyID          int64 `json:"colony_id"`
	BuildingTypeID    int   `json:"building_type_id"`
	Level             int   `json:"level"`
	IsConstructing    bool  `json:"is_constructing"`
	ConstructionTimer int64 `json:"construction_timer"`
}

// ── Game constants ──

const (
	TickIntervalSeconds  = 1800 // 30 minutes
	MaxWorkersPerCm2     = 1
	HarvestRate          = 1 // resources per worker per tick
	InitialTDCSize       = 50
	InitialFood           = 100
	InitialMaterials      = 100
)

// ── Building cost formulas ──

// Category A: cost ×2 per level
func CategoryACost(base, level int64) int64 {
	if level <= 0 {
		return 0
	}
	return base * (1 << (level - 1)) // 2^(level-1)
}

// Category A: time same as base (simple buildings have fixed time)
func CategoryATime(base int64, _ int64) int64 {
	return base
}

// Category B: mushroom farm — cost ×1.85 per level, production ×1.70
func CategoryBCost(base, level int64) int64 {
	if level <= 0 {
		return 0
	}
	cost := float64(base)
	for i := int64(1); i < level; i++ {
		cost *= 1.85
	}
	return int64(cost)
}

// Mushroom farm daily food: floor(122 * 1.70^(level-1))
func MushroomFarmDailyFood(level int64) int64 {
	if level <= 0 {
		return 0
	}
	prod := 122.0
	for i := int64(1); i < level; i++ {
		prod *= 1.70
	}
	return int64(prod)
}

// Category D: warehouse capacity — 1700 + 1200 * (2^level - 1)
func WarehouseCapacity(level int64) int64 {
	if level <= 0 {
		return 1700 // base storage without warehouse
	}
	return 1700 + 1200*((1<<level)-1)
}

// Cost to build next level — for warehouse: 600 * 2^(level-1)
func CategoryDCost(base, level int64) int64 {
	if level <= 0 {
		return 0
	}
	return base * (1 << (level - 1))
}

// Warehouse build time: 180 * 1.6^(level-1)
func CategoryDTime(base float64, level int64) int64 {
	if level <= 0 {
		return 0
	}
	t := base
	for i := int64(1); i < level; i++ {
		t *= 1.6
	}
	return int64(t)
}

// ── Breeding ──

// Effective breeding time with hatchery + solarium + tech_ponte bonuses
func EffectiveBreedTime(baseSecs int, hatcheryLevel, solariumLevel, techPonteLevel int) int {
	bonus := 1.0
	bonus += 0.10 * float64(hatcheryLevel)  // +10% per hatchery level
	bonus += 0.10 * float64(solariumLevel)  // +10% per solarium level
	bonus += 0.10 * float64(techPonteLevel) // +10% per tech_ponte level
	// bonus is a speed multiplier; time = base / bonus
	effective := float64(baseSecs) / bonus
	return int(effective)
}

// ── WebSocket messages ──

type WSMessage struct {
	Type    string      `json:"type"`
	Payload interface{} `json:"payload"`
}

type ColonyStatePayload struct {
	Colony   Colony            `json:"colony"`
	Buildings []ColonyBuilding `json:"buildings"`
	Ants     []ColonyAnt       `json:"ants"`
}

type TickDeltaPayload struct {
	TickID    int64            `json:"tick_id"`
	Resources ResourcesDelta   `json:"resources"`
	Deltas    TickDeltas       `json:"deltas"`
}

type ResourcesDelta struct {
	Food      int64 `json:"food"`
	Materials int64 `json:"materials"`
}

type TickDeltas struct {
	FoodHarvested      int64              `json:"food_harvested"`
	MaterialsHarvested int64              `json:"materials_harvested"`
	UpkeepFood         int64              `json:"upkeep_food"`
	BuildingsCompleted []string           `json:"buildings_completed"`
	BreedsCompleted    []BreedComplete    `json:"breeds_completed"`
	MushroomFood       int64             `json:"mushroom_food"`
}

type BreedComplete struct {
	AntTypeID int   `json:"ant_type_id"`
	Count     int64 `json:"count"`
}

// ── Ant representation (aggregated) ──

type ColonyAnt struct {
	ID            int64  `json:"id"`
	ColonyID      int64  `json:"colony_id"`
	AntTypeID     int    `json:"ant_type_id"`
	Location      string `json:"location"`
	Count         int64  `json:"count"`
	CumulativeXP  int64  `json:"cumulative_xp"`
}

// ── Tick engine ──

type TickResult struct {
	Resources          ResourcesDelta
	BreedsCompleted    []BreedComplete
	BreedCompleted     *int       // single breed completed this tick
	BuildingsDone      []int
	ResearchDone       []int
	Evolutions         []EvolutionResult
	MushroomFood       int64
	FoodUpkeep         int64
	FoodHarvested      int64
	MaterialsHarvested int64
}
// ── Phase 2: Evolution ──

type EvolutionResult struct {
	FromTypeID int   `json:"from_type_id"`
	ToTypeID   int   `json:"to_type_id"`
	Count      int64 `json:"count"`
}

// EvolutionTarget returns the elite ant type ID for a given ant type
// Maps regular ants to their evolved form (matching init.sql)
func EvolutionTarget(antTypeID int) int {
	mapping := map[int]int{
		2:  3,  // SN → NE
		5:  6,  // S → SE
		7:  8,  // C → CE
		11: 12, // Tk → TkE
		13: 14, // Tu → TuE
	}
	return mapping[antTypeID]
}

const XPPerEvolution = 100

// ── Phase 2: Research cost scaling ──

func ResearchCost(baseWorkers, baseFood, baseMaterials int, level int) (int, int, int) {
	w := float64(baseWorkers)
	f := float64(baseFood)
	m := float64(baseMaterials)
	for i := 1; i < level; i++ {
		w *= 2.0
		f *= 2.5
		m *= 1.5
	}
	return int(w), int(f), int(m)
}

func ResearchTime(baseSeconds int, level int) int {
	t := float64(baseSeconds)
	for i := 1; i < level; i++ {
		t *= 1.6
	}
	return int(t)
}

// ── Phase 2: Category C building cost (food + workers) ──

func CategoryCFoodCost(baseFood int64, level int) int64 {
	if level <= 0 {
		return 0
	}
	c := float64(baseFood)
	for i := 1; i < level; i++ {
		c *= 2.0
	}
	return int64(c)
}

func CategoryCWorkerCost(baseWorkers int64, level int) int64 {
	if level <= 0 {
		return 0
	}
	c := float64(baseWorkers)
	for i := 1; i < level; i++ {
		c *= 2.0
	}
	return int64(c)
}

// ── Phase 5: Technology dependency graph ──

// TechPrerequisites maps research ID → required research ID → min level
var TechPrerequisites = map[int]map[int]int{
	7:  {4: 1},  // Communication Animaux needs Architecture level 1
	8:  {3: 5},  // Génétique needs Armes level 5
	9:  {8: 3},  // Acide needs Génétique level 3
	10: {9: 5},  // Poison needs Acide level 5
}

// TechUnlocks maps research ID → ant type ID it unlocks for breeding
var TechUnlocks = map[int][]int{
	7:  {7},   // Communication Animaux → Concierge (C)
	8:  {11},  // Génétique → Tank (Tk)
	9:  {9, 10}, // Acide → Artilleuse (A), Artilleuse d'Élite (AE)
	10: {13},  // Poison → Tueuse (Tu)
}

// CheckTechPrerequisites validates all requirements for a given research
func CheckTechPrerequisites(techID int, targetLevel int, currentResearch map[int]int) bool {
	prereqs, exists := TechPrerequisites[techID]
	if !exists {
		return true // no prerequisites
	}
	for reqTechID, reqLevel := range prereqs {
		if currentResearch[reqTechID] < reqLevel {
			return false
		}
	}
	return true
}

// IsUnitUnlocked checks if an ant type can be bred based on research + building levels
func IsUnitUnlocked(antTypeID int, researchLevels map[int]int, buildingLevels map[int]int) bool {
	for techID, antIDs := range TechUnlocks {
		for _, aid := range antIDs {
			if aid == antTypeID {
				if researchLevels[techID] < 1 {
					return false
				}
			}
		}
	}
	// Also check building requirements from ant_types table:
	// JSN: combat_room 1, SN: combat_room 3, JS: combat_room 5, S: barracks 1, Tk: barracks 22
	// Handled by the caller via ant_types table
	return true
}

// ── Phase 5: Missing formulas ──

const (
	// Upkeep rates (per tick)
	UpkeepInsideRate  = 0.10 / 48  // 10% per day, divided by 48 ticks
	UpkeepOutsideRate = 0.05 / 48  // 5% per day for hunting/attacking ants
	StarvationDeath   = 0.005      // 0.5% of ants die per tick when food=0

	// XP gains
	XPPerCombatBase    = 10
	BaseUnitsGainingXP = 10
	// Mealybug farm: +10% units gaining XP per level
)

// XP slots for combat: base * (1 + 0.10 * mealybug_level)
func XPSlots(mealybugLevel int) int64 {
	return int64(float64(BaseUnitsGainingXP) * (1.0 + 0.10*float64(mealybugLevel)))
}

// Starvation kills fraction of military ants when food = 0
func StarvationDeaths(militaryCount int64) int64 {
	return int64(float64(militaryCount) * StarvationDeath)
}

// Outside upkeep: extra food cost for ants on hunt/attack/tdc
func OutsideUpkeepFood(count int64) int64 {
	return int64(float64(count) * UpkeepOutsideRate)
}

// Inside upkeep (already handled in tick as 1 food/military/tick for simplicity)
func InsideUpkeepFood(count int64) int64 {
	return int64(float64(count) * UpkeepInsideRate)
}

// ── Phase 5: Building prerequisite check ──

// Building prerequisites for ant breeding (matching init.sql ant_types)
var AntBuildingPrerequisites = map[int]struct {
	BuildingSlug string
	MinLevel     int
}{
	1:  {"combat_room", 1},  // JSN
	2:  {"combat_room", 3},  // SN
	4:  {"combat_room", 5},  // JS
	5:  {"barracks", 1},     // S
	11: {"barracks", 22},    // Tk
}

// Building slug → building type ID mapping
var BuildingSlugToID = map[string]int{
	"mushroom_farm":   1,
	"food_warehouse":  2,
	"mat_warehouse":   3,
	"hatchery":        4,
	"solarium":        5,
	"lab":             6,
	"analysis_room":   7,
	"combat_room":     8,
	"barracks":        9,
	"dome":            10,
	"imperial_lodge":  11,
	"aphid_farm":      12,
	"mealybug_farm":   13,
}

// CheckAntBreedingAllowed validates building + research requirements for breeding
func CheckAntBreedingAllowed(antTypeID int, buildingLevels map[int]int, researchLevels map[int]int) (bool, string) {
	// Check building prerequisites
	if prereq, ok := AntBuildingPrerequisites[antTypeID]; ok {
		buildingID := BuildingSlugToID[prereq.BuildingSlug]
		if buildingLevels[buildingID] < prereq.MinLevel {
			return false, "building requirement not met"
		}
	}
	// Check research unlocks
	for techID, antIDs := range TechUnlocks {
		for _, aid := range antIDs {
			if aid == antTypeID && researchLevels[techID] < 1 {
				return false, "research requirement not met"
			}
		}
	}
	return true, ""
}
