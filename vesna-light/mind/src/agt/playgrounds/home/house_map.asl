// Mappa della casa della scena 

// Elenco delle stanze della casa
map_ntpp( salotto, casa ).                  // Il salotto si ttova all'interno della mia casa
map_ntpp( cucina, casa ).
map_ntpp( saladapranzo, casa ).
map_ntpp( corridoio, casa ).
map_ntpp( camera, casa ).
map_ntpp( ripostiglio, casa ).
map_ntpp( bagno, casa ).
map_ntpp( ufficio, casa ).

// Oggetti ATTIVI del salotto - uso gli stessi nomi dei nodi di Godot (solo quelli che hanno un Marker)
map_ntpp( armchair2, salotto ).

// Oggetti della cucina - sempre solo quelli che hanno il Marker corrispondente
map_ntpp( kitchentable_A_large_decorated2, cucina ).

// Sala da pranzo
map_ntpp( chair_A_wood5, saladapranzo ).
map_ntpp( passaggio_corridoio, saladapranzo).
map_ntpp( tavolo, saladapranzo ).

// Corridoio - da modificare se ne voglio uno
// map_ntpp( nome_marker_mobiletto, corridoio ).

// Ripostiglio - da modificare
map_ntpp( cardboard_box_open, ripostiglio ).
map_ntpp( radio, ripostiglio ).

// Bagno - da modificare
map_ntpp( bathroom_sink, bagno ).

// Camera - da modificare
map_ntpp( bed_double_B2, camera ).

// Ufficio - da modificare
map_ntpp( chair_desk, ufficio ).

// --- COLLEGAMENTI (Porte e Varchi) ---
// Regola: La Stanza A è connessa alla Porta X. La Porta X è connessa alla Stanza B.

// Connessione Salotto <-> Cucina
map_po( salotto, passaggio_cucina ).
map_po( passaggio_cucina, cucina ).

// Connessione Cucina <-> Sala da pranzo
map_po( cucina, passaggio_saladapranzo ).
map_po( passaggio_saladapranzo, saladapranzo ).

// Connessione Sala da pranzo <-> Corridoio
map_po( saladapranzo, passaggio_corridoio ).
map_po( passaggio_corridoio, corridoio ).

// Connessioni dal Corridoio verso le stanze superiori
// 1. Verso il Ripostiglio (R)
map_po( corridoio, passaggio_ripostiglio ).
map_po( passaggio_ripostiglio, ripostiglio ).

// 2. Verso il Bagno (B)
map_po( corridoio, passaggio_bagno ).
map_po( passaggio_bagno, bagno ).

// 3. Verso la Camera (Cl)
map_po( corridoio, passaggio_camera ).
map_po( passaggio_camera, camera ).

// Connessione Camera <-> Ufficio (U)
map_po( camera, passaggio_ufficio ).
map_po( passaggio_ufficio, ufficio ).