extends StaticBody3D

const DISTANZA_SICUREZZA = 4.0
var giocatore_vicino = false
var pc_violato = false

func _ready():
	$PCSensor/UI_PC/Label.visible = false

# Questa funzione scatta da sola quando entri nel cubo grande dell'Area3D
func _on_area_3d_body_entered(body):
	if body.name == "FirstPersonCharacter": 
		giocatore_vicino = true
		print("Giocatore vicino al PC: premere R per interagire")
		# Se hai un'interfaccia a schermo, puoi accenderla qui
		$PCSensor/UI_PC/Label.visible = true
		
# Questa funzione scatta quando ti allontani
func _on_area_3d_body_exited(body):
	if body.name == "FirstPersonCharacter":
		giocatore_vicino = false
		$PCSensor/UI_PC/Label.visible = false

# Questo ascolta costantemente la tastiera
func _process(delta):
	# Se sei vicino e premi il tasto "R" (o l'azione che hai mappato)
	if giocatore_vicino and Input.is_action_just_pressed("turn_on"):
		interact()

func interact():
	print("--- TENTATIVO DI HACKING ---")

	if pc_violato:
		$PCSensor/UI_PC/Label.text = "Hai già trovato quello che ti serviva qui."
		return

	var bob = get_tree().get_root().find_child("Bob", true, false)

	if bob:
		var distanza = global_position.distance_to(bob.global_position)
		distanza = snapped(distanza, 0.1)
		print("Distanza di Bob: ", distanza, " metri.")

		if distanza < DISTANZA_SICUREZZA:
			print("ACCESSO NEGATO: Bob ti sta guardando!")
			$PCSensor/UI_PC/Label.text = "Bob ti sta guardando!"
			# Bob se ne accorge: la fiducia scende (vedi bob.asl -> +tentativo_hacking)
			var log_data : Dictionary = {
				"sender": "body",
				"receiver": "vesna",
				"type": "signal",
				"data": {
					"type": "tentativo_hacking",
					"status": "scoperto",
					"reason": "pc",
				}
			}
			bob.ws.send_text(JSON.stringify(log_data))

			# Bob ti rimprovera SUBITO, non solo se poi vai tu a parlargli:
			# il dialogo si apre di scatto con un solo modo per rispondere.
			var menu = get_tree().root.find_child("DialogInterface", true, false)
			if menu != null:
				# Prima l'interlocutore, poi il topic: imposta_interlocutore()
				# svuota topic_pendenti se l'interlocutore cambia, quindi
				# nell'ordine inverso cancellerebbe il rimprovero appena messo.
				menu.imposta_interlocutore("Bob")
				if not "rimprovero_pc" in menu.topic_pendenti:
					menu.topic_pendenti.append("rimprovero_pc")
				menu.visible = true
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				get_tree().paused = true
		else:
			print("ACCESSO CONSENTITO: Bob è distratto. Hacking in corso...")
			pc_violato = true
			# Percorso "low morality": l'indizio su Finn si scopre rubandolo
			# invece di guadagnarselo con la fiducia (vedi bob.asl -> confessione).
			# Bob non si accorge di nulla: nessun effetto sulla fiducia.
			$PCSensor/UI_PC/Label.text = "Hacking riuscito. Trovi una mail nella posta di Bob:\n\"Finn, mi servono ancora le chiavi di scorta di casa mia che ti avevo dato per le piante. Portamele appena puoi.\""
			# Disattiva temporaneamente l'interazione per non farla scattare mille volte
			giocatore_vicino = false
			# Sblocca la stessa prova della confessione nell'inventario (nodo
			# separato, nessun collegamento con dialogo/fiducia)
			var inventario = get_tree().root.find_child("Inventario", true, false)
			if inventario != null:
				inventario.sblocca("confessione")
			# Credenza silenziosa per Jason: Bob non lo sa e non ne parlerà mai,
			# ma resta utile per gli atti successivi (percorso "low morality").
			var log_data : Dictionary = {
				"sender": "body",
				"receiver": "vesna",
				"type": "signal",
				"data": {
					"type": "furto_riuscito",
					"status": "pc",
					"reason": "indisturbato",
				}
			}
			bob.ws.send_text(JSON.stringify(log_data))
	else:
		print("ERRORE: Non trovo Bob!")
