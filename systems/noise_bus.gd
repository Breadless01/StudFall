# noise_bus.gd
# Autoload as "NoiseBus" in Project Settings → Autoload
# All noise events go through here. Enemies subscribe via signal.
extends Node

signal noise_emitted(pos: Vector3, loudness: float, tag: String, source_node: Node)

# Rate limiting per tag per source
var _last_emit_time: Dictionary = {}
const FOOTSTEP_INTERVAL := 0.35  # seconds between footstep noise events

func emit_noise(
	pos: Vector3,
	loudness: float,
	tag: String,
	source_node: Node = null
) -> void:
	# Rate-limit footsteps
	if tag == "footstep_sprint" or tag == "footstep_walk":
		var key := str(source_node) + tag
		var now := Time.get_ticks_msec() / 1000.0
		if _last_emit_time.has(key) and (now - _last_emit_time[key]) < FOOTSTEP_INTERVAL:
			return
		_last_emit_time[key] = now

	noise_emitted.emit(pos, loudness, tag, source_node)


# Loudness reference values (0..1)
# shoot_pistol:    0.9
# shoot_rifle:     1.0
# footstep_sprint: 0.4
# footstep_walk:   0.15
# door_open:       0.5
# throw:           0.4
# interact:        0.2
