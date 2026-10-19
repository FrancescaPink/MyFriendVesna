extends Area3D

var accesa = false
var giocatore_vicino = false

# Scatta quando il giocatore entra nell'area
func _on_body_entered(body: Node3D) -> void:
	if body.name == "FirstPersonCharacter":
		$UIRadio.visible = true
		giocatore_vicino = true
		print("Giocatore vicino alla radio: premere R per interagire")

# Scatta quando il giocatore esce dall'area
func _on_body_exited(body: Node3D) -> void:
	if body.name == "FirstPersonCharacter":
		$UIRadio.visible = false
		giocatore_vicino = false
		
# Genero l'evento se il player preme il tasto dedicato
func _input(event):
	# "ui_accept" è il tasto predefinito per Spazio/Invio in Godot
	if giocatore_vicino and event.is_action_pressed("turn_on"):
		toggle_radio()

func toggle_radio():
	# Accedo al nodo AudioStreamPlayer3D -> uso il simbolo '$' seguito dal nome esatto del nodo
	var audio = get_parent().get_node("AudioStreamPlayer3D") 
	# Controlli per simulare la percezione uditiva
	if not accesa:
		accesa = true
		audio.play()
		print("Radio ACCESA")
		invia_segnale_a_bob()
	else:
		accesa = false
		audio.stop()
		print("Radio SPENTA")

func invia_segnale_a_bob():
	# Cerco il nodo che gestisce la comunicazione (Bob/Vesna)
	var agents = get_tree().get_nodes_in_group("agents")
	if agents.size() > 0:
		var bob = agents[0]
		# Preparo il pacchetto JSON
		var log_data : Dictionary = {
			"sender": "body",
			"receiver": "vesna",
			"type": "signal",
			"data": {
				"type": "rumore_rilevato",
				"status": "radio",           	 	# Cosa sente Bob
				"reason": "radio",   	 		# Dove lo sente
			}
		}
		# Invio il messaggio tramite il WebSocket di Bob
		bob.ws.send_text(JSON.stringify(log_data))
		print("Segnale inviato alla mente di Bob!")

# Funzione che permette a Bob di spegnere la radio
func disattiva_radio():
	var audio = get_parent().get_node("AudioStreamPlayer3D")
	if accesa:
		accesa = false
		audio.stop()
		print("La radio è stata SPENTA da Bob!")
