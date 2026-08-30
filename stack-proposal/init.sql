-- ============================================================================
-- Antswarzzz — Database Initialization Script
-- MariaDB 11.4+
-- Auto-mounted by Docker Compose at /docker-entrypoint-initdb.d/01-schema.sql
-- ============================================================================

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- ---------------------------------------------------------------------------
-- 1. PLAYERS & COLONIES
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS players (
    id              INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    username        VARCHAR(32)     NOT NULL,
    email           VARCHAR(255)    NOT NULL,
    password_hash   VARCHAR(255)    NOT NULL,
    created_at      DATETIME        NOT NULL DEFAULT UTC_TIMESTAMP(),
    last_login      DATETIME        NULL,
    is_active       TINYINT(1)      NOT NULL DEFAULT 1,
    PRIMARY KEY (id),
    UNIQUE KEY uk_username (username),
    UNIQUE KEY uk_email (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS colonies (
    id                  INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    player_id           INT UNSIGNED    NOT NULL,
    name                VARCHAR(64)     NOT NULL,
    tdc_size            INT UNSIGNED    NOT NULL DEFAULT 50,
    workers_on_food     INT UNSIGNED    NOT NULL DEFAULT 0,
    workers_on_materials INT UNSIGNED   NOT NULL DEFAULT 0,
    last_tick_at        DATETIME        NOT NULL DEFAULT UTC_TIMESTAMP(),
    created_at          DATETIME        NOT NULL DEFAULT UTC_TIMESTAMP(),
    updated_at          DATETIME        NOT NULL DEFAULT UTC_TIMESTAMP() ON UPDATE UTC_TIMESTAMP(),
    PRIMARY KEY (id),
    CONSTRAINT fk_colonies_player FOREIGN KEY (player_id) REFERENCES players(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS colony_resources (
    colony_id   INT UNSIGNED    NOT NULL,
    food        BIGINT UNSIGNED NOT NULL DEFAULT 0,
    materials   BIGINT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (colony_id),
    CONSTRAINT fk_resources_colony FOREIGN KEY (colony_id) REFERENCES colonies(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- 2. STATIC REFERENCE: ANT TYPES
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS ant_types (
    id                      TINYINT UNSIGNED NOT NULL,
    slug                    VARCHAR(32)      NOT NULL,
    name                    VARCHAR(64)      NOT NULL,
    abbreviation            VARCHAR(8)       NOT NULL,
    base_hp                 SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    base_attack             SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    base_defense            SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    breed_time_seconds      INT UNSIGNED     NULL,
    food_cost               INT UNSIGNED     NOT NULL,
    is_worker               TINYINT(1)       NOT NULL DEFAULT 0,
    is_breedable            TINYINT(1)       NOT NULL DEFAULT 1,
    evolves_to_id           TINYINT UNSIGNED NULL,
    death_order             TINYINT UNSIGNED NOT NULL,
    unlock_building_slug    VARCHAR(32)      NULL,
    unlock_building_level   INT UNSIGNED     NULL,
    unlock_research_slug    VARCHAR(32)      NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uk_ant_slug (slug),
    CONSTRAINT fk_ant_evolves FOREIGN KEY (evolves_to_id) REFERENCES ant_types(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Seed: 15 ant types (id 0-14, matching spec)
INSERT INTO ant_types (id, slug, name, abbreviation, base_hp, base_attack, base_defense, breed_time_seconds, food_cost, is_worker, is_breedable, evolves_to_id, death_order, unlock_building_slug, unlock_building_level, unlock_research_slug) VALUES
(0,  'ouvriere',           'Ouvrière',             'Wrk',  0,  0,  0,  60,    5,  1, 1, NULL, 1,  NULL,           NULL, NULL),
(1,  'jsn',                'Jeune Soldate Naine',  'JSN',  8,  3,  2,  300,   10, 0, 1, NULL, 2,  'combat_room',  1,    NULL),
(2,  'sn',                 'Soldate Naine',        'SN',   10, 5,  4,  450,   14, 0, 1, 3,    3,  'combat_room',  3,    NULL),
(3,  'ne',                 'Naine d''Élite',       'NE',   13, 7,  6,  NULL,  18, 0, 0, NULL, 4,  NULL,           NULL, NULL),
(4,  'js',                 'Jeune Soldate',        'JS',   16, 10, 9,  740,   16, 0, 1, NULL, 5,  'combat_room',  5,    NULL),
(5,  's',                  'Soldate',              'S',    20, 15, 14, 1000,  22, 0, 1, 6,    6,  'barracks',     1,    NULL),
(6,  'se',                 'Soldate d''Élite',     'SE',   27, 24, 23, NULL,  28, 0, 0, NULL, 12, NULL,           NULL, NULL),
(7,  'c',                  'Concierge',            'C',    30, 1,  25, 1410,  30, 0, 1, 8,    7,  NULL,           NULL, 'comm_animaux'),
(8,  'ce',                 'Concierge d''Élite',   'CE',   40, 1,  35, NULL,  38, 0, 0, NULL, 8,  NULL,           NULL, NULL),
(9,  'a',                  'Artilleuse',           'A',    10, 30, 15, 1440,  28, 0, 1, NULL, 9,  NULL,           NULL, 'acide'),
(10, 'ae',                 'Artilleuse d''Élite',  'AE',   12, 35, 18, 1520,  35, 0, 1, NULL, 10, NULL,           NULL, 'acide'),
(11, 'tk',                 'Tank',                 'Tk',   35, 55, 1,  1860,  45, 0, 1, 12,   11, 'barracks',     22,   'genetique'),
(12, 'tke',                'Tank d''Élite',        'TkE',  50, 80, 1,  NULL,  55, 0, 0, NULL, 13, NULL,           NULL, NULL),
(13, 'tu',                 'Tueuse',               'Tu',   50, 50, 50, 2740,  60, 0, 1, 14,   14, NULL,           NULL, 'poison'),
(14, 'tue',                'Tueuse d''Élite',      'TuE',  55, 55, 55, NULL,  72, 0, 0, NULL, 15, NULL,           NULL, NULL);

-- ---------------------------------------------------------------------------
-- 3. STATIC REFERENCE: BUILDING TYPES
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS building_types (
    id                  TINYINT UNSIGNED NOT NULL,
    slug                VARCHAR(32)      NOT NULL,
    name                VARCHAR(64)      NOT NULL,
    category            ENUM('A','B','C','D') NOT NULL,
    base_cost_materials INT UNSIGNED     NOT NULL DEFAULT 0,
    base_cost_food      INT UNSIGNED     NULL,
    base_cost_workers   INT UNSIGNED     NULL,
    base_time_seconds   INT UNSIGNED     NOT NULL,
    effect_description  VARCHAR(255)     NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uk_building_slug (slug)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Seed: 13 building types, matching spec §3.2
INSERT INTO building_types (id, slug, name, category, base_cost_materials, base_cost_food, base_cost_workers, base_time_seconds, effect_description) VALUES
(1,  'mushroom_farm',   'Champignonnière',         'B', 90,     NULL, NULL, 120, 'Passive daily food: floor(122 * 1.70^(lvl-1))'),
(2,  'food_warehouse',  'Entrepôt de nourriture',  'D', 600,    NULL, NULL, 180, 'Food storage: 1700 + 1200*(2^lvl - 1)'),
(3,  'mat_warehouse',   'Entrepôt de matériaux',   'D', 600,    NULL, NULL, 180, 'Material storage: 1700 + 1200*(2^lvl - 1)'),
(4,  'hatchery',        'Couveuse',                'A', 2000,   NULL, NULL, 1000,'+10% laying speed per level'),
(5,  'solarium',        'Solarium',                'A', 1400,   NULL, NULL, 300, '+10% laying speed per level'),
(6,  'lab',             'Laboratoire',             'A', 300,    NULL, NULL, 120, 'Enables research'),
(7,  'analysis_room',   'Salle d''analyse',        'A', 800,    NULL, NULL, 200, '-10% research time per level'),
(8,  'combat_room',     'Salle de combat',         'C', 2500,   4000, 50,   200, 'Unlocks military units'),
(9,  'barracks',        'Caserne',                 'C', 5000,   8000, 100,  200, 'Unlocks advanced military units'),
(10, 'dome',            'Dôme',                    'C', 10000,  16000,200,  200, 'Defense HP bonus: 10% + 5%/lvl'),
(11, 'imperial_lodge',  'Loge Impériale',          'C', 20000,  32000,400,  200, 'Defense HP bonus: 30% + 15%/lvl; colonization target'),
(12, 'aphid_farm',      'Étable à pucerons',       'A', 100,    NULL, NULL, 200, '+1% pillage, +5% trade per level'),
(13, 'mealybug_farm',   'Étable à cochenilles',    'A', 80,     NULL, NULL, 120, '+10% units gaining XP per level');

-- ---------------------------------------------------------------------------
-- 4. STATIC REFERENCE: RESEARCH TYPES
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS research_types (
    id                          TINYINT UNSIGNED NOT NULL,
    slug                        VARCHAR(32)      NOT NULL,
    name                        VARCHAR(64)      NOT NULL,
    base_cost_workers           INT UNSIGNED     NOT NULL,
    base_cost_food              INT UNSIGNED     NOT NULL,
    base_cost_materials         INT UNSIGNED     NOT NULL,
    base_time_seconds           INT UNSIGNED     NOT NULL,
    prerequisite_research_id    TINYINT UNSIGNED NULL,
    prerequisite_building_slug  VARCHAR(32)      NULL,
    effect_type                 VARCHAR(32)      NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uk_research_slug (slug),
    CONSTRAINT fk_research_prereq FOREIGN KEY (prerequisite_research_id) REFERENCES research_types(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Seed: 10 research types (matching spec §5.3)
-- Base costs are representative; spec uses scaling formulas (workers ×2, food ×2.5, mat ×1.5, time ×1.6 per level)
INSERT INTO research_types (id, slug, name, base_cost_workers, base_cost_food, base_cost_materials, base_time_seconds, prerequisite_research_id, prerequisite_building_slug, effect_type) VALUES
(1,  'tech_ponte',     'Technique de Ponte',       100,  200,  100,  600,   NULL, 'lab', 'breeding_speed'),
(2,  'bouclier',       'Bouclier Thoracique',      100,  200,  100,  600,   NULL, 'lab', 'unit_hp'),
(3,  'armes',          'Armes',                    100,  200,  100,  600,   NULL, 'lab', 'unit_damage'),
(4,  'architecture',   'Architecture',             100,  200,  100,  600,   NULL, 'lab', 'build_time'),
(5,  'vitesse_chasse', 'Vitesse de Chasse',        100,  200,  100,  600,   NULL, 'lab', 'hunt_time'),
(6,  'vitesse_attaque','Vitesse d''Attaque',       100,  200,  100,  600,   NULL, 'lab', 'attack_time'),
(7,  'comm_animaux',   'Communication Animaux',    200,  400,  200,  1200,  4,    'lab', 'unlock_only'),
(8,  'genetique',      'Génétique',                300,  600,  300,  1800,  3,    'lab', 'unlock_only'),
(9,  'acide',          'Acide',                    400,  800,  400,  2400,  8,    'lab', 'unlock_only'),
(10, 'poison',         'Poison',                   500,  1000, 500,  3600,  9,    'lab', 'unlock_only');

-- ---------------------------------------------------------------------------
-- 5. COLONY BUILDINGS (mutable)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS colony_buildings (
    id                  INT UNSIGNED     NOT NULL AUTO_INCREMENT,
    colony_id           INT UNSIGNED     NOT NULL,
    building_type_id    TINYINT UNSIGNED NOT NULL,
    level               INT UNSIGNED     NOT NULL DEFAULT 0,
    is_constructing     TINYINT(1)       NOT NULL DEFAULT 0,
    construction_timer  INT UNSIGNED     NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE KEY uk_colony_building (colony_id, building_type_id),
    CONSTRAINT fk_cb_colony FOREIGN KEY (colony_id) REFERENCES colonies(id) ON DELETE CASCADE,
    CONSTRAINT fk_cb_type FOREIGN KEY (building_type_id) REFERENCES building_types(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- 6. COLONY RESEARCH (mutable)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS colony_research (
    id                  INT UNSIGNED     NOT NULL AUTO_INCREMENT,
    colony_id           INT UNSIGNED     NOT NULL,
    research_type_id    TINYINT UNSIGNED NOT NULL,
    level               INT UNSIGNED     NOT NULL DEFAULT 0,
    is_researching      TINYINT(1)       NOT NULL DEFAULT 0,
    researching_level   INT UNSIGNED     NOT NULL DEFAULT 0,
    research_timer      INT UNSIGNED     NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE KEY uk_colony_research (colony_id, research_type_id),
    CONSTRAINT fk_cr_colony FOREIGN KEY (colony_id) REFERENCES colonies(id) ON DELETE CASCADE,
    CONSTRAINT fk_cr_type FOREIGN KEY (research_type_id) REFERENCES research_types(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- 7. COLONY ANTS (aggregated per type per location)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS colony_ants (
    id              INT UNSIGNED     NOT NULL AUTO_INCREMENT,
    colony_id       INT UNSIGNED     NOT NULL,
    ant_type_id     TINYINT UNSIGNED NOT NULL,
    location        ENUM('home','tdc','hunting','attacking') NOT NULL DEFAULT 'home',
    count           INT UNSIGNED     NOT NULL DEFAULT 0,
    cumulative_xp   BIGINT UNSIGNED  NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE KEY uk_colony_ant_location (colony_id, ant_type_id, location),
    CONSTRAINT fk_ca_colony FOREIGN KEY (colony_id) REFERENCES colonies(id) ON DELETE CASCADE,
    CONSTRAINT fk_ca_type FOREIGN KEY (ant_type_id) REFERENCES ant_types(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- 8. BREEDING
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS breed_queue (
    id              INT UNSIGNED     NOT NULL AUTO_INCREMENT,
    colony_id       INT UNSIGNED     NOT NULL,
    position        INT UNSIGNED     NOT NULL,
    ant_type_id     TINYINT UNSIGNED NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uk_breed_queue_pos (colony_id, position),
    CONSTRAINT fk_bq_colony FOREIGN KEY (colony_id) REFERENCES colonies(id) ON DELETE CASCADE,
    CONSTRAINT fk_bq_ant_type FOREIGN KEY (ant_type_id) REFERENCES ant_types(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS active_breed (
    colony_id       INT UNSIGNED     NOT NULL,
    ant_type_id     TINYINT UNSIGNED NOT NULL,
    timer           INT UNSIGNED     NOT NULL,
    queue_position  INT UNSIGNED     NOT NULL DEFAULT 1,
    PRIMARY KEY (colony_id),
    CONSTRAINT fk_ab_colony FOREIGN KEY (colony_id) REFERENCES colonies(id) ON DELETE CASCADE,
    CONSTRAINT fk_ab_ant_type FOREIGN KEY (ant_type_id) REFERENCES ant_types(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- 9. HUNTS (PvE)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS hunts (
    id              INT UNSIGNED NOT NULL AUTO_INCREMENT,
    colony_id       INT UNSIGNED NOT NULL,
    target_area     INT UNSIGNED NOT NULL,
    timer           INT UNSIGNED NOT NULL,
    status          ENUM('active','completed','failed') NOT NULL DEFAULT 'active',
    PRIMARY KEY (id),
    CONSTRAINT fk_hunts_colony FOREIGN KEY (colony_id) REFERENCES colonies(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS hunt_armies (
    hunt_id         INT UNSIGNED NOT NULL,
    colony_ant_id   INT UNSIGNED NOT NULL,
    count           INT UNSIGNED NOT NULL,
    PRIMARY KEY (hunt_id, colony_ant_id),
    CONSTRAINT fk_ha_hunt FOREIGN KEY (hunt_id) REFERENCES hunts(id) ON DELETE CASCADE,
    CONSTRAINT fk_ha_ant FOREIGN KEY (colony_ant_id) REFERENCES colony_ants(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- 10. ATTACKS (PvP)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS attacks (
    id                      INT UNSIGNED NOT NULL AUTO_INCREMENT,
    attacker_colony_id      INT UNSIGNED NOT NULL,
    defender_colony_id      INT UNSIGNED NOT NULL,
    attack_type             ENUM('tdc','colony') NOT NULL,
    timer                   INT UNSIGNED NOT NULL,
    status                  ENUM('active','resolved_attacker_win','resolved_defender_win') NOT NULL DEFAULT 'active',
    created_at              DATETIME NOT NULL DEFAULT UTC_TIMESTAMP(),
    PRIMARY KEY (id),
    CONSTRAINT fk_attacks_attacker FOREIGN KEY (attacker_colony_id) REFERENCES colonies(id) ON DELETE CASCADE,
    CONSTRAINT fk_attacks_defender FOREIGN KEY (defender_colony_id) REFERENCES colonies(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS attack_armies (
    attack_id       INT UNSIGNED NOT NULL,
    colony_ant_id   INT UNSIGNED NOT NULL,
    count           INT UNSIGNED NOT NULL,
    PRIMARY KEY (attack_id, colony_ant_id),
    CONSTRAINT fk_aa_attack FOREIGN KEY (attack_id) REFERENCES attacks(id) ON DELETE CASCADE,
    CONSTRAINT fk_aa_ant FOREIGN KEY (colony_ant_id) REFERENCES colony_ants(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- 11. COMBAT LOGS
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS combat_logs (
    id                      INT UNSIGNED NOT NULL AUTO_INCREMENT,
    attacker_colony_id      INT UNSIGNED NOT NULL,
    defender_colony_id      INT UNSIGNED NOT NULL,
    combat_type             ENUM('tdc_attack','colony_attack','hunt') NOT NULL,
    winner_colony_id        INT UNSIGNED NULL,
    tdc_gained              INT UNSIGNED NOT NULL DEFAULT 0,
    tdc_lost                INT UNSIGNED NOT NULL DEFAULT 0,
    food_pillaged           BIGINT UNSIGNED NOT NULL DEFAULT 0,
    materials_pillaged      BIGINT UNSIGNED NOT NULL DEFAULT 0,
    attacker_losses         JSON NULL,
    defender_losses         JSON NULL,
    resolved_at             DATETIME NOT NULL DEFAULT UTC_TIMESTAMP(),
    PRIMARY KEY (id),
    CONSTRAINT fk_cl_attacker FOREIGN KEY (attacker_colony_id) REFERENCES colonies(id) ON DELETE CASCADE,
    CONSTRAINT fk_cl_defender FOREIGN KEY (defender_colony_id) REFERENCES colonies(id) ON DELETE CASCADE,
    CONSTRAINT fk_cl_winner   FOREIGN KEY (winner_colony_id)   REFERENCES colonies(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- 12. COLONIZATIONS
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS colonizations (
    colonizer_colony_id INT UNSIGNED NOT NULL,
    colonized_colony_id INT UNSIGNED NOT NULL,
    tax_rate            DECIMAL(4,4) NOT NULL,
    started_at          DATETIME NOT NULL DEFAULT UTC_TIMESTAMP(),
    PRIMARY KEY (colonizer_colony_id, colonized_colony_id),
    CONSTRAINT fk_colonizer FOREIGN KEY (colonizer_colony_id) REFERENCES colonies(id) ON DELETE CASCADE,
    CONSTRAINT fk_colonized FOREIGN KEY (colonized_colony_id) REFERENCES colonies(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- 13. EVENT LOG
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS colony_events (
    id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    colony_id   INT UNSIGNED    NOT NULL,
    event_type  VARCHAR(32)     NOT NULL,
    payload     JSON            NULL,
    created_at  DATETIME        NOT NULL DEFAULT UTC_TIMESTAMP(),
    PRIMARY KEY (id),
    INDEX idx_events_colony_time (colony_id, created_at),
    CONSTRAINT fk_ev_colony FOREIGN KEY (colony_id) REFERENCES colonies(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

SET FOREIGN_KEY_CHECKS = 1;