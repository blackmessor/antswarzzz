package api

import (
	"encoding/json"
	"net/http"
	"strconv"
	"strings"

	"github.com/antswarzzz/server/internal/combat"
	"github.com/antswarzzz/server/internal/database"
	"github.com/antswarzzz/server/internal/models"
	"github.com/antswarzzz/server/internal/tick"
)

type Handler struct {
	db    *database.DB
	tick  *tick.Engine
}

func NewHandler(db *database.DB, eng *tick.Engine) *Handler {
	return &Handler{db: db, tick: eng}
}

func (h *Handler) Register(mux *http.ServeMux) {
	mux.HandleFunc("/health", h.health)
	mux.HandleFunc("/api/colony", h.handleColony)
	mux.HandleFunc("/api/colony/", h.handleColonyByID)
	mux.HandleFunc("/api/breeding/", h.handleBreeding)
	mux.HandleFunc("/api/research/", h.handleResearch)
	mux.HandleFunc("/api/player/register", h.registerPlayer)
	mux.HandleFunc("/api/hunt/", h.handleHunt)
	mux.HandleFunc("/api/pvp/", h.handlePvP)
	mux.HandleFunc("/api/tick", h.forceTick)
}

func (h *Handler) health(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, map[string]interface{}{
		"status":     "ok",
		"service":    "antswarzzz-server",
		"tick_count": h.tick.TickCount(),
	})
}

func (h *Handler) registerPlayer(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "POST required", 405)
		return
	}
	var body struct {
		Username string `json:"username"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil || body.Username == "" {
		writeJSON(w, map[string]string{"error": "username required"})
		return
	}

	playerID, err := h.db.CreatePlayer(body.Username)
	if err != nil {
		writeJSON(w, map[string]string{"error": "failed to create player"})
		return
	}

	colonyID, err := h.db.CreateColony(playerID, body.Username+"'s colony")
	if err != nil {
		writeJSON(w, map[string]string{"error": "failed to create colony"})
		return
	}

	writeJSON(w, map[string]interface{}{
		"player_id": playerID,
		"colony_id": colonyID,
		"username":  body.Username,
	})
}

func (h *Handler) handleColony(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "POST required", 405)
		return
	}
	var body struct {
		PlayerID int64  `json:"player_id"`
		Name     string `json:"name"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		writeJSON(w, map[string]string{"error": "invalid body"})
		return
	}
	if body.Name == "" {
		body.Name = "New Colony"
	}
	id, err := h.db.CreateColony(body.PlayerID, body.Name)
	if err != nil {
		writeJSON(w, map[string]string{"error": err.Error()})
		return
	}
	writeJSON(w, map[string]int64{"colony_id": id})
}

func (h *Handler) handleColonyByID(w http.ResponseWriter, r *http.Request) {
	parts := strings.Split(strings.TrimPrefix(r.URL.Path, "/api/colony/"), "/")
	if len(parts) == 0 || parts[0] == "" {
		http.Error(w, "colony ID required", 400)
		return
	}
	colonyID, err := strconv.ParseInt(parts[0], 10, 64)
	if err != nil {
		http.Error(w, "invalid colony ID", 400)
		return
	}

	switch r.Method {
	case http.MethodGet:
		colony, err := h.db.GetColony(colonyID)
		if err != nil {
			writeJSON(w, map[string]string{"error": err.Error()})
			return
		}
		buildings, _ := h.db.GetColonyBuildings(colonyID)
		ants, _ := h.db.GetColonyAnts(colonyID)
		breedQ, _ := h.db.GetBreedQueue(colonyID)
		activeAntType, activeTimer, activePos, _ := h.db.GetActiveBreed(colonyID)
		research, _ := h.db.GetColonyResearch(colonyID)
		military, _ := h.db.GetMilitaryAntCount(colonyID)
		workerCount, _ := h.db.GetWorkerCount(colonyID)

		payload := map[string]interface{}{
			"colony":    colony,
			"buildings": buildings,
			"ants":      ants,
			"worker_count": workerCount,
			"military_count": military,
		}
		if breedQ != nil {
			payload["breed_queue"] = breedQ
		}
		if activeAntType != nil {
			payload["active_breed"] = map[string]interface{}{
				"ant_type_id":    *activeAntType,
				"timer":          *activeTimer,
				"queue_position": *activePos,
			}
		}
		if research != nil {
			payload["research"] = research
		}
		writeJSON(w, payload)

	case http.MethodPost:
		var action struct {
			Action             string `json:"action"`
			WorkersOnFood      *int64 `json:"workers_on_food,omitempty"`
			WorkersOnMaterials *int64 `json:"workers_on_materials,omitempty"`
			BuildingTypeID     *int   `json:"building_type_id,omitempty"`
			AntTypeID          *int   `json:"ant_type_id,omitempty"`
		}
		if err := json.NewDecoder(r.Body).Decode(&action); err != nil {
			writeJSON(w, map[string]string{"error": "invalid action"})
			return
		}

		switch action.Action {
		case "assign_workers":
			if action.WorkersOnFood != nil && action.WorkersOnMaterials != nil {
				if err := h.db.UpdateWorkers(colonyID, *action.WorkersOnFood, *action.WorkersOnMaterials); err != nil {
					writeJSON(w, map[string]string{"error": err.Error()})
					return
				}
				writeJSON(w, map[string]string{"status": "workers_updated"})
			} else {
				writeJSON(w, map[string]string{"error": "workers_on_food and workers_on_materials required"})
			}

		case "upgrade_building":
			if action.BuildingTypeID == nil {
				writeJSON(w, map[string]string{"error": "building_type_id required"})
				return
			}
			btID := *action.BuildingTypeID

			// Get current level
			buildings, err := h.db.GetColonyBuildings(colonyID)
			if err != nil {
				writeJSON(w, map[string]string{"error": err.Error()})
				return
			}
			var currentLevel int
			var isConstructing bool
			for _, b := range buildings {
				if b.BuildingTypeID == btID {
					currentLevel = b.Level
					isConstructing = b.IsConstructing
					break
				}
			}
			if isConstructing {
				writeJSON(w, map[string]string{"error": "building already under construction"})
				return
			}
			nextLevel := currentLevel + 1

			// Compute cost — depends on category
			// For now, use simple A/B/D formulas; category C adds food/workers cost
			mats := int64(0)
			switch btID {
			case 1: // Champignonnière (B)
				mats = models.CategoryBCost(90, int64(nextLevel))
			case 2, 3: // Warehouses (D)
				mats = models.CategoryDCost(600, int64(nextLevel))
			default: // General A
				mats = models.CategoryACost(2000, int64(nextLevel))
			}
			timer := int64(300) // default 5 min; warehouse uses its own formula

			if err := h.db.StartBuilding(colonyID, btID, timer, mats); err != nil {
				writeJSON(w, map[string]string{"error": err.Error()})
				return
			}
			writeJSON(w, map[string]interface{}{
				"status":     "construction_started",
				"building":   btID,
				"next_level": nextLevel,
				"timer":      timer,
				"materials":  mats,
			})

		default:
			writeJSON(w, map[string]string{"error": "unknown action: " + action.Action})
		}
	}
}

// ── Phase 2: Breeding endpoints ──

func (h *Handler) handleBreeding(w http.ResponseWriter, r *http.Request) {
	// URL: /api/breeding/{colony_id}
	parts := strings.Split(strings.TrimPrefix(r.URL.Path, "/api/breeding/"), "/")
	if len(parts) == 0 || parts[0] == "" {
		http.Error(w, "colony ID required", 400)
		return
	}
	colonyID, err := strconv.ParseInt(parts[0], 10, 64)
	if err != nil {
		http.Error(w, "invalid colony ID", 400)
		return
	}

	switch r.Method {
	case http.MethodPost:
		var action struct {
			Action    string `json:"action"`
			AntTypeID int    `json:"ant_type_id"`
		}
		if err := json.NewDecoder(r.Body).Decode(&action); err != nil {
			writeJSON(w, map[string]string{"error": "invalid body"})
			return
		}

		switch action.Action {
		case "queue":
			if action.AntTypeID < 1 || action.AntTypeID > 14 {
				writeJSON(w, map[string]string{"error": "invalid ant_type_id (1-14)"})
				return
			}
			// Check building + research prerequisites
			buildings, _ := h.db.GetColonyBuildings(colonyID)
			buildingLevels := make(map[int]int)
			for _, b := range buildings {
				buildingLevels[b.BuildingTypeID] = b.Level
			}
			research, _ := h.db.GetColonyResearch(colonyID)
			researchLevels := make(map[int]int)
			for _, r := range research {
				researchLevels[r.ResearchTypeID] = r.Level
			}
			if allowed, reason := models.CheckAntBreedingAllowed(action.AntTypeID, buildingLevels, researchLevels); !allowed {
				writeJSON(w, map[string]string{"error": reason})
				return
			}
			pos, err := h.db.QueueBreed(colonyID, action.AntTypeID)
			if err != nil {
				writeJSON(w, map[string]string{"error": err.Error()})
				return
			}

			// If no active breed, start immediately
			activeType, _, _, _ := h.db.GetActiveBreed(colonyID)
			if activeType == nil {
				// Start breeding with cost deducted
				breedTime := int64(300)    // default 5 min
				foodCost := int64(10)
				if err := h.db.StartBreed(colonyID, action.AntTypeID, pos, breedTime, foodCost); err != nil {
					writeJSON(w, map[string]string{"error": err.Error()})
					return
				}
				writeJSON(w, map[string]interface{}{
					"status":    "breeding_started",
					"position":  pos,
					"ant_type":  action.AntTypeID,
					"timer":     breedTime,
				})
			} else {
				writeJSON(w, map[string]interface{}{
					"status":    "queued",
					"position":  pos,
					"ant_type":  action.AntTypeID,
				})
			}

		default:
			writeJSON(w, map[string]string{"error": "unknown action: " + action.Action})
		}
	}
}

// ── Phase 2: Research endpoints ──

func (h *Handler) handleResearch(w http.ResponseWriter, r *http.Request) {
	parts := strings.Split(strings.TrimPrefix(r.URL.Path, "/api/research/"), "/")
	if len(parts) == 0 || parts[0] == "" {
		http.Error(w, "colony ID required", 400)
		return
	}
	colonyID, err := strconv.ParseInt(parts[0], 10, 64)
	if err != nil {
		http.Error(w, "invalid colony ID", 400)
		return
	}

	if r.Method != http.MethodPost {
		http.Error(w, "POST required", 405)
		return
	}

	var action struct {
		Action         string `json:"action"`
		ResearchTypeID int    `json:"research_type_id"`
	}
	if err := json.NewDecoder(r.Body).Decode(&action); err != nil {
		writeJSON(w, map[string]string{"error": "invalid body"})
		return
	}

	switch action.Action {
	case "start":
		if action.ResearchTypeID < 1 || action.ResearchTypeID > 10 {
			writeJSON(w, map[string]string{"error": "invalid research_type_id (1-10)"})
			return
		}

		// Get current level
		research, err := h.db.GetColonyResearch(colonyID)
		if err != nil {
			writeJSON(w, map[string]string{"error": err.Error()})
			return
		}
		var currentLevel int
		for _, r := range research {
			if r.ResearchTypeID == action.ResearchTypeID {
				currentLevel = r.Level
				if r.IsResearching {
					writeJSON(w, map[string]string{"error": "research already in progress"})
					return
				}
				break
			}
		}
		nextLevel := currentLevel + 1

		// Check prerequisites: build research level map
		researchLevels := make(map[int]int)
		for _, r := range research {
			researchLevels[r.ResearchTypeID] = r.Level
		}
		if !models.CheckTechPrerequisites(action.ResearchTypeID, nextLevel, researchLevels) {
			writeJSON(w, map[string]string{"error": "prerequisites not met"})
			return
		}

		// Compute cost and time
		workers, foodCost, mats := models.ResearchCost(100, 200, 100, nextLevel)
		t := models.ResearchTime(600, nextLevel)

		// Deduct resources
		colony, _ := h.db.GetColony(colonyID)
		if colony.Resources.Food < int64(foodCost) {
			writeJSON(w, map[string]string{"error": "not enough food"})
			return
		}
		if colony.Resources.Materials < int64(mats) {
			writeJSON(w, map[string]string{"error": "not enough materials"})
			return
		}

		// Deduct and start
		if err := h.db.UpdateResources(colonyID, colony.Resources.Food-int64(foodCost), colony.Resources.Materials-int64(mats)); err != nil {
			writeJSON(w, map[string]string{"error": err.Error()})
			return
		}
		if err := h.db.StartResearch(colonyID, action.ResearchTypeID, nextLevel, int64(t)); err != nil {
			writeJSON(w, map[string]string{"error": err.Error()})
			return
		}

		writeJSON(w, map[string]interface{}{
			"status":            "research_started",
			"research_type_id":  action.ResearchTypeID,
			"target_level":      nextLevel,
			"timer":             t,
			"cost_workers":      workers,
			"cost_food":         foodCost,
			"cost_materials":    mats,
		})

	default:
		writeJSON(w, map[string]string{"error": "unknown action: " + action.Action})
	}
}

// ── Tick ──

func (h *Handler) forceTick(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "POST required", 405)
		return
	}
	var body struct {
		ColonyID *int64 `json:"colony_id"`
	}
	json.NewDecoder(r.Body).Decode(&body)

	if body.ColonyID != nil {
		if err := h.tick.ForceTick(*body.ColonyID); err != nil {
			writeJSON(w, map[string]string{"error": err.Error()})
			return
		}
	} else {
		h.tick.ForceTickAll()
	}
	writeJSON(w, map[string]string{"status": "tick_completed"})
}

func writeJSON(w http.ResponseWriter, v interface{}) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(v)
}

// ── Phase 3: Hunt endpoint ──

func (h *Handler) handleHunt(w http.ResponseWriter, r *http.Request) {
	parts := strings.Split(strings.TrimPrefix(r.URL.Path, "/api/hunt/"), "/")
	if len(parts) == 0 || parts[0] == "" {
		http.Error(w, "colony ID required", 400)
		return
	}
	colonyID, err := strconv.ParseInt(parts[0], 10, 64)
	if err != nil {
		http.Error(w, "invalid colony ID", 400)
		return
	}

	if r.Method != http.MethodPost {
		http.Error(w, "POST required", 405)
		return
	}

	var action struct {
		Action   string         `json:"action"`
		Ants     []struct {
			AntTypeID int   `json:"ant_type_id"`
			Count     int64 `json:"count"`
		} `json:"ants"`
	}
	if err := json.NewDecoder(r.Body).Decode(&action); err != nil {
		writeJSON(w, map[string]string{"error": "invalid body"})
		return
	}

	switch action.Action {
	case "start":
		if len(action.Ants) == 0 {
			writeJSON(w, map[string]string{"error": "at least one ant type required"})
			return
		}

		// Move ants to hunting location
		for _, a := range action.Ants {
			if err := h.db.MoveAntsToLocation(colonyID, a.AntTypeID, a.Count, "hunting"); err != nil {
				writeJSON(w, map[string]string{"error": err.Error()})
				return
			}
		}

		// Get colony for TDC
		colony, err := h.db.GetColony(colonyID)
		if err != nil {
			writeJSON(w, map[string]string{"error": err.Error()})
			return
		}

		// Hunt timer based on TDC size
		timer := int64(1800) // 30 min base

		// Apply vitesse_chasse bonus
		research, _ := h.db.GetColonyResearch(colonyID)
		for _, r := range research {
			if r.ResearchTypeID == 5 { // Vitesse de Chasse
				timer = timer * int64(max(0.1, 1.0-0.10*float64(r.Level)))
			}
		}

		huntID, err := h.db.StartHunt(colonyID, colony.TDCSize, timer)
		if err != nil {
			writeJSON(w, map[string]string{"error": err.Error()})
			return
		}

		writeJSON(w, map[string]interface{}{
			"status":  "hunt_started",
			"hunt_id": huntID,
			"timer":   timer,
		})

	case "resolve":
		// Immediate hunt resolution (for testing / force-resolve)
		ants, _ := h.db.GetColonyAnts(colonyID)
		huntingAnts := filterAntsByLocation(ants, "hunting")
		if len(huntingAnts) == 0 {
			writeJSON(w, map[string]string{"error": "no ants hunting"})
			return
		}

		colony, _ := h.db.GetColony(colonyID)
		researchList, _ := h.db.GetColonyResearch(colonyID)
		buildings, _ := h.db.GetColonyBuildings(colonyID)

		bonuses := researchBonuses(researchList)
		for _, bld := range buildings {
			switch bld.BuildingTypeID {
			case 10:
				bonuses.DomeLevel = bld.Level
			case 11:
				bonuses.ImperialLodgeLevel = bld.Level
			}
		}

		units := buildCombatUnits(huntingAnts, bonuses)
		result := resolveHunt(colony.TDCSize, units, bonuses)

		// Return survivors home
		for _, a := range huntingAnts {
			if a.Count > 0 {
				h.db.ReturnAntsHome(colonyID, a.AntTypeID, a.Count, "hunting")
			}
		}

		if result.Won {
			// Award TDC directly
			h.db.UpdateTDC(colonyID, result.TDCLostToWinner)
			// Award XP
			for _, xp := range result.XPRecipients {
				h.db.AddXPToAnts(colonyID, xp.AntTypeID, xp.XPGained*int64(xp.Count))
			}
		}

		writeJSON(w, map[string]interface{}{
			"won":           result.Won,
			"tdc_gained":    result.TDCLostToWinner,
			"rounds_fought": result.RoundsFought,
			"xp_awarded":    result.XPRecipients,
		})

	default:
		writeJSON(w, map[string]string{"error": "unknown action: " + action.Action})
	}
}

func filterAntsByLocation(ants []models.ColonyAnt, loc string) []models.ColonyAnt {
	var out []models.ColonyAnt
	for _, a := range ants {
		if a.Location == loc {
			out = append(out, a)
		}
	}
	return out
}

func researchBonuses(research []struct {
	ResearchTypeID  int
	Level           int
	IsResearching   bool
	ResearchingLevel int
	ResearchTimer   int64
}) combat.CombatBonuses {
	var b combat.CombatBonuses
	for _, r := range research {
		switch r.ResearchTypeID {
		case 2:
			b.TechBouclierLevel = r.Level
		case 3:
			b.TechArmesLevel = r.Level
		}
	}
	return b
}

func buildCombatUnits(ants []models.ColonyAnt, bonuses combat.CombatBonuses) []combat.CombatUnit {
	return combat.BuildCombatUnits(ants, bonuses)
}

func resolveHunt(tdc int64, units []combat.CombatUnit, bonuses combat.CombatBonuses) combat.HuntResult {
	return combat.ResolveHunt(tdc, units, bonuses)
}

// ── Phase 4: PvP endpoint ──

func (h *Handler) handlePvP(w http.ResponseWriter, r *http.Request) {
	parts := strings.Split(strings.TrimPrefix(r.URL.Path, "/api/pvp/"), "/")
	if len(parts) == 0 || parts[0] == "" {
		http.Error(w, "colony ID required", 400)
		return
	}
	colonyID, err := strconv.ParseInt(parts[0], 10, 64)
	if err != nil {
		http.Error(w, "invalid colony ID", 400)
		return
	}

	if r.Method != http.MethodPost {
		http.Error(w, "POST required", 405)
		return
	}

	var action struct {
		Action       string `json:"action"`
		TargetID     int64  `json:"target_id,omitempty"`
		AntTypeID    int    `json:"ant_type_id,omitempty"`
		Count        int64  `json:"count,omitempty"`
		Ants         []struct {
			AntTypeID int   `json:"ant_type_id"`
			Count     int64 `json:"count"`
		} `json:"ants,omitempty"`
	}
	if err := json.NewDecoder(r.Body).Decode(&action); err != nil {
		writeJSON(w, map[string]string{"error": "invalid body"})
		return
	}

	switch action.Action {
	case "targets":
		colony, err := h.db.GetColony(colonyID)
		if err != nil {
			writeJSON(w, map[string]string{"error": err.Error()})
			return
		}
		targets, err := h.db.GetAttackTargets(colonyID, colony.TDCSize, 15)
		if err != nil {
			writeJSON(w, map[string]string{"error": err.Error()})
			return
		}
		writeJSON(w, map[string]interface{}{
			"targets": targets,
		})

	case "attack":
		if action.TargetID == 0 {
			writeJSON(w, map[string]string{"error": "target_id required"})
			return
		}
		if len(action.Ants) == 0 {
			writeJSON(w, map[string]string{"error": "ants required"})
			return
		}

		attacker, _ := h.db.GetColony(colonyID)
		defender, err := h.db.GetColony(action.TargetID)
		if err != nil {
			writeJSON(w, map[string]string{"error": "defender not found"})
			return
		}

		if !combat.CanAttack(attacker.TDCSize, defender.TDCSize) {
			writeJSON(w, map[string]string{"error": "target outside TDC range (50%-300%)"})
			return
		}

		// Check not already colonized
		_, _, err = h.db.GetColonizer(action.TargetID)
		if err == nil {
			writeJSON(w, map[string]string{"error": "target is already colonized"})
			return
		}

		// Move ants to attacking location
		for _, a := range action.Ants {
			h.db.MoveAntsToLocation(colonyID, a.AntTypeID, a.Count, "attacking")
		}

		// Compute travel time
		research, _ := h.db.GetColonyResearch(colonyID)
		vitesseAttaque := 0
		for _, r := range research {
			if r.ResearchTypeID == 6 {
				vitesseAttaque = r.Level
			}
		}
		timer := combat.AttackTravelTime(attacker.TDCSize, defender.TDCSize, vitesseAttaque)

		attackID, err := h.db.StartPvPAttack(colonyID, action.TargetID, timer)
		if err != nil {
			writeJSON(w, map[string]string{"error": err.Error()})
			return
		}

		writeJSON(w, map[string]interface{}{
			"status":     "attack_launched",
			"attack_id":  attackID,
			"target_id":  action.TargetID,
			"timer":      timer,
		})

	case "resolve":
		// Force-resolve pending attacks for this colony
		attacks, _ := h.db.GetActiveAttacksForColony(colonyID)
		if len(attacks) == 0 {
			writeJSON(w, map[string]string{"error": "no active attacks"})
			return
		}
		results := []map[string]interface{}{}
		for _, atk := range attacks {
			// Resolve each attack
			_, _ = h.db.GetColony(atk.AttackerColonyID)
			defenderColony, _ := h.db.GetColony(atk.DefenderColonyID)

			attAnts, _ := h.db.GetColonyAnts(atk.AttackerColonyID)
			defAnts, _ := h.db.GetColonyAnts(atk.DefenderColonyID)

			attackingUnits := filterAntsByLocation(attAnts, "attacking")

			// Get research bonuses
			attResearch, _ := h.db.GetColonyResearch(atk.AttackerColonyID)
			defResearch, _ := h.db.GetColonyResearch(atk.DefenderColonyID)

			attBonuses := researchBonuses(attResearch)
			defBonuses := researchBonuses(defResearch)

			attBuildings, _ := h.db.GetColonyBuildings(atk.AttackerColonyID)
			defBuildings, _ := h.db.GetColonyBuildings(atk.DefenderColonyID)
			for _, bld := range defBuildings {
				switch bld.BuildingTypeID {
				case 10:
					defBonuses.DomeLevel = bld.Level
				case 11:
					defBonuses.ImperialLodgeLevel = bld.Level
				}
			}

			attUnits := combat.BuildCombatUnits(attackingUnits, attBonuses)
			defUnits := combat.BuildCombatUnits(defAnts, defBonuses)
			combat.ApplyDefenseBonuses(defUnits, defBonuses)

			aphidLevel := 0
			for _, bld := range attBuildings {
				if bld.BuildingTypeID == 12 {
					aphidLevel = bld.Level
				}
			}

			pvpResult := combat.ResolvePvPAttack(
				attUnits, defUnits,
				defenderColony.TDCSize,
				defenderColony.Resources.Food,
				defenderColony.Resources.Materials,
				aphidLevel,
				false, 0,
			)

			h.db.ResolveAttack(atk.ID, pvpResult.AttackerWins, pvpResult.TDCLostToAttacker, pvpResult.FoodStolen, pvpResult.MaterialsStolen, pvpResult.ColonyCaptured)

			// Return surviving attackers home
			for _, a := range attackingUnits {
				if a.Count > 0 {
					h.db.ReturnAntsHome(atk.AttackerColonyID, a.AntTypeID, a.Count, "attacking")
				}
			}

			results = append(results, map[string]interface{}{
				"attack_id":       atk.ID,
				"attacker_wins":   pvpResult.AttackerWins,
				"rounds":          pvpResult.RoundsFought,
				"tdc_stolen":      pvpResult.TDCLostToAttacker,
				"food_stolen":     pvpResult.FoodStolen,
				"mats_stolen":     pvpResult.MaterialsStolen,
				"colony_captured": pvpResult.ColonyCaptured,
			})
		}
		writeJSON(w, map[string]interface{}{"results": results})

	case "colonize":
		if action.TargetID == 0 {
			writeJSON(w, map[string]string{"error": "target_id required"})
			return
		}
		// Check attacker has Loge Impériale
		buildings, _ := h.db.GetColonyBuildings(colonyID)
		hasLodge := false
		for _, b := range buildings {
			if b.BuildingTypeID == 11 && b.Level > 0 {
				hasLodge = true
				break
			}
		}
		if !hasLodge {
			writeJSON(w, map[string]string{"error": "Loge Impériale required to colonize"})
			return
		}

		aphidLevel := 0
		for _, b := range buildings {
			if b.BuildingTypeID == 12 {
				aphidLevel = b.Level
			}
		}
		tax := combat.ColonizationTax(aphidLevel)
		if err := h.db.Colonize(colonyID, action.TargetID, tax); err != nil {
			writeJSON(w, map[string]string{"error": err.Error()})
			return
		}
		writeJSON(w, map[string]interface{}{
			"status":   "colonized",
			"tax_rate": tax,
		})

	default:
		writeJSON(w, map[string]string{"error": "unknown action: " + action.Action})
	}
}