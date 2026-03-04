# enemy_state_attack.gd
# Enemy FSM state: Attack — dispatches do_attack() (melee or ranged depending on attack_mode).
class_name EnemyStateAttack
extends "res://player/state_machine.gd".State

func enter(_msg: Dictionary) -> void:
	var enemy = state_machine.owner_node as Enemy
	# Melee: stop and swing. Ranged: can stay mobile (handled in do_ranged_attack)
	if enemy.attack_mode == Enemy.AttackMode.MELEE:
		enemy.stop_movement()
	enemy.do_attack()

func update(_delta: float) -> void:
	var enemy = state_machine.owner_node as Enemy
	var perc  = enemy.perception as PerceptionSystem
	if enemy.can_attack():
		if not enemy.is_in_attack_range(perc._player) or not perc.target_visible:
			state_machine.transition_to("Chase")
		else:
			enemy.do_attack()
