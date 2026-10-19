extends Area3D

var puo_attivarsi : bool = true

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_body_entered(body: Node3D) -> void:
	# Controlliamo il nome del nodo che ha toccato la porta.
	if body.name == "FirstPersonCharacter" and puo_attivarsi: 
		puo_attivarsi = false
		# Troviamo l'interfaccia UI e le mandiamo il testo con il Tag
		var menu = get_tree().root.find_child("DialogInterface", true, false)
		if menu != null:
			if not "uscita_casa" in menu.topic_pendenti:
				menu.topic_pendenti.append("uscita_casa")
			# La domanda vera ("Sei sicuro...?") viene mostrata da _on_menu_aperto()
			# in menu_dialog.gd, che riconosce "uscita_casa" tra i topic pendenti.
			# 2. NOVITÀ: Rende il menu visibile forzatamente!
			menu.visible = true
			# 3. NOVITÀ: Libera il cursore del mouse così puoi cliccare il bottone
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			# LA SOLUZIONE: Mettiamo in pausa il mondo, NON facciamo sparire il giocatore!
			get_tree().paused = true
			
func _on_body_exited(body: Node3D) -> void:
	if body.name == "FirstPersonCharacter":
		puo_attivarsi = true # Riattiva la porta quando ti allontani
