extends CharacterBody3D

# Velocità di camminata. Era una costante condivisa: ora è esportata così un
# singolo agente può andare più piano senza toccare tutti gli altri (Finn
# cammina avanti e indietro nervosamente, vedi finn.asl). Chi non la
# sovrascrive nella scena resta a 10.0 esattamente come prima.
@export var SPEED: float = 10.0

# Destinazioni per cui questo agente usa la velocità normale (10.0) invece
# della propria SPEED ridotta. Serve a Finn: cammina piano avanti e indietro
# tra finn_passo_a/b, ma quando il giocatore lo convince a spostarsi sul
# marciapiede (finn_sicuro) non ha più motivo di andarci con lo stesso passo
# nervoso. Elenco di nomi di target (quelli passati a vesna.walk/!go_to), non
# di agenti: lasciato generico e vuoto di default così non serve toccare
# nessun altro personaggio per usarlo in futuro.
@export var velocita_normale_per: Array[String] = []
const ACCELERATION = 8.0
const JUMP_VELOCITY = 4.5

@export var PORT : int
var tcp_server := TCPServer.new()
var ws := WebSocketPeer.new()

var regions_dict : Dictionary = {}
var current_region = ""

var end_communication = true

var target_movement : String = "empty"

@onready var navigator : NavigationAgent3D = $NavigationAgent3D
@onready var jump_anim = $Body/Jump
@onready var idle_anim = $Body/Idle
@onready var run_anim = $Body/Run

@export var desired_separation: float = 3.0  # distanza minima desiderata
@export var separation_weight: float = 5.0   # peso della forza di separazione

func _ready() -> void:
	if tcp_server.listen( PORT ) != OK:
		push_error( "Unable to start the srver" )
		set_process( false )
	# RICERCA DINAMICA: Cerca "Regions" in tutto l'albero
	var regions_node = get_tree().root.find_child("Regions", true, false)
	if regions_node != null:
		for region in regions_node.get_children():
			region.connect( "body_entered", func( body) : _on_area_body_entered( region.name, body ) )
			
	# RICERCA DINAMICA: Cerca "Doors" in tutto l'albero
	var doors_node = get_tree().root.find_child("Doors", true, false)
	if doors_node != null:
		for door in doors_node.get_children():
			door.get_node("Area3D").connect( "body_entered", func( body) : _on_area_body_entered( door.name, body ) )
	play_idle()
	
func _process(delta: float) -> void:
	while tcp_server.is_connection_available():
		var conn : StreamPeerTCP = tcp_server.take_connection()
		assert( conn != null )
		ws.accept_stream( conn )
		
	ws.poll()
	
	if ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		while ws.get_available_packet_count():
			var msg : String = ws.get_packet().get_string_from_ascii()
			print( "Received msg ", msg )
			var intention : Dictionary = JSON.parse_string( msg )
			manage( intention )

func _physics_process(delta: float) -> void:
	# Gestisce la pausa se mi trovo nel menu
	if get_tree().paused:
		return
	
	# Debug
	#print("Posizione di Bob: ", global_position)
	
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
		
	#var target_direction: Vector3 = (navigator.get_next_path_position() - global_transform.origin).normalized()
	
	if navigator.is_target_reached() or navigator.is_navigation_finished():
		play_idle()
		velocity.x = 0
		velocity.z = 0
		if not end_communication:
			signal_end_movement()
			
	elif not navigator.is_navigation_finished():
		play_run()
		var direction = ( navigator.get_next_path_position() - global_position ).normalized()
		var avoidance_force = get_avoidance_force()
		var final_direction = ( direction + avoidance_force ).normalized()
		rotation.y = atan2( -final_direction.z, final_direction.x )
		
		# ---> IL FIX DELLA GRAVITA' <---
		var vecchia_y = velocity.y # 1. Salviamo la gravità prima del lerp
		velocity = velocity.lerp( final_direction * velocita_attuale(), ACCELERATION * delta )
		velocity.y = vecchia_y     # 2. Rimettiamo la gravità al suo posto!
		# -------------------------------
	move_and_slide()
	
func _on_area_body_entered( region_name, body ):
	if ( body.name == self.name ):
		print( "Agent ", self.name, " entered region ", region_name )
		if ( region_name == target_movement ):
			signal_end_movement()
			navigator.set_target_position( global_position )
	
func _exit_tree() -> void:
	ws.close()
	tcp_server.stop()
	
func get_avoidance_force() -> Vector3:
	var force: Vector3 = Vector3.ZERO
	# Supponiamo che tutti i CharacterBody3D siano nel gruppo "players"
	for other in get_tree().get_nodes_in_group("agents"):
		if other == self:
			continue
		var diff = global_transform.origin - other.global_transform.origin
		var distance = diff.length()
		if distance < desired_separation and distance > 0:
			# La forza cresce quando la distanza diminuisce
			force += diff.normalized() / distance
	return force * separation_weight

func manage( intention : Dictionary ) -> void:
	var sender : String = intention[ 'sender' ]
	var receiver : String = intention[ 'receiver' ]
	var type : String = intention[ 'type' ]
	var data : Dictionary = intention[ 'data' ]
	if type == 'walk':
		if data[ 'type' ] == 'goto':
			var target : String = data[ 'target' ]
			if data.has( 'id' ):
				var id : int = data[ 'id' ]
				walk( target, id )
			else:
				walk( target, -1 )
	elif type == 'interact':
		if data[ 'type' ] == 'use':
			var art_name : String = data[ 'art_name' ]
			use( art_name )
		elif data[ 'type' ] == 'grab':
			var art_name : String = data[ 'art_name' ]
			grab( art_name )
		elif data[ 'type' ] == 'free':
			var art_name : String = data[ 'art_name' ]
			free_art( art_name )
		elif data[ 'type' ] == 'release':
			var art_name : String = data[ 'art_name' ]
			release( art_name )
	# Mancano gli elif per jump e rotate? 
	# Logica per il dialogo
	elif type == 'dialogue':
		if data.has("text"):
			var risposta_di_bob = data["text"]
			# Cerca la tua interfaccia visiva
			var menu = get_tree().root.find_child("DialogInterface", true, false)
			# L'interfaccia di dialogo è UNA SOLA, condivisa da tutti gli
			# agenti: senza questo filtro qualunque battuta in arrivo ci
			# finisce dentro, anche se il giocatore nel frattempo si è messo
			# a parlare con un altro personaggio. Con le battute immediate
			# non si notava; con la telefonata di Chloe (~9s di pause di
			# lettura) sì, e i suoi bottoni comparivano sul Sig. Jefferson.
			# Se non è il mio turno la battuta va semplicemente scartata.
			if menu != null and menu.agente_attivo != name:
				menu = null
			if menu != null:
				# ricevi_testo() ripulisce subito eventuali tag [TOPIC:...] e
				# crea i bottoni PRIMA di mostrare il testo, così il tag
				# grezzo non lampeggia mai a schermo (era testo_ui.text =
				# risposta_di_bob diretto, con la pulizia solo un fotogramma
				# dopo in menu_dialog.gd)
				menu.ricevi_testo(risposta_di_bob)
	# Notifica temporanea (es. "+1 Fiducia"), separata dal dialogo: usa un
	# nodo diverso (FiduciaNotifier), non tocca DialogInterface/menu_dialog.gd
	elif type == 'notify':
		if data.has("text"):
			var notifier = get_tree().root.find_child("FiduciaNotifier", true, false)
			if notifier != null:
				notifier.mostra(data["text"])
	# Sblocco di una prova nell'inventario: nodo separato "Inventario", non
	# tocca dialogo ne' notifiche di fiducia
	elif type == 'prova_raccolta':
		if data.has("id"):
			var inventario = get_tree().root.find_child("Inventario", true, false)
			if inventario != null:
				inventario.sblocca(data["id"])


func walk( target, id ):
	# Cerca il target direttamente in tutto il mondo
	var target_region = get_tree().root.find_child(target, true, false)
	
	if target_region != null:
		navigator.set_target_position( target_region.global_position )
	else:
		print("ERRORE NAVIGAZIONE: Non trovo il target chiamato ", target)
	target_movement = target
	play_run()
	end_communication = false

func get_obj_from_group( art_name : String, group_name : String ):
	var group_objs = get_tree().get_nodes_in_group( group_name )
	for group_obj in group_objs:
		if art_name == group_obj.name:
			return group_obj
	return null
	
func use( art_name: String ):
	print( "I want to use " + art_name )
	# Se l'oggetto da usare è la radio, cerco il suo sensore e lo spengo
	if art_name == "radio":
		# find_child cerca il nodo in tutta la scena 
		var radio_node = get_tree().get_root().find_child("radio_sensor", true, false)
		if radio_node:
			radio_node.disattiva_radio()
	
func grab( art_name: String ):
	var art = get_obj_from_group( art_name, "GrabbableArtifact")
	if art == null:
		print( "Object not found!")
		return
	print( "I take the hand" )
	var right_hand = get_node_or_null( "Body/Root/Skeleton3D/RightHand" )
	if ( right_hand == null ):
		print( "Oh no I do not have a hand!")
	#art.global_position = Vector3.ZERO
	art.reparent( right_hand )
	print( "reparent done" )
	#art.global_transform.origin = right_hand.position
	art.transform.origin = Vector3.ZERO
	print( "I want to grab " + art_name )

func free_art( art_name : String ):
	print( "I free " + art_name )
	
func release( art_name : String ):
	var release_points = get_tree().get_nodes_in_group( "ReleasePoint" )
	var nearest_release
	var nearest_dist = 1000
	for release_point in release_points:
		var cur_dist = release_point.global_position.distance_to( global_position )
		if  cur_dist < nearest_dist:
			nearest_release = release_point
			nearest_dist = cur_dist
	var art = get_obj_from_group( art_name, "GrabbableArtifact" )
	art.reparent( nearest_release )
	art.transform.origin = Vector3.ZERO
	print( "I release " + art_name )
	
func signal_end_movement( ) -> void:
	target_movement = "empty"
	var log : Dictionary = {}
	log[ 'sender' ] = 'body'
	log[ 'receiver' ] = 'vesna'
	log[ 'type' ] = 'signal'
	var msg : Dictionary = {}
	msg[ 'type' ] = 'movement'
	msg[ 'status' ] = 'completed'
	msg[ 'reason' ] = 'destination_reached'
	log[ 'data' ] = msg
	ws.send_text( JSON.stringify( log ) )
	end_communication = true

func update_region( new_region : String ) -> void:
	current_region = new_region
	if current_region not in regions_dict:
		regions_dict[ current_region ] = []
		
func play_idle() -> void:
	if run_anim and run_anim.is_playing():
		run_anim.stop()
	idle_anim.play( "Root|Idle" )

func play_run() -> void:
	if idle_anim.is_playing():
		idle_anim.stop()
	# L'animazione di corsa è tarata su SPEED = 10: a velocità ridotte le gambe
	# gireranno molto più veloci dello spostamento reale (effetto "moonwalk").
	# La rallento in proporzione, con un minimo per non farla sembrare al
	# rallentatore. A SPEED = 10 il fattore è 1.0, quindi nulla cambia per gli
	# agenti esistenti. Usa velocita_attuale() e non SPEED direttamente, così
	# l'animazione torna al passo normale insieme al movimento vero quando la
	# destinazione è tra quelle in velocita_normale_per.
	run_anim.speed_scale = clampf( velocita_attuale() / 10.0, 0.3, 1.0 )
	run_anim.play( "Root|Run" )

# Velocità da usare per QUESTO movimento: normale se la destinazione attuale
# è elencata in velocita_normale_per, altrimenti la SPEED propria dell'agente.
func velocita_attuale() -> float:
	if target_movement in velocita_normale_per:
		return 10.0
	return SPEED
