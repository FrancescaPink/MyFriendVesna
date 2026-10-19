extends CanvasLayer

# ============================================================
#  Menu di pausa globale (Autoload) — richiamabile con Esc in qualunque
#  scena di gioco (casa, città, tribunale). Non richiede modifiche alle
#  singole scene: essendo un Autoload è già presente ovunque.
#  Stesso stile visivo del menu principale.
# ============================================================

const MAIN_MENU_SCENE := "res://menu/main_menu.tscn"

const GOLD  := Color(0.85, 0.7, 0.36)
const CREAM := Color(0.96, 0.94, 0.9)

var _panel: Control
var _open := false
var _sfx_hover: AudioStreamPlayer
var _sfx_click: AudioStreamPlayer
var _mouse_mode_before := Input.MOUSE_MODE_CAPTURED

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100  # sempre sopra al resto dell'interfaccia di gioco
	_build_ui()
	_build_audio()

func _build_audio() -> void:
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
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(dim)

	var box := PanelContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(360, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.08, 0.07, 0.97)
	style.set_corner_radius_all(14)
	style.set_border_width_all(2)
	style.border_color = GOLD
	style.set_content_margin_all(28)
	box.add_theme_stylebox_override("panel", style)
	_panel.add_child(box)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	box.add_child(vb)

	var title := Label.new()
	title.text = "Pausa"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)

	vb.add_child(_make_button("Riprendi", _on_resume))
	vb.add_child(_make_button("Menu principale", _on_main_menu))
	vb.add_child(_make_button("Esci dal gioco", _on_quit))

	call_deferred("_recenter", box)

func _recenter(box: PanelContainer) -> void:
	await get_tree().process_frame
	var vp := get_viewport().get_visible_rect().size
	box.position = (vp - box.size) * 0.5

func _make_button(text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(300, 54)
	b.add_theme_font_size_override("font_size", 24)
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

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	# non interferire con il menu principale (gestisce Esc per il suo pannello Storia)
	var cur := get_tree().current_scene
	if cur != null and cur.scene_file_path == MAIN_MENU_SCENE:
		return
	# non aprirsi sopra a un dialogo già attivo (es. conversazione con Bob)
	if not _open:
		var dialog := get_tree().root.find_child("DialogInterface", true, false)
		if dialog != null and dialog.visible:
			return
	_toggle()
	get_viewport().set_input_as_handled()

func _toggle() -> void:
	if _open:
		_close()
	else:
		_openpause()

func _openpause() -> void:
	_open = true
	_panel.visible = true
	get_tree().paused = true
	_mouse_mode_before = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _close() -> void:
	_open = false
	_panel.visible = false
	get_tree().paused = false
	Input.mouse_mode = _mouse_mode_before

func _on_resume() -> void:
	_close()

func _on_main_menu() -> void:
	get_tree().paused = false
	_open = false
	_panel.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)

func _on_quit() -> void:
	get_tree().quit()
