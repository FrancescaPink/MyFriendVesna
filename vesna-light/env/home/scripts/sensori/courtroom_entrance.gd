extends Area3D

# Trigger sul portico del tribunale in città: avvicinandosi alla porta, chiede
# conferma prima di entrare (il vero teletrasporto avviene solo al click sul
# bottone, gestito in menu_dialog.gd insieme a "uscita_casa"). Stesso identico
# schema di zona_uscita.gd: è un ingresso a SENSO UNICO, non si torna indietro.

var puo_attivarsi : bool = true

func _on_body_entered(body: Node3D) -> void:
	if body.name == "FirstPersonCharacter" and puo_attivarsi:
		puo_attivarsi = false
		var menu = get_tree().root.find_child("DialogInterface", true, false)
		if menu != null:
			if not "entra_tribunale" in menu.topic_pendenti:
				menu.topic_pendenti.append("entra_tribunale")
			# La domanda vera viene mostrata da _on_menu_aperto() in menu_dialog.gd,
			# che riconosce "entra_tribunale" tra i topic pendenti.
			menu.visible = true
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			get_tree().paused = true

func _on_body_exited(body: Node3D) -> void:
	if body.name == "FirstPersonCharacter":
		puo_attivarsi = true
