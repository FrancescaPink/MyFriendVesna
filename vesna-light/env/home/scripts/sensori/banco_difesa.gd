extends Area3D

# Zona al banco della difesa, in tribunale. Il giocatore entra in aula libero
# di muoversi; l'udienza comincia solo quando prende posto qui e preme Q.
#
# Perché non parte all'ingresso: aprire il dialogo appena varcata la porta
# lasciava il giocatore inchiodato sulla soglia senza avere ancora visto l'aula,
# e non si capiva cosa stesse succedendo (segnalato dall'utente). Così invece
# c'è un gesto esplicito — vai al tuo banco, apri il processo — che è anche più
# fedele a quello che farebbe un avvocato.
#
# Diverso da sensor_dialogue.gd: quello sta addosso a un NPC e apre una
# conversazione con lui; questo sta in un LUOGO e apre un procedimento. Per
# questo non usa get_parent() come interlocutore ma il Giudice, ovunque sia.

var giocatore_presente: bool = false
var processo_avviato: bool = false

# Avviso a schermo, stesso schema di radio e PC (UIRadio / UI_PC in
# home.tscn): un CanvasLayer che si accende avvicinandosi. Una Label3D
# piantata nella scena diventa illeggibile appena ci si avvicina.
@onready var _scritta: CanvasLayer = $UIBanco

func _ready() -> void:
	_scritta.visible = false

func _on_body_entered(body: Node3D) -> void:
	if not ("FirstPersonCharacter" in body.name):
		return
	giocatore_presente = true
	if not processo_avviato:
		_scritta.visible = true

func _on_body_exited(body: Node3D) -> void:
	if not ("FirstPersonCharacter" in body.name):
		return
	giocatore_presente = false
	_scritta.visible = false

func _process(_delta: float) -> void:
	if processo_avviato or not giocatore_presente:
		return
	if not Input.is_action_just_pressed("speak"):
		return

	var menu = get_tree().root.find_child("DialogInterface", true, false)
	if menu == null:
		print("ERRORE: DialogInterface non trovato, l'udienza non può iniziare.")
		return
	if menu.visible:
		return  # un dialogo è già aperto

	processo_avviato = true
	_scritta.visible = false

	# Rete di sicurezza: rimanda alle menti tutte le prove raccolte, nel caso
	# qualcuna fosse stata ottenuta mentre l'agente destinatario non era ancora
	# connesso (vedi inventario.gd).
	var inventario = get_tree().root.find_child("Inventario", true, false)
	if inventario != null:
		inventario.reinvia_tutto()

	# Il Giudice diventa l'interlocutore e si apre il riquadro di dialogo:
	# l'udienza si gioca col sistema di dialogo già esistente, e siccome parla
	# un solo agente per volta il filtro sul mittente non dà problemi (a
	# differenza della trattativa, dove parlano in tre — vedi giudice.asl).
	menu.imposta_interlocutore("Giudice")
	# Da qui il riquadro entra in modalità processo: niente "Come va?", niente
	# uscita finché non arriva il verdetto (vedi menu_dialog.gd).
	menu.avvia_modo_processo()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	menu.visible = true

	_avvisa_giudice()

# Manda alla mente del Giudice il segnale che apre il procedimento, sullo
# stesso canale usato da tutti i sensori.
func _avvisa_giudice() -> void:
	var giudice = get_tree().root.find_child("Giudice", true, false)
	if giudice == null or not ("ws" in giudice):
		print("ATTENZIONE: nessun Giudice collegato, il processo non partirà.")
		return
	if giudice.ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		print("ATTENZIONE: la mente del Giudice non è connessa.")
		return
	giudice.ws.send_text(JSON.stringify({
		"sender": "body",
		"receiver": "vesna",
		"type": "signal",
		"data": {"type": "processo", "status": "iniziato", "reason": "banco"},
	}))
	print("Udienza aperta: avvisata la mente del Giudice.")
