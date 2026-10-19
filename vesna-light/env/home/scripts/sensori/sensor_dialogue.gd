extends Area3D

# Con questa variabile stabilisco se mi trovo vicino all'agente o no
var puo_parlare: bool = false

# Mi assicuro che la scritta sia invisibile all'avvio
func _ready() -> void:
	$Label3D2.visible = false

func _on_body_entered(body: Node3D) -> void:
	 # FILTRO: Assicuriamoci che il nome contenga "FirstPersonCharacter"
	if "FirstPersonCharacter" in body.name:
		print("Player entrato!")
		# 1. Assicurati che il nome del nodo Label sia corretto
		var label = get_node_or_null("Label3D2")
		if label:
			label.visible = true
			print("Label impostata su visibile")
		puo_parlare = true

# Quando mi allontano la scritta sparisce
func _on_body_exited(body: Node3D) -> void:
	if body.name != "FirstPersonCharacter": 
		return
	$Label3D2.visible = false
	puo_parlare = false
	
# Questa funzione gira ad ogni frame (60 volte al secondo) per ascoltare i tasti
func _process(delta: float) -> void:
	if not (puo_parlare and Input.is_action_just_pressed("speak")):
		return

	# Cerca il CanvasLayer nella scena.
	var menu_dialogo = get_tree().root.find_child("DialogInterface", true, false)
	if menu_dialogo == null:
		print("ERRORE: Non riesco a trovare il nodo DialogInterface. Controlla il nome!")
		return

	# Dialogo già aperto: non lo riapro e soprattutto non cambio interlocutore
	# sotto i piedi di chi lo ha appena aperto. Serve anche perché questi
	# sensori continuano a girare a gioco in pausa (process_mode ALWAYS sul
	# personaggio), quindi premere Q dentro il dialogo li rifarebbe scattare.
	if menu_dialogo.visible:
		return

	# Se il giocatore è nel raggio di più NPC contemporaneamente parla solo il
	# più vicino. Senza questo controllo, al bar (dove il Sig. Jefferson in
	# pausa sta a 0.72 da Chloe) lo stesso tasto Q fa reagire ENTRAMBI i
	# sensori nello stesso fotogramma: il secondo cambia interlocutore e
	# azzera i bottoni appena creati dal primo, e siccome il menu è già
	# visibile _on_menu_aperto() non riparte — il riquadro resta senza nessun
	# bottone tranne quello di chiusura (bug segnalato dall'utente).
	if not _sono_il_piu_vicino_al_giocatore():
		return

	print("BINGO! Hai premuto Q mentre eri vicino all'agente!")
	# Non assegno agente_attivo direttamente: imposta_interlocutore()
	# svuota anche la coda di argomenti del personaggio precedente,
	# altrimenti i suoi bottoni restano addosso a questo.
	menu_dialogo.imposta_interlocutore(get_parent().name)
	# Rende visibile il menu
	menu_dialogo.visible = true
	# Sblocca la freccetta del mouse per far cliccare i bottoni
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Nasconde la scritta fluttuante "Premi per parlare" mentre sei nel menu
	$Label3D2.visible = false
	# METTO IN PAUSA IL GIOCO (Il giocatore si blocca)
	get_tree().paused = true

# Vero se nessun altro agente che ha a sua volta il giocatore nel raggio è più
# vicino di me. In caso di parità vince chi arriva primo, va benissimo.
func _sono_il_piu_vicino_al_giocatore() -> bool:
	var giocatore = get_tree().root.find_child("FirstPersonCharacter", true, false)
	if giocatore == null:
		return true
	var io = get_parent()
	var mia_distanza = io.global_position.distance_to(giocatore.global_position)
	for altro in get_tree().get_nodes_in_group("agents"):
		if altro == io:
			continue
		var suo_sensore = altro.get_node_or_null("Area3D")
		if suo_sensore == null or not ("puo_parlare" in suo_sensore):
			continue
		if not suo_sensore.puo_parlare:
			continue  # il giocatore non è nel suo raggio: non è in gara
		if altro.global_position.distance_to(giocatore.global_position) < mia_distanza:
			return false
	return true
