extends CanvasLayer

# ==========================================
# VARIABILI GLOBALI
# ==========================================
var agente_attivo : String = "Bob" # Di default cerca Bob

# Alcune sequenze automatiche mettono in bocca al GIOCATORE (l'avvocato) una
# battuta che parte da sola: per esempio l'affondo sulle date nell'
# interrogatorio di Finn. Arrivando dallo stesso canale delle battute degli NPC
# sembrava che le dicesse l'NPC. Le battute marcate col tag [IO] (stessa
# convenzione di [TOPIC:...]) vengono quindi mostrate in un colore diverso.
const COLORE_GIOCATORE := Color(0.53, 0.79, 1.0)
var _colore_npc : Color = Color.WHITE

# MODALITÀ PROCESSO (Atto 3). Acceso da banco_difesa.gd quando si apre
# l'udienza, spento quando arriva il verdetto. Un dibattimento non è una
# chiacchierata: finché è acceso
#   - non compare "Come va?", che qui non ha senso;
#   - non compare il bottone di uscita, perché il processo va seguito fino
#     alla fine (richiesta esplicita dell'utente);
#   - se una battuta arriva a riquadro chiuso, il riquadro si RIAPRE da solo.
# Quest'ultimo punto è la parte importante: prima, chiudendo il dialogo
# durante una delle pause del giudice, il resto del processo si perdeva per
# sempre e non c'era modo di riaprirlo (il varco al banco è a scatto unico).
var modo_processo : bool = false

# FASE 2 dell'Atto 3 (la trattativa vera e propria). Da quando arriva
# [TRATTATIVA] a quando arriva [FINE:tono], ogni battuta del giudice va nel
# log scorrevole di NegotiationChat invece che in questo riquadro: bottoni e
# topic non servono piu', la negoziazione e' automatica, ed era proprio
# questo lo scambio che il prof. in sede di controllo voleva poter rileggere.
# Il riquadro resta chiuso per tutta la durata: lo riapre solo Godot con la
# schermata finale di EndScreen.
const TAG_INIZIO_TRATTATIVA := "[TRATTATIVA]"
var _negoziazione_attiva : bool = false

func avvia_modo_processo() -> void:
	modo_processo = true

# Cambia interlocutore buttando via la coda di argomenti di quello precedente.
# Serve perché le battute arrivano da Jason in modo ASINCRONO e possono
# atterrare qui dopo che hai già chiuso il dialogo e ti sei spostato su un
# altro personaggio: succedeva con la telefonata di Chloe, che dura ~9 secondi
# per via delle pause di lettura, e i suoi bottoni finivano addosso al Sig.
# Jefferson. Da usare SEMPRE al posto di scrivere agente_attivo direttamente.
func imposta_interlocutore(nome: String) -> void:
	if nome == agente_attivo:
		return
	agente_attivo = nome
	topic_pendenti.clear()
	pulisci_bottoni()
var database_dialoghi : Dictionary = {}
var argomenti_attivi : Array = [] # Evita di creare cloni dello stesso bottone
var topic_pendenti : Array = [] # Salva i topic sbloccati mentre il menu è chiuso

# Domande di conferma per i varchi a senso unico (porte). Quando uno di questi
# topic è in topic_pendenti, il menu mostra SOLO la domanda vera + Sì/No,
# invece del saluto generico con tutti gli altri bottoni della conversazione.
const DOMANDE_CONFERMA := {
	"uscita_casa": "Sei sicuro di voler uscire? Non potrai tornare indietro.",
	"entra_tribunale": "Sei sicuro di voler entrare in tribunale? Non potrai tornare indietro.",
}

# Varchi per cui vale la pena ricordare quante prove si hanno in mano prima di
# confermare: il numero di prove determina il finale, e questi passaggi sono a
# senso unico. L'uscita di casa è esclusa apposta (in Atto 1 le prove non sono
# ancora il punto, e all'inizio sarebbero comunque zero: dirlo lì
# spaventerebbe soltanto).
const CONFERME_CON_PROVE := ["entra_tribunale"]

func _riepilogo_prove(topic_conferma: String) -> String:
	if not topic_conferma in CONFERME_CON_PROVE:
		return ""
	var inventario = get_tree().root.find_child("Inventario", true, false)
	if inventario == null:
		return ""
	var c: Vector2i = inventario.conteggio()
	return "\nFinora hai raccolto %d prove su %d." % [c.x, c.y]

# Messaggi che Bob "dice da solo" aprendo il menu di scatto (reazione a un
# evento, non il giocatore che clicca "Come va?"). Testo fisso + un solo
# bottone "Scusa" che chiude senza altre opzioni: niente saluto generico,
# niente altri bottoni.
const MESSAGGI_SPONTANEI := {
	"rimprovero_pc": "Ehi! Che stai facendo al mio computer?! Così non mi fiderò mai di te!",
}

# Topic che, se pendenti, si mostrano DA SOLI (solo il proprio bottone, testo
# di Bob già presente preservato): sono scambi isolati e autoconclusivi
# (es. il "grazie" per gli scatoloni), non l'inizio di una chiacchierata più
# ampia. Senza questo, "Come va?" e altri topic in sospeso comparirebbero
# insieme, affollando il riquadro senza motivo.
const TOPIC_ESCLUSIVI := ["scatoloni_grazie"]

# ==========================================
# AVVIO E GESTIONE MENU
# ==========================================
func _ready() -> void:
	# 1. Caricamento del database JSON
	var percorso_file = "res://data/topic.json"
	if FileAccess.file_exists(percorso_file):
		var file = FileAccess.open(percorso_file, FileAccess.READ)
		var contenuto_testo = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var errore = json.parse(contenuto_testo)
		if errore == OK:
			database_dialoghi = json.data
			print("SUCCESSO! Dialoghi caricati: ", database_dialoghi)
		else:
			print("ERRORE DI SINTASSI NEL JSON alla riga ", json.get_error_line())
	else:
		print("ERRORE: File topic.json non trovato!")
		
	# 2. Collego il sensore di apertura menu
	self.visibility_changed.connect(_on_menu_aperto)

	# 3. Memorizzo il colore normale del testo, per poterci tornare dopo una
	#    battuta del giocatore
	_colore_npc = $Panel/BobText.get_theme_color("default_color")

# Colora il riquadro a seconda di chi sta parlando. La battuta del giocatore è
# sempre l'intero messaggio, quindi basta cambiare il colore di tutto il testo:
# niente BBCode, così nessun carattere del dialogo rischia di essere
# interpretato come markup.
func _imposta_colore_battuta(del_giocatore: bool) -> void:
	$Panel/BobText.add_theme_color_override(
		"default_color", COLORE_GIOCATORE if del_giocatore else _colore_npc)

# Questa funzione scatta automaticamente quando il menu diventa visibile o invisibile
func _on_menu_aperto() -> void:
	# Se il menu è appena apparso a schermo
	if self.visible == true:
		# Pulisci tutto e mostra solo il bottone iniziale
		pulisci_bottoni()
		# Riapro sempre in "voce dell'NPC": il colore del giocatore vale solo
		# per la singola battuta marcata [IO] che lo ha acceso
		_imposta_colore_battuta(false)
		# CONTROLLO: siamo davanti a una porta con conferma (casa o tribunale)?
		var topic_conferma := ""
		for t in DOMANDE_CONFERMA:
			if t in topic_pendenti:
				topic_conferma = t
				break
		# CONTROLLO: Bob ha qualcosa da dire spontaneamente (es. ti ha appena beccato)?
		var topic_spontaneo := ""
		for t in MESSAGGI_SPONTANEI:
			if t in topic_pendenti:
				topic_spontaneo = t
				break

		if topic_conferma != "":
			# Solo la domanda vera + Sì/No, niente saluto generico o altri bottoni
			$Panel/BobText.text = DOMANDE_CONFERMA[topic_conferma] + _riepilogo_prove(topic_conferma)
			mostra_bottone_topic(topic_conferma)
			$Panel/OptionsContainer/BTNEsci.text = "No, devo ancora controllare"
		elif topic_spontaneo != "":
			# Solo il rimprovero + un bottone per scusarsi, niente saluto generico
			$Panel/BobText.text = MESSAGGI_SPONTANEI[topic_spontaneo]
			$Panel/OptionsContainer/BTNEsci.text = "Scusa"
			topic_pendenti.erase(topic_spontaneo)
		elif modo_processo:
			# In aula non si saluta e non si esce: il riquadro resta in attesa
			# della prossima battuta del giudice, che porta con sé i propri
			# bottoni. Niente "Come va?", niente uscita.
			$Panel/OptionsContainer/BTNEsci.visible = false
		elif topic_pendenti.size() > 0:
			# Bob ha già detto qualcosa da solo mentre il menu era chiuso (es.
			# "grazie per il croissant!"): NON sovrascrivo quel testo col saluto
			# generico, altrimenti il giocatore non lo legge mai.
			var topic_esclusivo := ""
			for t in TOPIC_ESCLUSIVI:
				if t in topic_pendenti:
					topic_esclusivo = t
					break
			$Panel/OptionsContainer/BTNEsci.text = "Ci vediamo dopo."
			if topic_esclusivo != "":
				# Scambio isolato: solo il suo bottone, niente "Come va?" né
				# altri topic pendenti mischiati insieme
				mostra_bottone_topic(topic_esclusivo)
				topic_pendenti.erase(topic_esclusivo)
			else:
				mostra_bottone_topic("comeva")
				for topic in topic_pendenti:
					mostra_bottone_topic(topic)
		else:
			# Dialogo standard con l'agente, nessun evento in sospeso
			$Panel/BobText.text = "Ciao, come posso aiutarti?"
			mostra_bottone_topic("comeva")
			$Panel/OptionsContainer/BTNEsci.text = "Ci vediamo dopo."

	# AGGIUNTA FONDAMENTALE: Se il menu si nasconde (perché ti allontani)
	else:
		# Svuota tutta la memoria per non contaminare il prossimo personaggio
		topic_pendenti.clear()
		pulisci_bottoni()

# ==========================================
# IL MOTORE DINAMICO DEI BOTTONI
# ==========================================

# Crea bottoni dal nulla prendendo il testo dal JSON
func mostra_bottone_topic(topic_id: String) -> void:
	# Se il bottone c'è già o l'ID non esiste nel JSON, fermati
	if topic_id in argomenti_attivi or not database_dialoghi.has(topic_id):
		return 
		
	var nuovo_bottone = Button.new()
	nuovo_bottone.text = database_dialoghi[topic_id]["testo_bottone"]
	# Font più piccolo e bottone più compatto: con fino a 5 bottoni insieme
	# (Come va? + 3 smalltalk + Ci vediamo dopo) quelli di default non
	# stavano nel riquadro, uscivano dal bordo inferiore.
	nuovo_bottone.add_theme_font_size_override("font_size", 15)
	nuovo_bottone.custom_minimum_size.y = 26
	# Salvo l'id del topic sul nodo stesso, cosi' rimuovi_bottone_topic() può
	# ritrovare e distruggere SOLO questo bottone in mezzo agli altri.
	nuovo_bottone.set_meta("topic_id", topic_id)

	# Binding: Collego il click alla funzione universale, passandogli l'ID
	nuovo_bottone.pressed.connect(self._on_bottone_dinamico_pressed.bind(topic_id))
	
	# Aggiungo il bottone dentro il VBoxContainer
	$Panel/OptionsContainer.add_child(nuovo_bottone)
	argomenti_attivi.append(topic_id)
	
	# Cerca il bottone di uscita e spingilo all'ultimo posto (-1)
	for figlio in $Panel/OptionsContainer.get_children():
		if "esci" in figlio.name.to_lower():
			$Panel/OptionsContainer.move_child(figlio, -1)


# La funzione che invia messaggi a Jason per TUTTI i topic!
func _on_bottone_dinamico_pressed(topic_id: String) -> void:
	
	# ==========================================
	# INTERCETTAZIONE DI SISTEMA (CAMBIO LIVELLO)
	# ==========================================
	if topic_id == "uscita_casa":
		print("Teletrasporto in città in corso...")
		var scritta = get_tree().root.find_child("Label3D2", true, false)
		if scritta != null:
			scritta.queue_free() 
			
		get_tree().paused = false
		
		# --- NUOVO SISTEMA DI SPOSTAMENTO ---
		var giocatore = get_tree().root.find_child("FirstPersonCharacter", true, false)
		var punto_spawn = get_tree().root.find_child("CitySpawn", true, false)
		var clima_citta = get_tree().root.find_child("CityEnvironment", true, false)
		
		if giocatore != null and punto_spawn != null:
			giocatore.global_position = punto_spawn.global_position
			giocatore.scale = punto_spawn.scale
			var telecamera = giocatore.get_viewport().get_camera_3d()
			if telecamera != null and clima_citta != null:
				telecamera.environment = clima_citta.environment
		
		self.visible = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		topic_pendenti.clear()
		pulisci_bottoni()
		return

	if topic_id == "entra_tribunale":
		print("Teletrasporto in tribunale in corso...")
		get_tree().paused = false

		var giocatore = get_tree().root.find_child("FirstPersonCharacter", true, false)
		var punto_spawn = get_tree().root.find_child("TribunaleSpawn", true, false)
		var clima_tribunale = get_tree().root.find_child("TribunaleEnvironment", true, false)

		if giocatore != null and punto_spawn != null:
			giocatore.global_position = punto_spawn.global_position
			giocatore.scale = punto_spawn.scale
			var telecamera = giocatore.get_viewport().get_camera_3d()
			if telecamera != null and clima_tribunale != null:
				telecamera.environment = clima_tribunale.environment

		self.visible = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		topic_pendenti.clear()
		pulisci_bottoni()
		return
	# ==========================================
	
	_imposta_colore_battuta(false)
	$Panel/BobText.text = "Sto pensando alla risposta..."
	# Cerca dinamicamente il nodo col nome salvato nella variabile
	var agent_node = get_tree().root.find_child(agente_attivo, true, false)
	
	if agent_node != null:
		var pacchetto : Dictionary = {"sender": "body", "receiver": "vesna", "type": "signal"}
		pacchetto["data"] = {"type": "user_message", "status": topic_id, "reason": "clicked"}
		
		# Invia tramite il WebSocket del personaggio che abbiamo trovato!
		if agent_node.ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
			agent_node.ws.send_text(JSON.stringify(pacchetto))
	else:
		print("ERRORE: Non trovo nessun agente chiamato: ", agente_attivo)

	# Tolgo SOLO il topic appena cliccato (e il suo bottone), non tutti
	# quelli pendenti: se ci sono più argomenti disponibili insieme (es.
	# lavoro E famiglia dopo gli scatoloni), gli altri devono restare
	# cliccabili senza dover chiudere e riaprire la conversazione.
	rimuovi_bottone_topic(topic_id)

# Distrugge tutti i bottoni dinamici tranne quello di uscita (usato quando il
# menu si chiude o si riapre da zero, non più ad ogni singolo click)
func pulisci_bottoni() -> void:
	for bottone in $Panel/OptionsContainer.get_children():
		# Distruggo il bottone SOLO se NON è il tasto Esci
		if bottone.name != "BTNEsci":
			bottone.queue_free()

	argomenti_attivi.clear()

# Distrugge SOLO il bottone del topic indicato, lasciando intatti gli altri
# eventuali bottoni pendenti (es. cliccando "lavoro" non deve sparire anche
# "famiglia" se erano proposti insieme)
func rimuovi_bottone_topic(topic_id: String) -> void:
	topic_pendenti.erase(topic_id)
	argomenti_attivi.erase(topic_id)
	for bottone in $Panel/OptionsContainer.get_children():
		if bottone.name != "BTNEsci" and bottone.get_meta("topic_id", "") == topic_id:
			bottone.queue_free()


# ==========================================
# REGOLE DI SBLOCCO
# ==========================================

# Chiamata da scripts/vesna.gd quando arriva una battuta da Jason: ripulisce
# SUBITO eventuali tag [TOPIC:...] (possono essere più di uno) creando i
# bottoni corrispondenti, e mostra solo il testo già pulito. Prima il testo
# grezzo (col tag ancora dentro) veniva scritto direttamente su BobText, e
# solo _process() lo ripuliva un fotogramma dopo: per quell'unico fotogramma
# si vedeva lampeggiare il tag grezzo (bug segnalato dall'utente: "si vede
# spuntare un'altra scritta per un microsecondo"). Così il tag non arriva mai
# a schermo, nemmeno per un fotogramma.
func ricevi_testo(testo: String) -> void:
	var pulito := testo

	# Fase 2: appena vediamo [TRATTATIVA] (o, per sicurezza, un [FINE:...]
	# arrivato senza che l'avessimo visto - caso di emergenza in cui le parti
	# non si sono mai registrate, vedi gnp_host.asl) deviamo TUTTO verso il
	# log scorrevole e usciamo subito: bottoni e topic del riquadro normale
	# non hanno più senso durante una negoziazione automatica.
	if _negoziazione_attiva or TAG_INIZIO_TRATTATIVA in pulito or "[FINE:" in pulito:
		_gestisci_narrazione_trattativa(pulito)
		return

	# Durante il processo il riquadro non può restare chiuso: se una battuta
	# arriva mentre è nascosto lo riapro, altrimenti il resto del dibattimento
	# andrebbe perso senza modo di recuperarlo.
	if modo_processo and not visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_tree().paused = true
		visible = true

	# In aula ogni battuta del giudice SOSTITUISCE le opzioni precedenti: le
	# risposte a una domanda non devono restare cliccabili quando è già stata
	# posta la successiva. Senza questo, i bottoni delle tre domande si
	# mescolavano e si potevano cumulare più risposte (la credibilità arrivava
	# a 4 su un massimo di 3). Fuori dal processo resta invece il
	# comportamento normale, dove più argomenti possono coesistere.
	if modo_processo:
		topic_pendenti.clear()
		pulisci_bottoni()

	# Tag [IO]: la battuta è pronunciata dal giocatore, non dall'NPC. Va tolto
	# dal testo e tradotto in un colore diverso.
	var del_giocatore := false
	while true:
		var pos = pulito.to_lower().find("[io]")
		if pos == -1:
			break
		del_giocatore = true
		pulito = pulito.substr(0, pos) + pulito.substr(pos + 4)
	_imposta_colore_battuta(del_giocatore)
	pulito = pulito.strip_edges()

	var minuscolo := pulito.to_lower()
	while "[topic:" in minuscolo:
		var inizio = minuscolo.find("[topic:")
		var fine = minuscolo.find("]", inizio)
		if fine == -1:
			break
		var topic_id = pulito.substr(inizio + 7, fine - (inizio + 7)).strip_edges().to_lower()
		if not topic_id in topic_pendenti:
			topic_pendenti.append(topic_id)
		mostra_bottone_topic(topic_id)
		var pezzo = pulito.substr(inizio, (fine - inizio) + 1)
		pulito = pulito.replace(pezzo, "")
		minuscolo = pulito.to_lower()
	$Panel/BobText.text = pulito

# Fase 2 dell'Atto 3: instrada la narrazione della trattativa verso il log
# scorrevole (NegotiationChat) invece che verso questo riquadro. Chiamata da
# ricevi_testo() appena vede [TRATTATIVA] o [FINE:tono] (vedi sopra).
func _gestisci_narrazione_trattativa(testo: String) -> void:
	var pulito := testo

	if TAG_INIZIO_TRATTATIVA in pulito:
		pulito = pulito.replace(TAG_INIZIO_TRATTATIVA, "")
		_negoziazione_attiva = true
		self.visible = false
		NegotiationChat.avvia()

	# [FINE:tono] arriva sull'ultima battuta: tono è vittoria/parziale/sconfitta,
	# scelto da giudice.asl in base alla fascia dell'esito.
	var tono := ""
	var inizio_tag = pulito.find("[FINE:")
	if inizio_tag != -1:
		var fine_tag = pulito.find("]", inizio_tag)
		if fine_tag != -1:
			tono = pulito.substr(inizio_tag + 6, fine_tag - (inizio_tag + 6))
			pulito = pulito.substr(0, inizio_tag) + pulito.substr(fine_tag + 1)

	pulito = pulito.strip_edges()
	if pulito != "":
		NegotiationChat.aggiungi(pulito)

	if tono != "":
		_negoziazione_attiva = false
		NegotiationChat.concludi(tono)

func _process(_delta: float) -> void:
	var testo_attuale = $Panel/BobText.text
	var testo_minuscolo = testo_attuale.to_lower()
	
	# Cerco il tag tutto in minuscolo
	if "[topic:" in testo_minuscolo:
		
		var inizio = testo_minuscolo.find("[topic:")
		var fine = testo_minuscolo.find("]", inizio)
		
		if fine != -1:
			# 1. Estraggo la parola (es: "cibo")
			var topic_id = testo_attuale.substr(inizio + 7, fine - (inizio + 7))
			
			# Tolgo eventuali spazi vuoti e forza in minuscolo
			topic_id = topic_id.strip_edges().to_lower()
			
			# Debug
			print(">>> MAGIA DEL TAG! Trovato ID: '", topic_id, "'")
			# NSalvo il topic nella memoria se non c'è già
			if not topic_id in topic_pendenti:
				topic_pendenti.append(topic_id)
			# Creo il bottone
			mostra_bottone_topic(topic_id)
			
			# Cancello fisicamente il blocco dal testo visibile
			var pezzo_da_cancellare = testo_attuale.substr(inizio, (fine - inizio) + 1)
			$Panel/BobText.text = testo_attuale.replace(pezzo_da_cancellare, "")


# ==========================================
# USCITA DAL MENU
# ==========================================

func _on_btn_esci_pressed() -> void:
	print("Chiudo il menu e torno al gioco!")
	self.visible = false 
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_tree().paused = false
	# Svuotiamo la memoria della porta, così se ci torni riparte da zero
	topic_pendenti.clear()
	pulisci_bottoni()
	# Resetta la scritta per la volta successiva
	_imposta_colore_battuta(false)
	$Panel/BobText.text = "Ciao, come posso aiutarti?"
	var scritta = get_tree().root.find_child("Label3D2", true, false)
	if scritta != null:
		scritta.visible = true
