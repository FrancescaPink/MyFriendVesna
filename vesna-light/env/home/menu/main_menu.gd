extends Control

# ============================================================
#  Menu iniziale di MyFriendVesna — "Il Caso Bob"
#  Costruito interamente via codice per robustezza.
#  Non dipende da, né modifica, nessuna scena/logica di gioco.
# ============================================================

const GAME_SCENE := "res://scenes/main.tscn"   # gioco completo (casa + città)

const GAVEL_BG := preload("res://menu/gavel_background.gd")

const GOLD  := Color(0.85, 0.7, 0.36)
const CREAM := Color(0.96, 0.94, 0.9)

# Lo sfondo (animazione vettoriale del martelletto) viene disegnato a doppia
# risoluzione dentro un SubViewport e poi ridotto a schermo: supersampling,
# così i bordi in rotazione restano lisci e senza sfarfallio.
const VP_SIZE := Vector2i(2560, 1440)

var _sv: SubViewport      # viewport ad alta risoluzione
var _screen: TextureRect  # output a schermo (downscale 2:1 = antialiasing)
var _gavel: Control       # animazione del martelletto
var _music: AudioStreamPlayer
var _sfx_hover: AudioStreamPlayer
var _sfx_click: AudioStreamPlayer
var _sfx_gavel: AudioStreamPlayer
var _fade: ColorRect
var _story_panel: Control
var _story_box: PanelContainer

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	_build_stage()
	_build_scrim()
	_build_audio()
	_build_title()
	_build_buttons()
	_build_story_panel()
	_build_fade_in()

	# il martelletto suona a ogni colpo
	_gavel.impact.connect(_on_gavel_impact)

# -------------------- SFONDO ANIMATO (martelletto) --------------------
func _build_stage() -> void:
	# viewport ad alta risoluzione (renderizzato offscreen)
	_sv = SubViewport.new()
	_sv.size = VP_SIZE
	_sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_sv.transparent_bg = false
	add_child(_sv)

	# l'animazione vettoriale vive dentro il viewport, quindi viene disegnata
	# al doppio della risoluzione e poi rimpicciolita = bordi lisci
	_gavel = Control.new()
	_gavel.set_script(GAVEL_BG)
	_gavel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sv.add_child(_gavel)

	# output a schermo: mostra la texture del viewport riducendola (2:1) => antialiasing
	_screen = TextureRect.new()
	_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_screen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_screen.texture = _sv.get_texture()
	_screen.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_screen)

func _on_gavel_impact() -> void:
	_sfx_gavel.play()

# -------------------- SCRIM (leggibilità testo) --------------------
func _build_scrim() -> void:
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0.82))
	grad.set_color(1, Color(0, 0, 0, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0.9, 0)
	gt.width = 512
	gt.height = 8
	var tr := TextureRect.new()
	tr.texture = gt
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tr)

	var bottom := ColorRect.new()
	bottom.color = Color(0, 0, 0, 0.28)
	bottom.set_anchors_preset(Control.PRESET_FULL_RECT)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bottom)

# -------------------- AUDIO --------------------
func _build_audio() -> void:
	_music = AudioStreamPlayer.new()
	var m := load("res://assets/menu/MusicMenu.mp3")
	if m is AudioStreamWAV:
		m.loop_mode = AudioStreamWAV.LOOP_FORWARD
		m.loop_begin = 0
		m.loop_end = m.data.size() / 4  # 16 bit stereo = 4 byte per frame
	_music.stream = m
	_music.volume_db = -8.0
	add_child(_music)
	_music.play()

	_sfx_hover = AudioStreamPlayer.new()
	_sfx_hover.stream = load("res://assets/menu/hover.wav")
	_sfx_hover.volume_db = -14.0
	add_child(_sfx_hover)

	_sfx_click = AudioStreamPlayer.new()
	_sfx_click.stream = load("res://assets/menu/click.wav")
	_sfx_click.volume_db = -6.0
	add_child(_sfx_click)

	_sfx_gavel = AudioStreamPlayer.new()
	_sfx_gavel.stream = load("res://assets/menu/gavel_hit.wav")
	_sfx_gavel.volume_db = -4.0
	add_child(_sfx_gavel)

# -------------------- TITOLO --------------------
func _build_title() -> void:
	var box := VBoxContainer.new()
	box.position = Vector2(90, 90)
	box.add_theme_constant_override("separation", 2)
	add_child(box)

	var title := Label.new()
	title.text = "My Friend Vesna"
	title.add_theme_font_size_override("font_size", 90)
	title.add_theme_color_override("font_color", CREAM)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 4)
	box.add_child(title)

	var sub := Label.new()
	sub.text = "Beyond The Verdict"
	sub.add_theme_font_size_override("font_size", 40)
	sub.add_theme_color_override("font_color", GOLD)
	box.add_child(sub)

# -------------------- PULSANTI --------------------
func _style_button(b: Button) -> void:
	b.custom_minimum_size = Vector2(340, 62)
	b.add_theme_font_size_override("font_size", 30)
	b.add_theme_color_override("font_color", CREAM)
	b.add_theme_color_override("font_hover_color", GOLD)
	b.add_theme_color_override("font_focus_color", GOLD)
	b.focus_mode = Control.FOCUS_ALL

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.06, 0.06, 0.08, 0.55)
	normal.set_corner_radius_all(8)
	normal.set_border_width_all(2)
	normal.border_color = Color(0.85, 0.7, 0.36, 0.55)
	normal.content_margin_left = 22
	normal.content_margin_right = 22
	normal.content_margin_top = 10
	normal.content_margin_bottom = 10

	var hover := normal.duplicate()
	hover.bg_color = Color(0.16, 0.13, 0.09, 0.85)
	hover.border_color = GOLD

	var pressed := hover.duplicate()
	pressed.bg_color = Color(0.24, 0.19, 0.11, 0.9)

	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("focus", hover)

func _make_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	_style_button(b)
	b.mouse_entered.connect(func(): _sfx_hover.play())
	return b

func _build_buttons() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	box.position = Vector2(96, 320)
	add_child(box)

	var play := _make_button("▶  Avvia gioco")
	play.pressed.connect(_on_play)
	box.add_child(play)

	var story := _make_button("📖  Storia")
	story.pressed.connect(_on_story)
	box.add_child(story)

	var quit := _make_button("✕  Esci")
	quit.pressed.connect(_on_quit)
	box.add_child(quit)

	play.grab_focus()

	var credit := Label.new()
	credit.text = "Un'avventura con agenti BDI · JaCaMo + Godot 4"
	credit.add_theme_font_size_override("font_size", 18)
	credit.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 0.7))
	credit.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	credit.position = Vector2(96, get_viewport_rect().size.y - 46)
	add_child(credit)

# -------------------- PANNELLO STORIA --------------------
func _build_story_panel() -> void:
	_story_panel = Control.new()
	_story_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_story_panel.visible = false
	add_child(_story_panel)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_story_panel.add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.custom_minimum_size = Vector2(640, 0)  # altezza libera: si adatta al contenuto
	var pstyle := StyleBoxFlat.new()
	pstyle.bg_color = Color(0.09, 0.08, 0.07, 0.97)
	pstyle.set_corner_radius_all(14)
	pstyle.set_border_width_all(2)
	pstyle.border_color = GOLD
	pstyle.set_content_margin_all(22)
	panel.add_theme_stylebox_override("panel", pstyle)
	_story_panel.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	panel.add_child(vb)

	var h := Label.new()
	h.text = "Il Caso Bob"
	h.add_theme_font_size_override("font_size", 32)
	h.add_theme_color_override("font_color", GOLD)
	vb.add_child(h)

	var body := RichTextLabel.new()
	body.bbcode_enabled = true
	body.fit_content = true
	body.custom_minimum_size = Vector2(596, 0)
	body.add_theme_font_size_override("normal_font_size", 17)
	body.add_theme_color_override("default_color", CREAM)
	body.text = _story_text()
	vb.add_child(body)

	var back := _make_button("← Indietro")
	back.custom_minimum_size = Vector2(180, 44)
	back.add_theme_font_size_override("font_size", 22)
	back.pressed.connect(func():
		_sfx_click.play()
		_story_panel.visible = false
	)
	vb.add_child(back)

	# la larghezza è fissa, l'altezza dipende dal testo: centriamo dopo che il
	# layout è stato calcolato, così non esce mai dallo schermo indipendentemente
	# dalla risoluzione della finestra di gioco.
	_story_box = panel
	call_deferred("_center_story_panel", panel)

func _center_story_panel(panel: PanelContainer) -> void:
	await get_tree().process_frame
	var vp := get_viewport_rect().size
	var size := panel.size
	var pos := (vp - size) * 0.5
	# non esce mai dai bordi, qualunque sia la risoluzione della finestra
	pos.x = clamp(pos.x, 20.0, max(20.0, vp.x - size.x - 20.0))
	pos.y = clamp(pos.y, 20.0, max(20.0, vp.y - size.y - 20.0))
	panel.position = pos

func _story_text() -> String:
	return "Bob si è appena trasferito in una nuova casa quando i server della società per cui " + \
		"lavora subiscono una grave violazione informatica. Le tracce del login non autorizzato " + \
		"portano dritte al suo indirizzo di casa — proprio nelle ore in cui giura di dormire.\n\n" + \
		"[color=#d8b45c]Tu sei l'avvocato chiamato a difenderlo.[/color] Ma Bob non si fida di " + \
		"nessuno, e la verità va guadagnata prima di poterla portare in tribunale.\n\n" + \
		"• [b]Atto 1 — La casa:[/b] conquista la fiducia di Bob e farti raccontare cos'è successo.\n" + \
		"• [b]Atto 2 — La città:[/b] raccogli prove e testimonianze tra vicini e colleghi.\n" + \
		"• [b]Atto 3 — Il tribunale:[/b] affronta il processo, dove il verdetto nasce da una vera " + \
		"negoziazione tra gli agenti."

# -------------------- DISSOLVENZA --------------------
func _build_fade_in() -> void:
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 1)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", 0.0, 1.0)

# -------------------- AZIONI --------------------
func _on_play() -> void:
	_sfx_click.play()
	_fade.modulate.a = 1.0
	_fade.color = Color(0, 0, 0, 1)
	move_child(_fade, get_child_count() - 1)
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", 1.0, 0.6)
	await tw.finished
	# copre subito lo schermo prima del cambio scena, altrimenti si vedrebbe
	# un fotogramma della casa prima che la sequenza di apertura sia pronta
	IntroSequence.begin_transition_cover()
	get_tree().change_scene_to_file(GAME_SCENE)

func _on_story() -> void:
	_sfx_click.play()
	_story_panel.visible = true
	call_deferred("_center_story_panel", _story_box)

func _on_quit() -> void:
	_sfx_click.play()
	await get_tree().create_timer(0.12).timeout
	get_tree().quit()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _story_panel.visible:
			_story_panel.visible = false
