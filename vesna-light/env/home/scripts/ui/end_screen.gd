extends CanvasLayer

# ============================================================
#  Schermata di fine partita (Atto 3). Richiesta del professore in sede di
#  controllo: prima non c'era alcun segnale esplicito che il gioco fosse
#  finito, solo il tono di una battuta del giudice ("la seduta e' tolta") -
#  bisognava dedurre da soli se era andata bene o male.
#
#  Il tono (vittoria / parziale / sconfitta) arriva da giudice.asl con un tag
#  [FINE:tono], scelto in base alla FASCIA dell'esito numerico (vedi il
#  commento su +esito_finale in giudice.asl): e' un giudizio narrativo di
#  quell'agente, non del protocollo di negoziazione, quindi resta fuori da
#  gnp_host.asl.
#
#  Da qui le uniche vie d'uscita sono tornare al menu principale o chiudere
#  il gioco: e' il punto in cui l'utente aveva chiesto di poter uscire "solo
#  dopo aver ricevuto il verdetto" - prima quel momento non esisteva davvero,
#  "Esci dall'aula" chiudeva solo il riquadro di dialogo e si tornava a
#  camminare in tribunale.
#
#  Autoload, come PauseMenu e NegotiationChat.
# ============================================================

const MAIN_MENU_SCENE := "res://menu/main_menu.tscn"
const GOLD  := Color(0.85, 0.7, 0.36)
const CREAM := Color(0.96, 0.94, 0.9)

# titolo, colore, sottotitolo
const TESTI := {
	"vittoria":  ["CASO VINTO", Color(0.55, 0.78, 0.5),
		"La difesa ha convinto il tribunale: Bob Parker e' assolto."],
	"parziale":  ["VITTORIA PARZIALE", Color(0.85, 0.7, 0.36),
		"Non e' l'assoluzione, ma il lavoro fatto ha pesato sulla sentenza."],
	"sconfitta": ["CASO PERSO", Color(0.82, 0.42, 0.38),
		"Il tribunale non ha trovato elementi sufficienti a favore di Bob Parker."],
}

var _panel: Control
var _titolo: Label
var _sottotitolo: Label
var _sfx_hover: AudioStreamPlayer
var _sfx_click: AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 97
	_build_ui()
	_build_audio()

func _build_audio() -> void:
	# Stessi suoni del menu di pausa, per coerenza.
	_sfx_hover = AudioStreamPlayer.new()
	_sfx_hover.stream = load("res://assets/menu/hover.wav")
	_sfx_hover.volume_db = -14.0
	_sfx_hover.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_sfx_hover)

	_sfx_click = AudioStreamPlayer.new()
	_sfx_click.stream = load("res://assets/menu/click.wav")
	_sfx_click.volume_db = -6.0
	_sfx_click.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_sfx_click)

func _build_ui() -> void:
	_panel = Control.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	_panel.visible = false
	add_child(_panel)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(dim)

	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(460, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.06, 0.05, 0.98)
	style.set_corner_radius_all(14)
	style.set_border_width_all(2)
	style.border_color = GOLD
	style.set_content_margin_all(32)
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
	vb.add_theme_constant_override("separation", 16)
	box.add_child(vb)

	_titolo = Label.new()
	_titolo.text = "FINE PARTITA"
	_titolo.add_theme_font_size_override("font_size", 38)
	_titolo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_titolo)

	_sottotitolo = Label.new()
	_sottotitolo.text = ""
	_sottotitolo.add_theme_font_size_override("font_size", 17)
	_sottotitolo.add_theme_color_override("font_color", CREAM)
	_sottotitolo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sottotitolo.autowrap_mode = TextServer.AUTOWRAP_WORD
	_sottotitolo.custom_minimum_size.x = 380
	vb.add_child(_sottotitolo)

	var separatore := HSeparator.new()
	vb.add_child(separatore)

	vb.add_child(_make_button("Rivedi la trattativa", _on_rivedi))
	vb.add_child(_make_button("Torna al menu principale", _on_main_menu))
	vb.add_child(_make_button("Esci dal gioco", _on_quit))


func _make_button(text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(360, 50)
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_color_override("font_color", CREAM)
	b.add_theme_color_override("font_hover_color", GOLD)
	b.add_theme_color_override("font_focus_color", GOLD)
	b.process_mode = Node.PROCESS_MODE_ALWAYS

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.06, 0.06, 0.08, 0.55)
	normal.set_corner_radius_all(8)
	normal.set_border_width_all(2)
	normal.border_color = Color(0.85, 0.7, 0.36, 0.55)
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8

	var hover := normal.duplicate()
	hover.bg_color = Color(0.16, 0.13, 0.09, 0.85)
	hover.border_color = GOLD

	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover.duplicate())
	b.add_theme_stylebox_override("focus", hover)

	b.mouse_entered.connect(func(): _sfx_hover.play())
	b.pressed.connect(func():
		_sfx_click.play()
		callback.call()
	)
	return b

# Chiamato da menu_dialog.gd (via NegotiationChat.concludi) col tono deciso
# da giudice.asl, o da NegotiationChat._on_torna_pressed per tornarci sopra.
func mostra(tono: String) -> void:
	var dati: Array = TESTI.get(tono, ["FINE PARTITA", CREAM, ""])
	_titolo.text = dati[0]
	_titolo.add_theme_color_override("font_color", dati[1])
	_sottotitolo.text = dati[2]
	_panel.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true

func _on_rivedi() -> void:
	_panel.visible = false
	NegotiationChat.riapri()

func _on_main_menu() -> void:
	get_tree().paused = false
	_panel.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)

func _on_quit() -> void:
	get_tree().quit()
