extends Node3D

const PORT = 8091
var tcp_server := TCPServer.new()
var ws := WebSocketPeer.new()

func _ready() -> void:
	print("--- RADIO SERVER ATTIVO (PORTA 8091) ---")
	if tcp_server.listen(PORT) != OK:
		print("ERRORE: Impossibile avviare il server sulla porta 8091")
		set_process(false)

func _process(_delta: float) -> void:
	while tcp_server.is_connection_available():
		var conn = tcp_server.take_connection()
		ws.accept_stream(conn)
		print("Java si è connesso alla porta 8091")

	ws.poll()
	
	var state = ws.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		while ws.get_available_packet_count() > 0:
			var msg = ws.get_packet().get_string_from_utf8()
			print("RICEVUTO SU 8091: ", msg) 
			var json = JSON.new()
			if json.parse(msg) == OK:
				manage(json.get_data())

func manage(intention: Dictionary) -> void:
	# Verificho che il messaggio sia del tipo corretto
	if intention.get("type") == "interaction":
		var data = intention.get("data", {})
		if data.get("type") == "turn_off_radio":
			print("AZIONE: Ricevuto comando turn_off_radio. Procedo...")
			spegni_fisicamente()

func spegni_fisicamente() -> void:
	# Cercho il nodo dello script della radio (radio_sensor)
	# Nlla scena il nodo si deve chiamare esattamente RadioSensor
	var radio_node = get_tree().get_root().find_child("RadioSensor", true, false)
	
	if radio_node:
		if radio_node.has_method("disattiva_radio"):
			radio_node.disattiva_radio()
			print("SUCCESSO: La radio è stata spenta fisicamente!")
		else:
			print("ERRORE: Il nodo radio_sensor non ha la funzione disattiva_radio()")
	else:
		print("ERRORE CRITICO: Non trovo il nodo 'radio_sensor' nell'albero della scena!")
