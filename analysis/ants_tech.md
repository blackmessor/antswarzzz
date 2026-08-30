# Fourmizzz — Analysis: Ant Types & Technology Tree

> Research compiled from official game tutorials, community guides, forum posts, the Fourmizzz Calculator spreadsheet (v1.2), and user scripts.
> Game: [fourmizzz.fr](http://www.fourmizzz.fr) — a French browser-based ant colony strategy MMO (since 2006).

---

## 1. Ant Types (Unités / Castes)

The game features 15 ant types including the basic worker (ouvrière). Units are bred by the Queen on the `Reine.php` page. They gain combat experience and can **evolve** within their class (e.g. Soldate → Soldate d'Élite).

### 1.1 Complete Unit Roster

| # | Unit | Abbr. | HP | Atk | Def | Prod. Time | Food | Unlock Requirement |
|---|------|-------|----|-----|-----|------------|------|---------------------|
| 0 | **Ouvrière** | Ouv. | 0 | 0 | 0 | 60s (1 min) | 5 | Default — harvests resources |
| 1 | **Jeune Soldate Naine** | JSN | 8 | 3 | 2 | 300s (5 min) | 10 | Salle de Combat lvl 1 |
| 2 | **Soldate Naine** | SN | 10 | 5 | 4 | 450s (7.5 min) | — | Salle de Combat lvl 3 |
| 3 | **Naine d'Élite** | NE | 13 | 7 | 6 | 570s (9.5 min) | — | **Evolution only** — from Soldate Naine via combat XP |
| 4 | **Jeune Soldate** | JS | 16 | 10 | 9 | 740s (12.3 min) | 16 (est.) | Salle de Combat higher level |
| 5 | **Soldate** | S | 20 | 15 | 14 | 1000s (16.7 min) | — | Caserne or Salle de Combat |
| 6 | **Soldate d'Élite** | SE | 27 | 24 | 23 | 1450s (24.2 min) | — | **Evolution only** — from Soldate via combat XP |
| 7 | **Concierge** | C | 30 | 1 | 25 | 1410s (23.5 min) | 30 | Research/building unlock |
| 8 | **Concierge d'Élite** | CE | 40 | 1 | 35 | — | — | **Evolution only** — from Concierge via combat XP |
| 9 | **Artilleuse** | A | 10 | 30 | 15 | 1440s (24 min) | — | **Acide** research (Labo 7-9, Armes 5-7, Génétique 3-5) |
| 10 | **Artilleuse d'Élite** | AE | 12 | 35 | 18 | 1520s (25.3 min) | 33-37 | Direct breed (or evolution, sources vary) |
| 11 | **Tank** | Tk | 35 | 55 | 1 | 1860s (31 min) | — | **Génétique** lvl 13-15 + Caserne lvl 22-23 |
| 12 | **Tank d'Élite** | TkE | 50 | 80 | 1 | — | — | **Evolution only** — from Tank via combat XP |
| 13 | **Tueuse** | Tu | 50 | 50 | 50 | 2740s (45.7 min) | — | **Poison** research (late-game) |
| 14 | **Tueuse d'Élite** | TuE | 55 | 55 | 55 | 2740s (45.7 min) | — | **Evolution only** — from Tueuse via combat XP |

**Notes:**
- Stats are base values before any bonus (Armes, Bouclier, Dôme, Loge).
- Production times come from the Fourmizzz Calculator spreadsheet (v1.2, 2015); values may have changed in later patches.
- "Evolution only" units (NE, SE, CE, TkE, TuE) cannot be bred directly from the Queen; they are earned when their base form gains enough combat XP.
- The Concierge has legendary defense (25 base) but nearly zero attack (1).
- The Tank has the highest attack per unit (55 base) but nearly zero defense (1).
- The Tueuse/Tueuse d'Élite are the most balanced and powerful units overall (50/50/50 and 55/55/55), with the longest breed time.

### 1.2 Combat Death Order

When units die in combat, the weakest die first. The order matches the Queen's breeding list:
JS Naine → Soldate Naine → Naine d'Élite → Jeune Soldate → Soldate → Concierge → Concierge d'Élite → Artilleuse → Artilleuse d'Élite → Soldate d'Élite → Tank → Tank d'Élite → Tueuse → Tueuse d'Élite

This makes JSN the preferred "tampon" (meat shield) unit — cheap, fast to produce, absorbs losses first.

### 1.3 Evolution System

Units gain XP from any combat (hunts or PvP attacks). When enough XP accumulates, they evolve to the next tier within their class:

```
Soldate Naine  ──XP──▶  Naine d'Élite
Soldate        ──XP──▶  Soldate d'Élite
Concierge      ──XP──▶  Concierge d'Élite
Tank           ──XP──▶  Tank d'Élite
Tueuse        ──XP──▶  Tueuse d'Élite
```

The **Étable à Cochenilles** building increases the number of units that progress per combat (+10% per level).

---

## 2. Technology Tree (Recherches)

Research is conducted in the **Laboratoire** (Laboratory). The **Salle d'Analyse** reduces research time (-10% per level).

### 2.1 Core Technologies

| Technology | Effect Per Level | Notes |
|------------|------------------|-------|
| **Technique de Ponte** | -10% breeding time | #1 priority — directly reduces unit production time |
| **Bouclier Thoracique** | +10% unit HP | Increases survivability |
| **Armes** | +10% unit damage | Bonus formula: base_damage × (1 + weapon_level/10) |
| **Architecture** | Unlocks buildings, -10% building time | Required for Loge Impériale, advanced buildings |
| **Vitesse de Chasse** | -10% hunt time, +1 simultaneous hunt per level | Critical for TDC (hunting territory) expansion |
| **Vitesse d'Attaque** | -10% PvP attack time, -10% convoy time | For attacking other players and sending convoys |

### 2.2 Unit-Unlocking Technologies

These technologies gate access to specific unit types:

| Technology | Unlocks | Prerequisites (Level 1) |
|------------|---------|------------------------|
| **Communication avec les animaux** | Étable à pucerons, other buildings/units | Architecture prerequisite |
| **Génétique** | Tank unit | Higher Labo/Armes levels |
| **Acide** | Artilleuse unit | Labo lvl 7-9, Armes lvl 5-7, Génétique lvl 3-5 |
| **Poison** | Tueuse unit | Late-game — requires high Génétique/Acide |

### 2.3 Technology Dependency Graph

```
Laboratoire (building)
├── Technique de Ponte ─── (no prereq, priority #1)
├── Bouclier Thoracique ── (no prereq)
├── Armes ───────────────── (no prereq)
├── Architecture ────────── (no prereq)
│   └── Loge Impériale, advanced buildings
├── Vitesse de Chasse ───── (no prereq)
├── Vitesse d'Attaque ───── (no prereq)
├── Communication animaux ─ (Architecture)
├── Génétique ───────────── (Labo + Armes levels)
│   └── Tank ────────────── (Génétique 13-15 + Caserne 22-23)
├── Acide ───────────────── (Labo 7-9 + Armes 5-7 + Génétique 3-5)
│   └── Artilleuse
└── Poison ──────────────── (high Génétique + Acide)
    └── Tueuse
```

---

## 3. Key Buildings & Their Roles

| Building | Role |
|----------|------|
| **Salle de Combat** | Unlocks combat units (JSN at lvl 1, SN at lvl 3, JS at higher levels) |
| **Caserne** | Unlocks advanced units (Soldate, Tank requires lvl 22-23) |
| **Laboratoire** | Enables all research |
| **Salle d'Analyse** | -10% research time per level |
| **Couveuse** | -10% breeding time per level |
| **Solarium** | -10% breeding time per level |
| **Champignonnière** | Passive daily food production |
| **Entrepôt (x2)** | Food and material storage caps |
| **Étable à Pucerons** | +1% pillage capacity, +5% trade capacity per level |
| **Étable à Cochenilles** | +10% unit evolution rate per combat per level |
| **Dôme** | Defense HP bonus: 10% + 5%/level |
| **Loge Impériale** | Defense HP bonus: 30% + 15%/level (army stored here is safer than in Fourmilière) |

### Bonuses Stacking
- Dôme and Loge bonuses are **cumulative** for total HP in defense.
- Armes bonus applies identically to both attack and defense damage calculations.
- Bouclier bonus multiplies base unit HP.

---

## 4. Early-Game Priority Path

Based on community guides (2011-2015 era):

1. **Technique de Ponte** — always max first
2. **Couveuse + Solarium** — alternate with Technique de Ponte
3. **Vitesse de Chasse** — max early for TDC expansion
4. **Architecture** — max after breeding time is low
5. **Armes** — develop gradually for better hunt efficiency
6. **Bouclier Thoracique** — develop alongside Armes
7. **Génétique → Acide → Poison** — late-game unit unlocks

**Avoid early:** Étable à pucerons, Étable à cochenilles, Dôme, Caserne — they don't accelerate early growth.

---

## 5. Sources

- Official tutorial: `fourmizzz.fr/tutorial.php`
- Community guides: `fourmizzz.cforum.info` (Tutoriel débutants by deca, Guide confirmés by coaster)
- Fourmizzz Calculator v1.2 spreadsheet (fichier-xls.com, 2015)
- Script FYT/FYW user script (GitHub gist by lwr20/Fourmitte)
- Quizity quizzes on Fourmizzz units & research (ChasseurDeDoudous, 2013)
- JeuxOnLine game profile

---

*Analysis compiled August 2026. The game has been live since 2006; some mechanics may have evolved. Stats are from the 2015 calculator — verify against current server if actively playing.*