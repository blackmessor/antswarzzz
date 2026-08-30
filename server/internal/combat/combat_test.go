package combat

// Unit test for combat engine — run with: go test ./internal/combat

import (
	"testing"
)

func TestResolveCombat(t *testing.T) {
	attackers := []CombatUnit{
		{AntTypeID: 1, Count: 1, BaseHP: 8, BaseAtk: 3, BaseDef: 2, CurrentHP: 8, DeathOrder: 2},
		{AntTypeID: 1, Count: 1, BaseHP: 8, BaseAtk: 3, BaseDef: 2, CurrentHP: 8, DeathOrder: 2},
		{AntTypeID: 1, Count: 1, BaseHP: 8, BaseAtk: 3, BaseDef: 2, CurrentHP: 8, DeathOrder: 2},
	}
	defenders := []CombatUnit{
		{AntTypeID: 0, Count: 1, BaseHP: 5, BaseAtk: 3, BaseDef: 1, CurrentHP: 5, DeathOrder: 0},
		{AntTypeID: 0, Count: 1, BaseHP: 5, BaseAtk: 3, BaseDef: 1, CurrentHP: 5, DeathOrder: 0},
	}
	result := resolve(attackers, defenders)
	if !result.AttackerWins {
		t.Errorf("expected attackers to win, got loss")
	}
	if result.RoundsFought > 10 {
		t.Errorf("expected < 10 rounds, got %d", result.RoundsFought)
	}
}

func TestResolveHunt(t *testing.T) {
	units := []CombatUnit{}
	for i := 0; i < 15; i++ {
		units = append(units, CombatUnit{
			AntTypeID: 1, Count: 1, BaseHP: 8, BaseAtk: 3, BaseDef: 2,
			CurrentHP: 8, DeathOrder: 2,
		})
	}
	result := ResolveHunt(50, units, CombatBonuses{})
	if !result.Won {
		t.Errorf("expected hunt win with 15 JSN vs 25 predators")
	}
	if result.TDCLostToWinner != 10 {
		t.Errorf("expected TDC 10 gained, got %d", result.TDCLostToWinner)
	}
}

func TestCanAttack(t *testing.T) {
	if !CanAttack(100, 200) {
		t.Error("100→200 should be valid (2x)")
	}
	if !CanAttack(100, 50) {
		t.Error("100→50 should be valid (0.5x)")
	}
	if CanAttack(100, 400) {
		t.Error("100→400 should be invalid (4x)")
	}
	if CanAttack(100, 10) {
		t.Error("100→10 should be invalid (0.1x)")
	}
}

func TestColonizationTax(t *testing.T) {
	tax := ColonizationTax(0)
	if tax != 0.20 {
		t.Errorf("base tax should be 0.20, got %f", tax)
	}
	tax = ColonizationTax(5)
	if tax < 0.24 || tax > 0.26 {
		t.Errorf("tax with level 5 should be ~0.25, got %f", tax)
	}
}