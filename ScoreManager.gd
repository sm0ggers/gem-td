extends Node

signal wave_modifier_changed(new_modifier: int)

var dynamic_score: float = 50.0
var extra_enemies_modifier: int = 0

## Adds score on enemy kills
func register_kill() -> void:
	dynamic_score += 0.75
	print("Enemy killed! Current Score: ", dynamic_score)
	
	if dynamic_score >= 100.0:
		var leftover = dynamic_score - 100.0
		dynamic_score = 50.0 + leftover # Carry over the fraction weight
		extra_enemies_modifier += 1
		
		wave_modifier_changed.emit(extra_enemies_modifier)
		print("🚀 Difficulty Up! Extra enemies: ", extra_enemies_modifier, " (Score reset to: ", dynamic_score, ")")

## Deducts score when enemies hit checkpoints or the exit
func register_leak(penalty_value: float) -> void:
	# penalty_value will be passed as a positive number (e.g., 0.2 or 5.0)
	dynamic_score -= penalty_value
	print("Leak detected! Current Score: ", dynamic_score)
	
	if dynamic_score <= 0.0:
		var leftover = abs(dynamic_score) # Get the negative overshoot amount
		dynamic_score = 50.0 - leftover # Carry over the deficit weight
		
		# Drop enemy count, but don't let total waves go below their absolute baseline layout
		extra_enemies_modifier = max(-5, extra_enemies_modifier - 1) 
		
		wave_modifier_changed.emit(extra_enemies_modifier)
		print("⚠️ Difficulty Down! Extra enemies: ", extra_enemies_modifier, " (Score reset to: ", dynamic_score, ")")
