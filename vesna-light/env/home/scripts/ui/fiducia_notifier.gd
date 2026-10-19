extends CanvasLayer

# Piccola notifica temporanea in alto a sinistra per i cambi di fiducia
# (es. "+1 Fiducia" / "-1 Fiducia"). Nodo separato da DialogInterface: non
# tocca in alcun modo il riquadro di dialogo o menu_dialog.gd.

@onready var _label: Label = $Label
var _tween: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 95
	_label.modulate.a = 0.0

func mostra(testo: String) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_label.text = testo
	_label.modulate.a = 1.0
	_tween = create_tween()
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_interval(2.0)
	_tween.tween_property(_label, "modulate:a", 0.0, 0.6)
