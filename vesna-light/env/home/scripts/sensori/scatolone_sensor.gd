extends Area3D

# Interazione "aiuta Bob a disfare gli scatoloni del trasloco" (Atto 1,
# meccanica di fiducia). Stesso schema di radio_sensor.gd: area di
# prossimità + prompt a schermo + tasto di interazione.

var giocatore_vicino = false
var sistemato = false

func _on_body_entered(body: Node3D) -> void:
	if body.name == "FirstPersonCharacter" and not sistemato:
		$UIScatolone.visible = true
		giocatore_vicino = true

func _on_body_exited(body: Node3D) -> void:
	if body.name == "FirstPersonCharacter":
		$UIScatolone.visible = false
		giocatore_vicino = false

func _input(event: InputEvent) -> void:
	if giocatore_vicino and not sistemato and event.is_action_pressed("turn_on"):
		sistema_scatolone()

func sistema_scatolone() -> void:
	sistemato = true
	$UIScatolone.visible = false
	invia_segnale_a_bob()

func invia_segnale_a_bob() -> void:
	var agents = get_tree().get_nodes_in_group("agents")
	if agents.size() > 0:
		var bob = agents[0]
		var log_data: Dictionary = {
			"sender": "body",
			"receiver": "vesna",
			"type": "signal",
			"data": {
				"type": "scatolone_sistemato",
				"status": "scatoloni",
				"reason": "ripostiglio",
			}
		}
		bob.ws.send_text(JSON.stringify(log_data))
