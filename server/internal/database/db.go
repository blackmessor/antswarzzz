package database

import (
	"database/sql"
	"fmt"
	"log"
	"time"

	_ "github.com/go-sql-driver/mysql"
	"github.com/antswarzzz/server/internal/models"
)

type DB struct {
	*sql.DB
}

func New(dsn string) (*DB, error) {
	conn, err := sql.Open("mysql", dsn)
	if err != nil {
		return nil, fmt.Errorf("open: %w", err)
	}
	conn.SetMaxOpenConns(25)
	conn.SetMaxIdleConns(5)
	conn.SetConnMaxLifetime(5 * time.Minute)

	// Wait for DB to be ready
	for i := 0; i < 30; i++ {
		err = conn.Ping()
		if err == nil {
			log.Println("Database connected")
			return &DB{conn}, nil
		}
		log.Printf("Waiting for database... (%d/30)", i+1)
		time.Sleep(2 * time.Second)
	}
	return nil, fmt.Errorf("database not ready after 60s: %w", err)
}

// ── Colony operations ──

func (db *DB) GetColony(colonyID int64) (*models.Colony, error) {
	c := &models.Colony{}
	err := db.QueryRow(`
		SELECT c.id, c.player_id, c.name, c.tdc_size, c.workers_on_food,
		       c.workers_on_materials, c.last_tick_at, c.created_at,
		       COALESCE(r.food, 0), COALESCE(r.materials, 0)
		FROM colonies c
		LEFT JOIN colony_resources r ON r.colony_id = c.id
		WHERE c.id = ?
	`, colonyID).Scan(&c.ID, &c.PlayerID, &c.Name, &c.TDCSize,
		&c.WorkersOnFood, &c.WorkersOnMaterials,
		&c.LastTickAt, &c.CreatedAt,
		&c.Resources.Food, &c.Resources.Materials)
	if err != nil {
		return nil, fmt.Errorf("get colony %d: %w", colonyID, err)
	}
	return c, nil
}

func (db *DB) GetAllActiveColonyIDs() ([]int64, error) {
	rows, err := db.Query(`SELECT id FROM colonies`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var ids []int64
	for rows.Next() {
		var id int64
		if err := rows.Scan(&id); err != nil {
			return nil, err
		}
		ids = append(ids, id)
	}
	return ids, nil
}

// ── Resource operations ──

func (db *DB) UpdateResources(colonyID int64, food, materials int64) error {
	_, err := db.Exec(`
		INSERT INTO colony_resources (colony_id, food, materials) 
		VALUES (?, ?, ?) 
		ON DUPLICATE KEY UPDATE food = VALUES(food), materials = VALUES(materials)
	`, colonyID, food, materials)
	return err
}

func (db *DB) UpdateWorkers(colonyID int64, food, materials int64) error {
	_, err := db.Exec(`
		UPDATE colonies SET workers_on_food = ?, workers_on_materials = ? WHERE id = ?
	`, food, materials, colonyID)
	return err
}

// ── Building operations ──

func (db *DB) GetColonyBuildings(colonyID int64) ([]models.ColonyBuilding, error) {
	rows, err := db.Query(`
		SELECT cb.id, cb.colony_id, cb.building_type_id, cb.level,
		       cb.is_constructing, cb.construction_timer
		FROM colony_buildings cb
		WHERE cb.colony_id = ?
		ORDER BY cb.building_type_id
	`, colonyID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var buildings []models.ColonyBuilding
	for rows.Next() {
		var b models.ColonyBuilding
		if err := rows.Scan(&b.ID, &b.ColonyID, &b.BuildingTypeID, &b.Level,
			&b.IsConstructing, &b.ConstructionTimer); err != nil {
			return nil, err
		}
		buildings = append(buildings, b)
	}
	return buildings, nil
}

func (db *DB) StartBuilding(colonyID int64, buildingTypeID int, timer int64, costMaterials int64) error {
	tx, err := db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	// Deduct materials
	_, err = tx.Exec(`
		UPDATE colony_resources SET materials = materials - ? WHERE colony_id = ? AND materials >= ?
	`, costMaterials, colonyID, costMaterials)
	if err != nil {
		return fmt.Errorf("deduct materials: %w", err)
	}

	// Set constructing
	_, err = tx.Exec(`
		UPDATE colony_buildings 
		SET is_constructing = 1, construction_timer = ?
		WHERE colony_id = ? AND building_type_id = ?
	`, timer, colonyID, buildingTypeID)
	if err != nil {
		return fmt.Errorf("start build: %w", err)
	}

	return tx.Commit()
}

// ── Tick operations ──

func (db *DB) TickConstructionTimer(colonyID int64, interval int64) ([]int, error) {
	// Decrement timers and collect completed buildings
	rows, err := db.Query(`
		UPDATE colony_buildings 
		SET construction_timer = GREATEST(CAST(construction_timer AS SIGNED) - ?, 0)
		WHERE colony_id = ? AND is_constructing = 1
		RETURNING building_type_id, construction_timer
	`, interval, colonyID)
	if err != nil {
		// MariaDB 11.4 supports RETURNING but fallback if not
		return nil, err
	}
	defer rows.Close()
	var completed []int
	for rows.Next() {
		var btID int
		var timer int64
		if err := rows.Scan(&btID, &timer); err != nil {
			return nil, err
		}
		if timer == 0 {
			completed = append(completed, btID)
		}
	}
	return completed, nil
}

func (db *DB) CompleteBuilding(colonyID int64, buildingTypeID int) error {
	_, err := db.Exec(`
		UPDATE colony_buildings 
		SET level = level + 1, is_constructing = 0, construction_timer = 0
		WHERE colony_id = ? AND building_type_id = ?
	`, colonyID, buildingTypeID)
	return err
}

// ── Ant operations ──

func (db *DB) GetColonyAnts(colonyID int64) ([]models.ColonyAnt, error) {
	rows, err := db.Query(`
		SELECT id, colony_id, ant_type_id, location, count, cumulative_xp
		FROM colony_ants WHERE colony_id = ?
	`, colonyID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var ants []models.ColonyAnt
	for rows.Next() {
		var a models.ColonyAnt
		if err := rows.Scan(&a.ID, &a.ColonyID, &a.AntTypeID, &a.Location, &a.Count, &a.CumulativeXP); err != nil {
			return nil, err
		}
		ants = append(ants, a)
	}
	return ants, nil
}

func (db *DB) AddAnts(colonyID int64, antTypeID int, count int64) error {
	_, err := db.Exec(`
		INSERT INTO colony_ants (colony_id, ant_type_id, location, count, cumulative_xp)
		VALUES (?, ?, 'home', ?, 0)
		ON DUPLICATE KEY UPDATE count = count + VALUES(count)
	`, colonyID, antTypeID, count)
	return err
}

// ── Worker count ──

func (db *DB) GetWorkerCount(colonyID int64) (int64, error) {
	var count int64
	err := db.QueryRow(`
		SELECT COALESCE(SUM(count), 0) FROM colony_ants
		WHERE colony_id = ? AND ant_type_id = 0 AND location = 'home'
	`, colonyID).Scan(&count)
	return count, err
}

// ── Tick finalization ──

func (db *DB) FinalizeTick(colonyID int64) error {
	_, err := db.Exec(`UPDATE colonies SET last_tick_at = UTC_TIMESTAMP() WHERE id = ?`, colonyID)
	return err
}

// ── Colony creation ──

func (db *DB) CreateColony(playerID int64, name string) (int64, error) {
	tx, err := db.Begin()
	if err != nil {
		return 0, err
	}
	defer tx.Rollback()

	res, err := tx.Exec(`
		INSERT INTO colonies (player_id, name, tdc_size) VALUES (?, ?, ?)
	`, playerID, name, models.InitialTDCSize)
	if err != nil {
		return 0, err
	}
	colonyID, _ := res.LastInsertId()

	// Create resources
	_, err = tx.Exec(`INSERT INTO colony_resources (colony_id, food, materials) VALUES (?, ?, ?)`,
		colonyID, models.InitialFood, models.InitialMaterials)
	if err != nil {
		return 0, err
	}

	// Create initial buildings — all 13, level 0
	buildingIDs := []int{1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13}
	for _, btID := range buildingIDs {
		_, err = tx.Exec(`
			INSERT INTO colony_buildings (colony_id, building_type_id, level) VALUES (?, ?, 0)
		`, colonyID, btID)
		if err != nil {
			return 0, err
		}
	}

	// Create research slots — all 10, level 0
	researchIDs := []int{1, 2, 3, 4, 5, 6, 7, 8, 9, 10}
	for _, rtID := range researchIDs {
		_, err = tx.Exec(`
			INSERT INTO colony_research (colony_id, research_type_id, level) VALUES (?, ?, 0)
		`, colonyID, rtID)
		if err != nil {
			return 0, err
		}
	}

	// Give 5 initial workers
	_, err = tx.Exec(`
		INSERT INTO colony_ants (colony_id, ant_type_id, location, count) VALUES (?, 0, 'home', 5)
	`, colonyID)
	if err != nil {
		return 0, err
	}

	return colonyID, tx.Commit()
}

// ── Player operations ──

func (db *DB) CreatePlayer(username string) (int64, error) {
	res, err := db.Exec(`
		INSERT INTO players (username, email, password_hash) VALUES (?, CONCAT(?, '@antswarzzz.local'), 'not-set')
	`, username, username)
	if err != nil {
		return 0, err
	}
	return res.LastInsertId()
}

func (db *DB) GetPlayerColony(playerID int64) (int64, error) {
	var colonyID int64
	err := db.QueryRow(`SELECT id FROM colonies WHERE player_id = ? LIMIT 1`, playerID).Scan(&colonyID)
	if err == sql.ErrNoRows {
		return 0, nil
	}
	return colonyID, err
}

// ── Phase 2: Breed queue ──

func (db *DB) QueueBreed(colonyID int64, antTypeID int) (int, error) {
	var pos int
	err := db.QueryRow(`
		INSERT INTO breed_queue (colony_id, position, ant_type_id)
		SELECT ?, COALESCE(MAX(position), 0) + 1, ?
		FROM breed_queue WHERE colony_id = ?
	`, colonyID, antTypeID, colonyID).Err()
	if err != nil {
		return 0, err
	}
	err = db.QueryRow(`SELECT MAX(position) FROM breed_queue WHERE colony_id = ?`, colonyID).Scan(&pos)
	return pos, err
}

func (db *DB) GetBreedQueue(colonyID int64) ([]struct {
	Position  int
	AntTypeID int
}, error) {
	rows, err := db.Query(`SELECT position, ant_type_id FROM breed_queue WHERE colony_id = ? ORDER BY position`, colonyID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var q []struct {
		Position  int
		AntTypeID int
	}
	for rows.Next() {
		var item struct {
			Position  int
			AntTypeID int
		}
		if err := rows.Scan(&item.Position, &item.AntTypeID); err != nil {
			return nil, err
		}
		q = append(q, item)
	}
	return q, nil
}

func (db *DB) StartBreed(colonyID int64, antTypeID int, position int, timer int64, foodCost int64) error {
	tx, err := db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	_, err = tx.Exec(`UPDATE colony_resources SET food = food - ? WHERE colony_id = ? AND food >= ?`,
		foodCost, colonyID, foodCost)
	if err != nil {
		return fmt.Errorf("deduct food: %w", err)
	}

	_, err = tx.Exec(`
		INSERT INTO active_breed (colony_id, ant_type_id, timer, queue_position)
		VALUES (?, ?, ?, ?)
		ON DUPLICATE KEY UPDATE ant_type_id = VALUES(ant_type_id), timer = VALUES(timer), queue_position = VALUES(queue_position)
	`, colonyID, antTypeID, timer, position)
	if err != nil {
		return fmt.Errorf("start breed: %w", err)
	}
	return tx.Commit()
}

func (db *DB) GetActiveBreed(colonyID int64) (*int, *int64, *int, error) {
	var antTypeID int
	var timer int64
	var pos int
	err := db.QueryRow(`SELECT ant_type_id, timer, queue_position FROM active_breed WHERE colony_id = ?`,
		colonyID).Scan(&antTypeID, &timer, &pos)
	if err == sql.ErrNoRows {
		return nil, nil, nil, nil
	}
	if err != nil {
		return nil, nil, nil, err
	}
	return &antTypeID, &timer, &pos, nil
}

func (db *DB) AdvanceBreedTimer(colonyID int64, interval int64) (bool, int, error) {
	// Decrement timer; if 0 or negative, breed is complete
	_, err := db.Exec(`
		UPDATE active_breed SET timer = GREATEST(CAST(timer AS SIGNED) - ?, 0) WHERE colony_id = ?
	`, interval, colonyID)
	if err != nil {
		return false, 0, err
	}

	var timer int64
	var antTypeID int
	err = db.QueryRow(`SELECT ant_type_id, timer FROM active_breed WHERE colony_id = ?`, colonyID).Scan(&antTypeID, &timer)
	if err == sql.ErrNoRows {
		return false, 0, nil
	}
	if err != nil {
		return false, 0, err
	}
	return timer == 0, antTypeID, nil
}

func (db *DB) CompleteBreed(colonyID int64, antTypeID int) error {
	tx, err := db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	// Add ant
	_, err = tx.Exec(`
		INSERT INTO colony_ants (colony_id, ant_type_id, location, count, cumulative_xp)
		VALUES (?, ?, 'home', 1, 0)
		ON DUPLICATE KEY UPDATE count = count + 1
	`, colonyID, antTypeID)
	if err != nil {
		return err
	}

	// Advance queue
	_, err = tx.Exec(`DELETE FROM active_breed WHERE colony_id = ?`, colonyID)
	if err != nil {
		return err
	}
	_, err = tx.Exec(`
		DELETE FROM breed_queue WHERE colony_id = ? ORDER BY position LIMIT 1
	`, colonyID)
	if err != nil {
		return err
	}
	// Re-index positions
	_, err = tx.Exec(`
		UPDATE breed_queue SET position = (@r := @r + 1)
		WHERE colony_id = ?
		ORDER BY position
	`, colonyID)
	if err != nil {
		return err
	}

	return tx.Commit()
}

// ── Phase 2: Research ──

func (db *DB) StartResearch(colonyID int64, researchTypeID int, targetLevel int, timer int64) error {
	_, err := db.Exec(`
		UPDATE colony_research
		SET is_researching = 1, researching_level = ?, research_timer = ?
		WHERE colony_id = ? AND research_type_id = ?
	`, targetLevel, timer, colonyID, researchTypeID)
	return err
}

func (db *DB) GetColonyResearch(colonyID int64) ([]struct {
	ResearchTypeID  int
	Level           int
	IsResearching   bool
	ResearchingLevel int
	ResearchTimer   int64
}, error) {
	rows, err := db.Query(`
		SELECT research_type_id, level, is_researching, researching_level, research_timer
		FROM colony_research WHERE colony_id = ? ORDER BY research_type_id
	`, colonyID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var list []struct {
		ResearchTypeID  int
		Level           int
		IsResearching   bool
		ResearchingLevel int
		ResearchTimer   int64
	}
	for rows.Next() {
		var r struct {
			ResearchTypeID  int
			Level           int
			IsResearching   bool
			ResearchingLevel int
			ResearchTimer   int64
		}
		if err := rows.Scan(&r.ResearchTypeID, &r.Level, &r.IsResearching, &r.ResearchingLevel, &r.ResearchTimer); err != nil {
			return nil, err
		}
		list = append(list, r)
	}
	return list, nil
}

func (db *DB) AdvanceResearchTimer(colonyID int64, interval int64) ([]int, error) {
	// Decrement all researching timers
	_, err := db.Exec(`
		UPDATE colony_research SET research_timer = GREATEST(CAST(research_timer AS SIGNED) - ?, 0)
		WHERE colony_id = ? AND is_researching = 1
	`, interval, colonyID)
	if err != nil {
		return nil, err
	}

	// Find completed research
	rows, err := db.Query(`
		SELECT research_type_id FROM colony_research
		WHERE colony_id = ? AND is_researching = 1 AND research_timer = 0
	`, colonyID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var completed []int
	for rows.Next() {
		var rtID int
		if err := rows.Scan(&rtID); err != nil {
			return nil, err
		}
		completed = append(completed, rtID)
	}
	return completed, nil
}

func (db *DB) CompleteResearch(colonyID int64, researchTypeID int) error {
	_, err := db.Exec(`
		UPDATE colony_research
		SET level = researching_level, is_researching = 0, researching_level = 0, research_timer = 0
		WHERE colony_id = ? AND research_type_id = ?
	`, colonyID, researchTypeID)
	return err
}

// ── Phase 2: Evolution ──

func (db *DB) AddXPToAnts(colonyID int64, antTypeID int, xp int64) error {
	_, err := db.Exec(`
		UPDATE colony_ants SET cumulative_xp = cumulative_xp + ?
		WHERE colony_id = ? AND ant_type_id = ? AND location = 'home'
	`, xp, colonyID, antTypeID)
	return err
}

func (db *DB) EvolveAnts(colonyID int64, fromTypeID int, toTypeID int, count int64) error {
	tx, err := db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	// Deduct from source
	_, err = tx.Exec(`
		UPDATE colony_ants SET count = count - ?, cumulative_xp = cumulative_xp - (100 * ?)
		WHERE colony_id = ? AND ant_type_id = ? AND location = 'home'
	`, count, count, colonyID, fromTypeID)
	if err != nil {
		return err
	}

	// Add to destination
	_, err = tx.Exec(`
		INSERT INTO colony_ants (colony_id, ant_type_id, location, count, cumulative_xp)
		VALUES (?, ?, 'home', ?, 0)
		ON DUPLICATE KEY UPDATE count = count + VALUES(count)
	`, colonyID, toTypeID, count)
	if err != nil {
		return err
	}

	return tx.Commit()
}

// ── Phase 2: Upkeep / Military count ──

func (db *DB) GetMilitaryAntCount(colonyID int64) (int64, error) {
	var count int64
	err := db.QueryRow(`
		SELECT COALESCE(SUM(count), 0) FROM colony_ants
		WHERE colony_id = ? AND ant_type_id > 0 AND location = 'home'
	`, colonyID).Scan(&count)
	return count, err
}

// ── Phase 3: Hunts ──

func (db *DB) StartHunt(colonyID int64, targetArea int64, timer int64) (int64, error) {
	res, err := db.Exec(`
		INSERT INTO hunts (colony_id, target_area, timer, status) VALUES (?, ?, ?, 'active')
	`, colonyID, targetArea, timer)
	if err != nil {
		return 0, err
	}
	return res.LastInsertId()
}

func (db *DB) GetActiveHunts(colonyID int64) ([]struct {
	ID         int64
	TargetArea int64
	Timer      int64
}, error) {
	rows, err := db.Query(`
		SELECT id, target_area, timer FROM hunts WHERE colony_id = ? AND status = 'active'
	`, colonyID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var hunts []struct {
		ID         int64
		TargetArea int64
		Timer      int64
	}
	for rows.Next() {
		var h struct {
			ID         int64
			TargetArea int64
			Timer      int64
		}
		if err := rows.Scan(&h.ID, &h.TargetArea, &h.Timer); err != nil {
			return nil, err
		}
		hunts = append(hunts, h)
	}
	return hunts, nil
}

func (db *DB) AdvanceHuntsTimer(colonyID int64, interval int64) ([]int64, error) {
	_, err := db.Exec(`
		UPDATE hunts SET timer = GREATEST(CAST(timer AS SIGNED) - ?, 0)
		WHERE colony_id = ? AND status = 'active'
	`, interval, colonyID)
	if err != nil {
		return nil, err
	}

	rows, err := db.Query(`
		SELECT id FROM hunts WHERE colony_id = ? AND status = 'active' AND timer = 0
	`, colonyID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var ids []int64
	for rows.Next() {
		var id int64
		if err := rows.Scan(&id); err != nil {
			return nil, err
		}
		ids = append(ids, id)
	}
	return ids, nil
}

func (db *DB) CompleteHunt(huntID int64, won bool, tdcGain int64) error {
	status := "failed"
	if won {
		status = "completed"
	}
	tx, err := db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	_, err = tx.Exec(`UPDATE hunts SET status = ? WHERE id = ?`, status, huntID)
	if err != nil {
		return err
	}

	if won {
		// Get colony_id and update TDC
		var colonyID int64
		err = tx.QueryRow(`SELECT colony_id FROM hunts WHERE id = ?`, huntID).Scan(&colonyID)
		if err != nil {
			return err
		}
		_, err = tx.Exec(`UPDATE colonies SET tdc_size = tdc_size + ? WHERE id = ?`, tdcGain, colonyID)
		if err != nil {
			return err
		}
	}
	return tx.Commit()
}

func (db *DB) GetHuntColonyID(huntID int64) (int64, error) {
	var colonyID int64
	err := db.QueryRow(`SELECT colony_id FROM hunts WHERE id = ?`, huntID).Scan(&colonyID)
	return colonyID, err
}

// ── Phase 3: TDC update ──

func (db *DB) UpdateTDC(colonyID int64, tdcGain int64) error {
	_, err := db.Exec(`UPDATE colonies SET tdc_size = tdc_size + ? WHERE id = ?`, tdcGain, colonyID)
	return err
}

func (db *DB) MoveAntsToLocation(colonyID int64, antTypeID int, count int64, location string) error {
	// Deduct from home
	_, err := db.Exec(`
		UPDATE colony_ants SET count = count - ?
		WHERE colony_id = ? AND ant_type_id = ? AND location = 'home' AND count >= ?
	`, count, colonyID, antTypeID, count)
	if err != nil {
		return err
	}
	// Add to target location
	_, err = db.Exec(`
		INSERT INTO colony_ants (colony_id, ant_type_id, location, count, cumulative_xp)
		VALUES (?, ?, ?, ?, 0)
		ON DUPLICATE KEY UPDATE count = count + VALUES(count)
	`, colonyID, antTypeID, location, count)
	return err
}

func (db *DB) ReturnAntsHome(colonyID int64, antTypeID int, count int64, location string) error {
	// Deduct from location
	_, err := db.Exec(`
		UPDATE colony_ants SET count = count - ?
		WHERE colony_id = ? AND ant_type_id = ? AND location = ?
	`, count, colonyID, antTypeID, location)
	if err != nil {
		return err
	}
	_, err = db.Exec(`
		INSERT INTO colony_ants (colony_id, ant_type_id, location, count, cumulative_xp)
		VALUES (?, ?, 'home', ?, 0)
		ON DUPLICATE KEY UPDATE count = count + VALUES(count)
	`, colonyID, antTypeID, count)
	return err
}

// ── Phase 4: PvP Attacks ──

func (db *DB) StartPvPAttack(attackerID, defenderID int64, timer int64) (int64, error) {
	res, err := db.Exec(`
		INSERT INTO attacks (attacker_colony_id, defender_colony_id, attack_type, timer, status)
		VALUES (?, ?, 'tdc', ?, 'active')
	`, attackerID, defenderID, timer)
	if err != nil {
		return 0, err
	}
	return res.LastInsertId()
}

func (db *DB) GetActiveAttacksForColony(colonyID int64) ([]struct {
	ID                 int64
	AttackerColonyID   int64
	DefenderColonyID   int64
	Timer              int64
}, error) {
	rows, err := db.Query(`
		SELECT id, attacker_colony_id, defender_colony_id, timer
		FROM attacks WHERE status = 'active' AND (attacker_colony_id = ? OR defender_colony_id = ?)
	`, colonyID, colonyID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var attacks []struct {
		ID                 int64
		AttackerColonyID   int64
		DefenderColonyID   int64
		Timer              int64
	}
	for rows.Next() {
		var a struct {
			ID                 int64
			AttackerColonyID   int64
			DefenderColonyID   int64
			Timer              int64
		}
		if err := rows.Scan(&a.ID, &a.AttackerColonyID, &a.DefenderColonyID, &a.Timer); err != nil {
			return nil, err
		}
		attacks = append(attacks, a)
	}
	return attacks, nil
}

func (db *DB) AdvanceAttackTimers(interval int64) ([]int64, error) {
	_, err := db.Exec(`
		UPDATE attacks SET timer = GREATEST(CAST(timer AS SIGNED) - ?, 0)
		WHERE status = 'active'
	`, interval)
	if err != nil {
		return nil, err
	}

	rows, err := db.Query(`SELECT id FROM attacks WHERE status = 'active' AND timer = 0`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var ids []int64
	for rows.Next() {
		var id int64
		if err := rows.Scan(&id); err != nil {
			return nil, err
		}
		ids = append(ids, id)
	}
	return ids, nil
}

func (db *DB) ResolveAttack(attackID int64, attackerWins bool, tdcGain, foodStolen, matsStolen int64, colonyCaptured bool) error {
	tx, err := db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	status := "resolved_defender_win"
	if attackerWins {
		status = "resolved_attacker_win"
	}

	_, err = tx.Exec(`UPDATE attacks SET status = ? WHERE id = ?`, status, attackID)
	if err != nil {
		return err
	}

	if attackerWins {
		var attID, defID int64
		err = tx.QueryRow(`SELECT attacker_colony_id, defender_colony_id FROM attacks WHERE id = ?`, attackID).Scan(&attID, &defID)
		if err != nil {
			return err
		}

		_, err = tx.Exec(`UPDATE colonies SET tdc_size = tdc_size + ? WHERE id = ?`, tdcGain, attID)
		if err != nil {
			return err
		}
		_, err = tx.Exec(`UPDATE colonies SET tdc_size = GREATEST(CAST(tdc_size AS SIGNED) - ?, 0) WHERE id = ?`, tdcGain, defID)
		if err != nil {
			return err
		}

		if foodStolen > 0 {
			tx.Exec(`UPDATE colony_resources SET food = GREATEST(CAST(food AS SIGNED) - ?, 0) WHERE colony_id = ?`, foodStolen, defID)
			tx.Exec(`UPDATE colony_resources SET food = food + ? WHERE colony_id = ?`, foodStolen, attID)
		}
		if matsStolen > 0 {
			tx.Exec(`UPDATE colony_resources SET materials = GREATEST(CAST(materials AS SIGNED) - ?, 0) WHERE colony_id = ?`, matsStolen, defID)
			tx.Exec(`UPDATE colony_resources SET materials = materials + ? WHERE colony_id = ?`, matsStolen, attID)
		}
	}

	return tx.Commit()
}

// ── Phase 4: Matchmaking ──

func (db *DB) GetAttackTargets(attackerID int64, attackerTDC int64, limit int) ([]models.Colony, error) {
	minTDC := int64(float64(attackerTDC) * 0.50)
	maxTDC := int64(float64(attackerTDC) * 3.00)

	rows, err := db.Query(`
		SELECT c.id, c.player_id, c.name, c.tdc_size, c.workers_on_food, c.workers_on_materials,
		       c.last_tick_at, c.created_at,
		       COALESCE(r.food, 0), COALESCE(r.materials, 0)
		FROM colonies c
		LEFT JOIN colony_resources r ON r.colony_id = c.id
		WHERE c.id != ?
		  AND c.tdc_size BETWEEN ? AND ?
		ORDER BY ABS(CAST(c.tdc_size AS SIGNED) - ?) ASC
		LIMIT ?
	`, attackerID, minTDC, maxTDC, attackerTDC, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var targets []models.Colony
	for rows.Next() {
		var c models.Colony
		if err := rows.Scan(&c.ID, &c.PlayerID, &c.Name, &c.TDCSize,
			&c.WorkersOnFood, &c.WorkersOnMaterials,
			&c.LastTickAt, &c.CreatedAt,
			&c.Resources.Food, &c.Resources.Materials); err != nil {
			return nil, err
		}
		targets = append(targets, c)
	}
	return targets, nil
}

// ── Phase 4: Colonization ──

func (db *DB) Colonize(colonizerID, colonizedID int64, taxRate float64) error {
	_, err := db.Exec(`
		INSERT INTO colonizations (colonizer_colony_id, colonized_colony_id, tax_rate)
		VALUES (?, ?, ?)
		ON DUPLICATE KEY UPDATE tax_rate = VALUES(tax_rate)
	`, colonizerID, colonizedID, taxRate)
	return err
}

func (db *DB) GetColonizer(colonyID int64) (int64, float64, error) {
	var colonizerID int64
	var taxRate float64
	err := db.QueryRow(`
		SELECT colonizer_colony_id, tax_rate FROM colonizations WHERE colonized_colony_id = ?
	`, colonyID).Scan(&colonizerID, &taxRate)
	if err != nil {
		return 0, 0, err
	}
	return colonizerID, taxRate, nil
}

func (db *DB) GetVassals(colonizerID int64) ([]int64, error) {
	rows, err := db.Query(`SELECT colonized_colony_id FROM colonizations WHERE colonizer_colony_id = ?`, colonizerID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var vassals []int64
	for rows.Next() {
		var id int64
		if err := rows.Scan(&id); err != nil {
			return nil, err
		}
		vassals = append(vassals, id)
	}
	return vassals, nil
}