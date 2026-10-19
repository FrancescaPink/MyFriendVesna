extends CanvasLayer

# Inventario delle prove — abbozzo per l'Atto 1/2 (vedi docs/story.md,
# sezione "Prove raccolte": 6 prove totali possibili in tutto il gioco,
# l'ultima facoltativa). Si apre/chiude col tasto "I" (nuovo, mai usato da
# nessun altro sistema). Nodo completamente isolato: non tocca in alcun modo
# DialogInterface/menu_dialog.gd, PauseMenu o altri menu esistenti.

const PROVE := [
	{"id": "confessione", "titolo": "Indizio: la chiave a Finn", "atto": "Atto 1"},
	{"id": "alex", "titolo": "Testimonianza di Alex sugli allarmi ignorati", "atto": "Atto 2"},
	{"id": "sullivan", "titolo": "Testimonianza del Sig. Sullivan sull'auto sospetta", "atto": "Atto 2"},
	{"id": "movente_finn", "titolo": "Movente di Finn (debiti)", "atto": "Atto 2"},
	{"id": "contraddizione_jefferson", "titolo": "Contraddizione del Sig. Jefferson", "atto": "Atto 2"},
	{"id": "prova_fisica", "titolo": "Prova fisica (chiavetta USB / log)", "atto": "Atto 2 - facoltativa"},
]

var _ottenute: Dictionary = {}

@onready var _lista: VBoxContainer = $Panel/VBox/Lista
@onready var _contatore: Label = $Panel/VBox/Contatore

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 92
	visible = false
	_ricostruisci()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventario"):
		if visible:
			_chiudi()
		elif not get_tree().paused:
			_apri()

func _apri() -> void:
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true

func _chiudi() -> void:
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_tree().paused = false

# Chiamato da Jason (vesna.via.prova, tramite scripts/vesna.gd) o
# direttamente da pc_interaction.gd per il percorso "low morality"
func sblocca(id: String) -> void:
	if not _ottenute.has(id):
		_ottenute[id] = true
		_ricostruisci()
		_avvisa_menti(id)

# Agenti che hanno bisogno di sapere cosa ha in mano il giocatore. Volutamente
# NON tutti: solo chi ha piani che dipendono da questa informazione.
#   Jefferson -> quante prove servono per poterlo incalzare (prova #5)
#   Chloe     -> se il giocatore ha la targa vista dal Sig. Sullivan, così può
#                collegarla a Finn
#   Difesa      -> le prove sono le sue munizioni argomentative in aula (Atto 3)
#   Procuratore -> il numero di prove determina quanto e' disposto a scendere
const MENTI_INTERESSATE := ["Jefferson", "Chloe", "Difesa", "Procuratore", "Giudice"]

# Comunica alle menti interessate ogni prova appena raccolta.
#
# Sta QUI dentro e non nei singoli agenti apposta: così copre anche il percorso
# "low morality" dell'hacking del PC, che sblocca una prova chiamando
# direttamente sblocca() senza passare da Jason (vedi pc_interaction.gd).
#
# Il pacchetto usa lo stesso formato dei sensori: VesnaAgent.handle_event() lo
# trasforma nella credenza prova_raccolta(<id>, ottenuta). Gli id delle prove
# sono già tutti minuscoli e senza spazi, quindi sono atomi Jason validi.
func _avvisa_menti(id: String) -> void:
	for agente in get_tree().get_nodes_in_group("agents"):
		if not (agente.name in MENTI_INTERESSATE):
			continue
		if not ("ws" in agente):
			continue
		if agente.ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
			continue  # mente non connessa: la prova resta comunque nell'inventario
		agente.ws.send_text(JSON.stringify({
			"sender": "body",
			"receiver": "vesna",
			"type": "signal",
			"data": {"type": "prova_raccolta", "status": id, "reason": "ottenuta"},
		}))

# Rimanda alle menti interessate TUTTE le prove già raccolte. Chiamato quando
# si entra in tribunale (menu_dialog.gd): è una rete di sicurezza per le prove
# eventualmente ottenute mentre la mente destinataria non era ancora connessa,
# caso in cui _avvisa_menti() le aveva scartate. Gli agenti ignorano da soli i
# doppioni (vedi difesa.asl e jefferson.asl), quindi rimandare è innocuo.
func reinvia_tutto() -> void:
	for id in _ottenute.keys():
		_avvisa_menti(id)

# Quante prove sono state raccolte finora, e quante ne esistono in tutto.
# Serve ai varchi a senso unico (menu_dialog.gd) per dire al giocatore cosa si
# sta lasciando alle spalle prima di confermare.
func conteggio() -> Vector2i:
	return Vector2i(_ottenute.size(), PROVE.size())

func _ricostruisci() -> void:
	for figlio in _lista.get_children():
		figlio.queue_free()
	var n_ottenute := 0
	for prova in PROVE:
		var riga := Label.new()
		riga.autowrap_mode = TextServer.AUTOWRAP_WORD
		if _ottenute.has(prova["id"]):
			n_ottenute += 1
			riga.text = "[OTTENUTA] " + prova["titolo"] + " (" + prova["atto"] + ")"
		else:
			riga.text = "[???] Prova non ancora trovata (" + prova["atto"] + ")"
			riga.modulate.a = 0.55
		_lista.add_child(riga)
	_contatore.text = "Prove raccolte: %d / %d" % [n_ottenute, PROVE.size()]
