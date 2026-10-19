extends Node

# Spawner di test: crea il player SOLO quando city.tscn viene avviata da sola (F6).
# Quando la città è istanziata dentro main.tscn non fa nulla,
# perché lì il player arriva dalla casa tramite il teleport.

const PLAYER_SCENE := preload("res://addons/gremlins_first_person/gremlins_fpc.tscn")

func _ready() -> void:
	# Controllo rinviato di un frame: current_scene è sicuramente già assegnata
	call_deferred("_spawn_player")

func _spawn_player() -> void:
	if get_tree().current_scene != get_parent():
		return
	var city := get_parent()
	var player := PLAYER_SCENE.instantiate()
	player.name = "FirstPersonCharacter"
	city.add_child(player)

	var spawn := city.get_node_or_null("CitySpawn")
	if spawn != null:
		player.global_position = spawn.global_position
		player.scale = spawn.scale          # stessa scala usata dal teleport (0.15)
	player.rotation.y = 0.0                 # guarda verso il tribunale (-Z)
	print("[CityStandalone] Player di test creato in ", player.global_position)
