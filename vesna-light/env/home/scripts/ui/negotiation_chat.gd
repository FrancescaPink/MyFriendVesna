extends CanvasLayer

# ============================================================
#  Log scorrevole della trattativa (Atto 3, fase 2).
#
#  Richiesta del professore in sede di controllo: durante la negoziazione
#  automatica fra accusa e difesa il giocatore vedeva solo l'ULTIMA battuta,
#  sovrascritta ogni volta (vedi giudice.asl, !narra) - impossibile rileggere
#  un argomento se ci si distrae un attimo. Da qui in poi ogni battuta resta
#  visibile, in un elenco che si può scorrere.
#
#  Si attiva quando menu_dialog.gd riceve il tag [TRATTATIVA] (messo da
#  gnp_host.asl in testa alla prima battuta della fase 2) e resta attivo fino
#  al tag [FINE:tono], che lo passa a EndScreen. Autoload come PauseMenu:
#  sempre presente, normalmente nascosto.
# ============================================================

const GOLD  := Color(0.85, 0.7, 0.36)
const CREAM := Color(0.96, 0.94, 0.9)
const COL_ACCUSA := Color(0.86, 0.5, 0.46)
const COL_DIFESA := Color(0.55, 0.72, 0.88)

var _panel: Control
var _lista: VBoxContainer
var _scroll: ScrollContainer
var _btn_torna: Button

# Restano validi anche dopo che la trattativa e' finita, cosi' "Rivedi la
# trattativa" dalla schermata finale puo' riaprire lo stesso log e tornare
# indietro senza doverlo ricostruire.
var _conclusa := false
var _tono_finale := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 96
	_build_ui()

func _build_ui() -> void:
	_panel = Control.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	_panel.visible = false
	add_child(_panel)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(dim)

	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(640, 480)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.08, 0.07, 0.97)
	style.set_corner_radius_all(14)
	style.set_border_width_all(2)
	style.border_color = GOLD
	style.set_content_margin_all(22)
	box.add_theme_stylebox_override("panel", style)
	# Il riquadro sta dentro un CenterContainer a tutto schermo, che lo tiene
	# centrato qualunque sia la sua altezza. Prima la posizione veniva calcolata
	# una volta sola all'avvio, a riquadro ancora vuoto: quando poi il testo lo
	# allungava (il sottotitolo di "caso perso" va su piu' righe) cresceva solo
	# verso il basso e usciva dallo schermo.
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	centro.process_mode = Node.PROCESS_MODE_ALWAYS
	_panel.add_child(centro)
	centro.add_child(box)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	box.add_child(vb)

	var title := Label.new()
	title.text = "La trattativa in aula"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)

	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(600, 380)
	vb.add_child(_scroll)

	_lista = VBoxContainer.new()
	_lista.add_theme_constant_override("separation", 10)
	_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_lista)

	_btn_torna = Button.new()
	_btn_torna.text = "Torna al verdetto"
	_btn_torna.visible = false
	_btn_torna.custom_minimum_size = Vector2(0, 42)
	_btn_torna.add_theme_font_size_override("font_size", 18)
	_btn_torna.pressed.connect(_on_torna_pressed)
	vb.add_child(_btn_torna)


# Chiamato da menu_dialog.gd quando arriva [TRATTATIVA]: nuova trattativa,
# log ripulito da eventuali residui di una sessione precedente.
func avvia() -> void:
	for figlio in _lista.get_children():
		figlio.queue_free()
	_conclusa = false
	_btn_torna.visible = false
	_panel.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true

# Aggiunge una riga e scorre in fondo. Il colore distingue chi parla:
# le frasi di accusa e difesa in dnm_patteggiamento.asl iniziano sempre
# rispettivamente con "L'accusa" e "La difesa" (controllato sul file), quindi
# basta il prefisso senza bisogno di un tag a parte.
#
# Se il giocatore ha chiuso il pannello a trattativa ancora in corso, questa
# battuta lo riapre da sola: stesso problema gia' risolto per il riquadro a
# riga singola (vedi menu_dialog.gd), stessa soluzione. Non riapre invece
# dopo la conclusione (_conclusa), per non contendere la scena a EndScreen
# nell'istante di passaggio fra i due pannelli.
func aggiungi(testo: String) -> void:
	if not _conclusa and not _panel.visible:
		_panel.visible = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_tree().paused = true
	var riga := Label.new()
	riga.text = testo
	riga.autowrap_mode = TextServer.AUTOWRAP_WORD
	riga.custom_minimum_size.x = 580
	riga.add_theme_color_override("font_color", _colore_per(testo))
	_lista.add_child(riga)
	await get_tree().process_frame
	_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)

func _colore_per(testo: String) -> Color:
	if testo.begins_with("L'accusa"):
		return COL_ACCUSA
	if testo.begins_with("La difesa"):
		return COL_DIFESA
	return CREAM

# Chiamato da menu_dialog.gd quando arriva [FINE:tono]: lascia un attimo per
# leggere l'ultima battuta, poi passa la linea a EndScreen.
func concludi(tono: String) -> void:
	_conclusa = true
	_tono_finale = tono
	_btn_torna.visible = true
	await get_tree().create_timer(1.6, true).timeout
	_panel.visible = false
	EndScreen.mostra(tono)

# Riapertura da EndScreen ("Rivedi la trattativa"): il log e' ancora quello
# della partita appena conclusa, non va ricostruito.
func riapri() -> void:
	_panel.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true

func _on_torna_pressed() -> void:
	_panel.visible = false
	EndScreen.mostra(_tono_finale)
