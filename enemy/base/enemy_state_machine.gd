# enemy_state_machine.gd
# DEPRECATED — This file has been split into individual state files:
#   enemy_state_idle.gd        → EnemyStateIdle (with patrol logic)
#   enemy_state_investigate.gd → EnemyStateInvestigate
#   enemy_state_chase.gd       → EnemyStateChase
#   enemy_state_attack.gd      → EnemyStateAttack (dispatches do_attack())
#   enemy_state_search.gd      → EnemyStateSearch
#   enemy_state_stunned.gd     → EnemyStateStunned
#
# Each state class requires its own file because Godot 4 only allows
# one class_name per .gd file. This file is kept as a reference only.
