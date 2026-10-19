extends StaticBody3D

# Distanza entro la quale Bob attiva il blocco. 
# Regolala in modo che scatti quando Bob è al suo posto di guardia.
const DISTANZA_GUARDIA = 3.0 

# Mi devo assicurare che il nome qui sotto sia IDENTICO a quello nell'albero di sinistra
@onready var collisione = $CollisionShape3D 

func _process(_delta):
	var bob = get_tree().get_root().find_child("Bob", true, false)
	
	if bob:
		var distanza = global_position.distance_to(bob.global_position)
		
		# Se Bob è vicino al muro E quasi fermo, il muro è ATTIVO (non passi)
		if distanza < DISTANZA_GUARDIA and bob.velocity.length() < 0.1:
			collisione.disabled = false
		# Se Bob è lontano (es. va a mangiare) o sta camminando, il muro è DISATTIVATO -> passii
		else:
			collisione.disabled = true
