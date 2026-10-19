extends Area3D

# Sensore di presenza reciproca tra NPC (Atto 2, vedi docs/story.md — la
# meccanica di "presenza" richiesta esplicitamente dal professore: Alex non
# rivela certe cose se il Sig. Jefferson è nelle vicinanze).
#
# Diverso da sensor_dialogue.gd: quello rileva il GIOCATORE e apre il menu di
# dialogo; questo rileva ALTRI AGENTI (non il giocatore) e avvisa la PROPRIA
# mente Jason di chi è comparso o sparito nelle vicinanze. Va messo come
# figlio del personaggio che deve "accorgersi" di chi gli sta intorno (qui:
# sia Alex che il Sig. Jefferson, ognuno col proprio sensore, così ciascuno
# sa se l'altro è vicino).
#
# Nota sul pattern: radio_sensor.gd/table_sensor.gd prendono semplicemente il
# primo elemento del gruppo "agents" per mandare un segnale — corretto lì
# perché in Atto 1 c'è un solo Bob. Qui invece serve sapere ESATTAMENTE quale
# mente avvisare (il proprio personaggio, get_parent()) e di CHI si tratta
# (l'altro nodo rilevato), quindi non riusa quel pattern.

# Se un altro agente è già dentro il raggio fin dall'avvio della scena, non
# c'è mai una vera "entrata" da rilevare (erano già sovrapposti al primo
# fotogramma): Area3D in Godot attiva body_entered solo su una transizione,
# non lo emette per corpi già dentro fin dall'inizio. Senza questo controllo
# esplicito, vicino(Chi) non veniva mai impostato e il topic si sbloccava
# subito, come se i due NPC non si fossero mai visti.
#
# IMPORTANTE: non basta un controllo one-shot dopo qualche secondo. main.tscn
# carica TUTTE le scene (casa, città, tribunale) all'avvio del gioco, quindi
# questo _ready() parte molto prima che il giocatore arrivi in città — e con
# ogni probabilità prima che la mente Jason si sia connessa al websocket.
# Un invio unico in quel momento andrebbe perso in silenzio per sempre
# (_segnala() controlla STATE_OPEN e scarta il messaggio se la connessione
# non è pronta). Per questo qui si RIPROVA finché l'invio non riesce davvero.
var _presenza_iniziale_inviata := false

func _ready() -> void:
	set_process(true)

func _process(_delta: float) -> void:
	if _presenza_iniziale_inviata:
		set_process(false)
		return
	var io = get_parent()
	if io == null or not ("ws" in io):
		return
	if io.ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return  # mente non ancora connessa: riprovo al prossimo frame
	_presenza_iniziale_inviata = true
	for body in get_overlapping_bodies():
		_segnala(body, "entered")
	set_process(false)

func _on_body_entered(body: Node3D) -> void:
	_segnala(body, "entered")

func _on_body_exited(body: Node3D) -> void:
	_segnala(body, "exited")

func _segnala(body: Node3D, stato: String) -> void:
	var io = get_parent()
	if io == null or body == io:
		return  # non segnalo la mia stessa presenza a me stesso
	if not body.is_in_group("agents"):
		return  # solo altri NPC: il giocatore lo gestisce sensor_dialogue.gd
	if not ("ws" in io):
		return
	var log_data: Dictionary = {
		"sender": "body",
		"receiver": "vesna",
		"type": "signal",
		"data": {
			"type": "presenza",
			"status": body.name.to_lower(),
			"reason": stato,
		}
	}
	if io.ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		io.ws.send_text(JSON.stringify(log_data))
