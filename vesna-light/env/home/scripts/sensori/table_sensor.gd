extends Area3D

func _on_body_entered(body):
	# Controllo se l'oggetto che ha toccato il tavolo è interattivo
	if body.is_in_group("GrabbableArtifact"):
		print("Alert: Il giocatore ha servito: " + body.name + " sul tavolo!")
		var nome_oggetto = body.name.to_lower()
		var nome_luogo = get_parent().name.to_lower()
		
		var agents = get_tree().get_nodes_in_group("agents")
		if agents.size() > 0:
			var bob = agents[0]
			
			var log : Dictionary = {}
			log['sender'] = 'body'
			log['receiver'] = 'vesna'
			log['type'] = 'signal'
			
			# Crredenza: oggetto_appoggiato(Oggetto, Luogo)
			var msg : Dictionary = {}
			msg['type'] = 'oggetto_appoggiato' 		# Questo è il nome della regola
			msg['status'] = nome_oggetto   			# Diventerà il primo parametro (Oggetto)
			msg['reason'] = nome_luogo     			# Diventerà il secondo parametro (Luogo)
			log['data'] = msg
			
			print("Invio segnale ASL: oggetto_appoggiato(" + nome_oggetto + ", " + nome_luogo + ")")
			bob.ws.send_text(JSON.stringify(log))
