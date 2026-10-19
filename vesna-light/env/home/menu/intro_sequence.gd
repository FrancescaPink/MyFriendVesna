extends CanvasLayer

# ============================================================
#  Sequenza di apertura del gioco: telefonata dello studio legale +
#  fascicolo del caso. Parte automaticamente non appena si entra nella
#  scena di gioco (home.tscn o main.tscn), prima che il giocatore prenda
#  il controllo. Autoload globale: non richiede modifiche alle scene.
# ============================================================

const GOLD  := Color(0.85, 0.7, 0.36)
const CREAM := Color(0.96, 0.94, 0.9)
const PAPER := Color(0.92, 0.88, 0.78)
const INK   := Color(0.16, 0.13, 0.09)


const PHONE_LINES := [
	["STUDIO LEGALE BARONI & ASSOCIATI", true],
	["— Pronto?", false],
	["— Buongiorno, Avvocato. Le abbiamo assegnato un nuovo caso.", false],
	["— Di cosa si tratta?", false],
	["— Accesso abusivo a un sistema informatico. NovaTech Systems contro\nun loro dipendente, un certo Bob Parker. Le prove puntano al suo domicilio.", false],
	["— Capisco. Mi metto subito in viaggio.", false],
	["— Il cliente la aspetta a casa sua. Buona fortuna.", false],
]

const FASCICOLO_TEXT := "[center][b]FASCICOLO N. 2024/0417[/b][/center]

[b]Imputato:[/b] Bob Parker
[b]Reato contestato:[/b] Accesso abusivo a sistema informatico (art. 615-ter c.p.)
[b]Parte lesa:[/b] NovaTech Systems

[b]Sintesi:[/b] Violazione dei server aziendali con sottrazione di dati finanziari riservati e richiesta di riscatto. Le tracce del login non autorizzato risalgono all'indirizzo IP dell'abitazione dell'imputato.

[b]Incarico:[/b] Difensore d'ufficio"

var _shown := false
var _skip_requested := false
var _root: Control
var _label: Label
var _fascicolo: Control
var _paper: PanelContainer
var _continue_hint: Label
var _sfx_ring: AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 90
	_build_ui()
	_build_audio()

func _build_audio() -> void:
	_sfx_ring = AudioStreamPlayer.new()
	_sfx_ring.stream = load("res://assets/intro/phone_ring.wav")
	_sfx_ring.volume_db = -3.0
	_sfx_ring.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_sfx_ring)

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.process_mode = Node.PROCESS_MODE_ALWAYS
	_root.visible = false
	add_child(_root)

	var bg := TextureRect.new()
	bg.texture = load("res://assets/intro/office_desk.png")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_root.add_child(bg)

	# leggero scurimento per garantire contrasto col testo sopra
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.38)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	# --- testo della telefonata (centrato) ---
	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 30)
	_label.add_theme_color_override("font_color", CREAM)
	_label.modulate.a = 0.0
	_label.custom_minimum_size = Vector2(900, 200)
	_root.add_child(_label)

	# --- fascicolo (documento) ---
	_fascicolo = Control.new()
	_fascicolo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fascicolo.visible = false
	_root.add_child(_fascicolo)

	var paper_dim := ColorRect.new()
	paper_dim.color = Color(0, 0, 0, 0.5)
	paper_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fascicolo.add_child(paper_dim)

	var paper := PanelContainer.new()
	paper.custom_minimum_size = Vector2(680, 0)
	var pstyle := StyleBoxFlat.new()
	pstyle.bg_color = PAPER
	pstyle.set_corner_radius_all(4)
	pstyle.set_border_width_all(2)
	pstyle.border_color = Color(0.5, 0.45, 0.35)
	pstyle.set_content_margin_all(34)
	paper.add_theme_stylebox_override("panel", pstyle)
	_fascicolo.add_child(paper)

	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.fit_content = true
	rtl.custom_minimum_size = Vector2(612, 0)
	rtl.add_theme_font_size_override("normal_font_size", 19)
	rtl.add_theme_color_override("default_color", INK)
	rtl.text = FASCICOLO_TEXT
	paper.add_child(rtl)
	_paper = paper

	_continue_hint = Label.new()
	_continue_hint.text = "premi un tasto per continuare"
	_continue_hint.add_theme_font_size_override("font_size", 16)
	_continue_hint.add_theme_color_override("font_color", CREAM)
	_continue_hint.visible = false
	_root.add_child(_continue_hint)

# Va chiamato SOLO dopo che _fascicolo.visible è stato messo a true: un
# RichTextLabel con fit_content non calcola l'altezza reale finché il nodo
# non è effettivamente visibile (da nascosto la size resta bloccata su un
# valore piccolo di default, "stabile" ma sbagliato).
func _layout_fascicolo() -> void:
	var last_size := Vector2(-1, -1)
	for i in 20:
		await get_tree().process_frame
		if _paper.size == last_size and _paper.size.y > 1.0:
			break
		last_size = _paper.size
	var vp := get_viewport().get_visible_rect().size
	# il pannello ha altezza variabile in base al testo: si centra, e la scritta
	# "premi un tasto" va posizionata SOTTO al pannello vero, non a un'altezza fissa
	_paper.position = (vp - _paper.size) * 0.5
	var hint_y: float = min(_paper.position.y + _paper.size.y + 24.0, vp.y - 40.0)
	_continue_hint.position = Vector2(vp.x * 0.5 - 100, hint_y)

## Da chiamare quando si avvia la transizione verso il gioco (es. dal pulsante
## "Avvia gioco" del menu), PRIMA di change_scene_to_file(): copre subito lo
## schermo così non si vede un fotogramma della scena di gioco (la casa) prima
## che la sequenza di apertura sia pronta a partire.
func begin_transition_cover() -> void:
	# _root diventa visibile QUI, subito, ben prima che _play_sequence() parta
	# (che aspetta il caricamento della nuova scena): senza questo reset, nel
	# frattempo si vedrebbe ancora lo stato lasciato dalla run precedente
	# (es. il fascicolo, se era rimasto visible=true), con un flash prima
	# che la scenetta della telefonata possa anche solo iniziare.
	_fascicolo.visible = false
	_fascicolo.modulate.a = 0.0
	_continue_hint.visible = false
	_continue_hint.modulate.a = 0.0
	_label.modulate.a = 0.0
	_root.visible = true
	_root.modulate.a = 1.0

const MAIN_MENU_SCENE_PATH := "res://menu/main_menu.tscn"

func _process(_delta: float) -> void:
	# Controllo ad ogni frame (non solo all'avvio del processo): all'avvio
	# vero e proprio del gioco la scena attiva è il MENU principale, non
	# home.tscn/main.tscn — quella scena arriva solo più tardi, quando il
	# giocatore clicca "Avvia gioco" e change_scene_to_file() la sostituisce.
	# Un controllo fatto una sola volta all'inizio se lo perde per sempre.
	var cur := get_tree().current_scene
	if cur == null:
		return
	var path := cur.scene_file_path

	if _shown:
		# Se si torna al menu principale (es. da "Menu principale" nella
		# pausa), riarma la sequenza: essendo un Autoload, _shown resterebbe
		# altrimenti true per tutta la vita del processo, e "Avvia gioco"
		# una seconda volta non la farebbe più ripartire.
		if path == MAIN_MENU_SCENE_PATH:
			_shown = false
		return

	if path == "res://scenes/home.tscn" or path == "res://scenes/main.tscn":
		_shown = true
		_play_sequence()

func _unhandled_input(event: InputEvent) -> void:
	if not _root.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		_skip_requested = true
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		_skip_requested = true
		get_viewport().set_input_as_handled()

func _fade(node: CanvasItem, to: float, dur: float) -> void:
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(node, "modulate:a", to, dur)
	await tw.finished

func _wait_or_skip(seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		if _skip_requested:
			return
		await get_tree().process_frame
		elapsed += get_process_delta_time()

func _play_sequence() -> void:
	# Azzero qui, non solo dentro il blocco del fascicolo: se il giocatore
	# salta la sequenza PRIMA di arrivare la', quel reset non viene mai
	# eseguito e la variabile resta bloccata su true, facendo si' che la
	# corsa successiva si "auto-salti" istantaneamente fin dall'inizio.
	_skip_requested = false
	# _root e i suoi figli sono nodi persistenti dell'autoload: senza questo
	# reset, _fascicolo resterebbe visible=true (e opaco) dalla corsa
	# precedente e coprirebbe subito lo schermo alla corsa successiva,
	# nascondendo la scenetta della telefonata che gira comunque sotto.
	_fascicolo.visible = false
	_fascicolo.modulate.a = 0.0
	_continue_hint.visible = false
	_continue_hint.modulate.a = 0.0
	_label.modulate.a = 0.0
	get_tree().paused = true
	var prev_mouse_mode := Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_root.visible = true
	_root.modulate.a = 1.0

	_sfx_ring.play()
	await _wait_or_skip(1.6)

	for line in PHONE_LINES:
		if _skip_requested:
			break
		var text: String = line[0]
		var is_title: bool = line[1]
		_label.text = text
		_label.add_theme_font_size_override("font_size", 34 if is_title else 26)
		_label.add_theme_color_override("font_color", GOLD if is_title else CREAM)
		await _fade(_label, 1.0, 0.35)
		await _wait_or_skip(2.3 if not is_title else 1.6)
		await _fade(_label, 0.0, 0.3)

	# --- fascicolo ---
	if not _skip_requested:
		_fascicolo.modulate.a = 0.0
		_fascicolo.visible = true
		# alpha a zero PRIMA di rendere visibile: la posizione corretta (sotto
		# al fascicolo) viene calcolata da _layout_fascicolo() solo dopo, e nel
		# frattempo il nodo sarebbe visibile alla sua posizione di default
		# (in alto a sinistra) per qualche frame, causando un lampo indesiderato
		_continue_hint.modulate.a = 0.0
		_continue_hint.visible = true
		# ora che è visibile, il RichTextLabel può calcolare la sua vera altezza
		await _layout_fascicolo()
		# reset PRIMA delle dissolvenze: un tasto premuto durante la comparsa
		# del fascicolo deve comunque contare come richiesta di continuare,
		# non essere silenziosamente cancellato quando le dissolvenze finiscono
		_skip_requested = false
		await _fade(_fascicolo, 1.0, 0.6)
		await _fade(_continue_hint, 1.0, 0.6)
		await _wait_or_skip(30.0)  # aspetta input del giocatore (con limite di sicurezza)

	# --- dissolvenza verso il gioco ---
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_root, "modulate:a", 0.0, 0.8)
	await tw.finished

	_root.visible = false
	get_tree().paused = false
	Input.mouse_mode = prev_mouse_mode if prev_mouse_mode != Input.MOUSE_MODE_VISIBLE else Input.MOUSE_MODE_CAPTURED
