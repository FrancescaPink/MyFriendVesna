{ include( "vesna.asl" ) }
{ include( "playgrounds/home/house_map.asl" ) }

// ============================================================
//  ATTO 1 - LA CASA: meccanica della fiducia
//  fiducia(N) sale con 5 azioni oneste (croissant, casa_nuova, scatoloni, lavoro, famiglia). A fiducia(5) 
//  Bob si confida e sblocca il topic "confessione" (vedi vesna-light/docs/story.md). Se cambia il numero di
//  azioni disponibili, la soglia qui sotto va aggiornata di conseguenza (altrimenti la confessione rischia di 
//  non essere più raggiungibile).
//  Ordine dei topic: prima colazione (cibo) -> poi casa_nuova -> poi, SOLO dopo aver fatto
//  gli scatoloni nel ripostiglio, si sbloccano anche lavoro e famiglia.
// ============================================================

+!guadagna_fiducia(Motivo)
    :   not fiducia_ottenuta(Motivo) & fiducia(N)
    <-  +fiducia_ottenuta(Motivo);
        NewN = N + 1;
        -fiducia(N);
        +fiducia(NewN);
        .print("[FIDUCIA] +1 (", Motivo, ") -> ", NewN);
        vesna.via.notify("+1 Fiducia");
        if ( NewN == 1 ) {
            !bob_si_scioglie_un_po;
        } elif ( NewN == 3 ) {
            !bob_si_scioglie_di_piu;
        } elif ( NewN == 5 ) {
            !sblocca_confessione;
        }.

+!guadagna_fiducia(_)
    <-  true.

+!perde_fiducia(Motivo)
    :   fiducia(N) & N > 0
    <-  NewN = N - 1;
        -fiducia(N);
        +fiducia(NewN);
        .print("[FIDUCIA] -1 (", Motivo, ") -> ", NewN);
        vesna.via.notify("-1 Fiducia").

+!perde_fiducia(_)
    <-  .print("[FIDUCIA] già a zero, nessun ulteriore calo.").

// Piccoli segnali che la fiducia sta salendo, PRIMA della confessione vera e
// propria: Bob parte diffidente e si scioglie gradualmente, non di scatto.
// Tag [TOPIC:_mood] fittizio: non esiste in topic.json quindi non crea
// nessun bottone, serve solo a marcare "Bob ha appena detto qualcosa" così
// menu_dialog.gd non sovrascrive la battuta col saluto generico se il
// giocatore apre il menu più tardi (stesso bug del messaggio degli scatoloni - RISOLTO).
+!bob_si_scioglie_un_po
    <-  .wait(7000); // tempo per leggere la battuta precedente prima di questa
        vesna.via.speak("Forse... forse non sei come gli altri avvocati che ho conosciuto. Grazie mille.[TOPIC:_mood]").

+!bob_si_scioglie_di_piu
    <-  .wait(7000); // tempo per leggere la battuta precedente prima di questa
        vesna.via.speak("Sai, iniziare a sentirmi meno solo in questa storia mi fa gia' stare meglio.[TOPIC:_mood]").

+!sblocca_confessione
    <-  .wait(7000); // tempo per leggere la battuta precedente prima di questa
        vesna.via.speak("Devo dirti una cosa... [TOPIC:confessione]").

// Il giocatore è stato sorpreso a frugare nel PC mentre Bob era presente
// (segnale inviato da pc_interaction.gd quando "Bob ti sta guardando").
// La battuta del rimprovero la mostra subito Godot per far scendere la fiducia
+tentativo_hacking(scoperto, _)
    <-  !perde_fiducia(hacking).

// Percorso "low morality": il giocatore ha frugato nel PC INDISTURBATO (Bob
// distratto dalla radio) e ha trovato l'indizio su Finn da solo. Bob non
// si accorge di nulla: nessuna battuta, nessun effetto sulla fiducia. Resta
// solo una credenza silenziosa, per eventuali usi futuri (Atto 2/3).
+furto_riuscito(_, _)
    <-  +scoperta_furtiva.

// Gli user message vanno usati in corrispondenza di bottoni nel gioco
// Servono 2 parametri -> Uso l'underscore perchè significa che l'informazione che arriva è irrilevante e non serve salvarla

// Primo incontro in assoluto col giocatore: Bob riconosce che è l'avvocato
// (il giocatore lo sa già dalla telefonata/fascicolo mostrati all'avvio del gioco)
// Tag [TOPIC:_mood] fittizio (non è in topic.json, nessun bottone creato)
+user_message(comeva, _) : not presentato
    <-  +presentato;
        vesna.via.speak("Ah... e' lei l'avvocato che mi hanno mandato? Sono... sono nei guai, vero? Non so nemmeno da dove cominciare.[TOPIC:_mood]").

// Se ha già raggiunto la soglia di fiducia e non si è ancora confidato, ogni
// saluto lo fa tornare sull'argomento (il bottone "Come va?" è sempre presente,
// a differenza di "confessione" che sparisce se chiudi il menu senza cliccarlo)
+user_message(comeva, _) : fiducia(N) & N >= 5 & not confessata
    <-  vesna.via.speak("Devo dirti una cosa... [TOPIC:confessione]").

// Il "come va" con la richiesta di cibo resta solo un aggancio narrativo verso
// il croissant: non vale punti fiducia da solo. Il punto vero si guadagna solo portando
// davvero la colazione. Prima della colazione mostro SOLO il topic cibo: gli smalltalk arrivano
// solo dopo, altrimenti l'area dei bottoni si riempie troppo (bottoni insieme escono dallo schermo).
+user_message(comeva, _) : not ha_mangiato
    <-  .print("Ho ricevuto il messaggio! Ora rispondo a Godot...");
        vesna.via.speak("Tutto bene! Ma ora ho una gran fame, hai qualcosa da mangiare?[TOPIC:cibo]").

// Dopo colazione ma PRIMA degli scatoloni: solo casa_nuova, e SOLO se Bob è
// in ufficio (dove finisce dopo aver mangiato e essere andato a fare la
// guardia al PC) — non subito in sala da pranzo mentre sta ancora mangiando
// o camminando verso l'ufficio, dove chiedere degli scatoloni non ha senso.
// Lavoro e famiglia arrivano solo più avanti (vedi scatoloni_completati
// sotto), altrimenti sono troppi bottoni insieme fin da subito.
+user_message(comeva, _) : ha_mangiato & not scatoloni_completati & .my_name(Me) & ntpp(Me, ufficio)
    <-  vesna.via.speak("Sto alla grande! Quel croissant era proprio quello che ci voleva per lavorare bene al PC.[TOPIC:casa_nuova]").

// Stesso caso ma Bob non è (ancora) in ufficio: stessa battuta, nessun topic
+user_message(comeva, _) : ha_mangiato & not scatoloni_completati
    <-  vesna.via.speak("Sto alla grande! Quel croissant era proprio quello che ci voleva per lavorare bene al PC.").

// Dopo gli scatoloni, in ufficio: ri-offro anche lavoro e famiglia se il
// giocatore non li ha ancora chiesti (es. ha chiuso il dialogo prima di
// cliccarli quando sono comparsi subito dopo il "grazie" per gli scatoloni).
// casa_nuova resta comunque legato all'ufficio, come sopra.
+user_message(comeva, _) : ha_mangiato & scatoloni_completati & .my_name(Me) & ntpp(Me, ufficio)
    <-  vesna.via.speak("Sto alla grande! Quel croissant era proprio quello che ci voleva per lavorare bene al PC.[TOPIC:casa_nuova][TOPIC:lavoro][TOPIC:famiglia]").

// Stesso caso ma Bob non è in ufficio: lavoro/famiglia restano disponibili
// (non sono legati alla posizione), solo casa_nuova resta escluso qui
+user_message(comeva, _) : ha_mangiato & scatoloni_completati
    <-  vesna.via.speak("Sto alla grande! Quel croissant era proprio quello che ci voleva per lavorare bene al PC.[TOPIC:lavoro][TOPIC:famiglia]").

+user_message(cibo, _)
    <-  vesna.via.speak("Oh si, magari! Un croissant sarebbe il massimo!").

+user_message(ringraziamento, _)
    <-  vesna.via.speak("Ora che ho la pancia piena sono molto piu' felice, mi metto subito al lavoro!").

// Smalltalk: chiacchiere non legate al caso, per far conoscere Bob come
// persona e non solo come "cliente accusato". Ognuna vale un punto fiducia
// una sola volta; se richieste di nuovo, Bob ripete solo brevemente.
+user_message(casa_nuova, _) : not casa_nuova_discussa
    <-  +casa_nuova_discussa;
        vesna.via.speak("Sto ancora sistemandomi, a dire il vero. Non ho ancora avuto la testa per disfare gli scatoloni.");
        !guadagna_fiducia(casa_nuova).

+user_message(casa_nuova, _) : casa_nuova_discussa
    <-  vesna.via.speak("Come ti dicevo, sto ancora sistemando gli scatoloni.").

+user_message(lavoro, _) : not lavoro_discusso
    <-  +lavoro_discusso;
        vesna.via.speak("Ero tecnico IT alla NovaTech, finche' non mi hanno accusato di aver violato i server della mia stessa azienda.");
        !guadagna_fiducia(lavoro).

+user_message(lavoro, _) : lavoro_discusso
    <-  vesna.via.speak("Lavoravo alla NovaTech, te l'ho gia' detto.").

+user_message(famiglia, _) : not famiglia_discussa
    <-  +famiglia_discussa;
        vesna.via.speak("Qui non conosco quasi nessuno. L'unico che sentivo ogni tanto era Finn, un ex collega... ma e' una storia complicata.");
        !guadagna_fiducia(famiglia).

+user_message(famiglia, _) : famiglia_discussa
    <-  vesna.via.speak("Come dicevo, l'unico che sentivo qui era Finn.").

+user_message(confessione, _)
    <-  +confessata;
        vesna.via.speak("Mi sono svegliato col laptop gia' acceso, ma non l'avevo toccato io. Le uniche chiavi di scorta ce le ha Finn, il mio ex collega.[TOPIC:perche_chiavi]");
        vesna.via.prova("confessione").

// Approfondimento sbloccato dopo la confessione: recupera il dettaglio delle
// chiavi (perché Finn le aveva) senza appesantire la battuta principale,
// che deve restare corta per stare nel riquadro senza sovrapporsi ai bottoni.
// Piccolo accenno al passo successivo in coda (richiesta dell'utente: solo
// un rimando diegetico nei dialoghi, niente bottoni o obiettivi nuovi).
+user_message(perche_chiavi, _)
    <-  vesna.via.speak("Gliele avevo date per innaffiare le piante durante il trasloco. Non pensavo sarebbe servito a nient'altro. Magari qualcuno qui in citta' lo conosce.").

// Bob resta fermo in salotto finché il giocatore non gli parla la prima
// volta: ".wait(presentato)" sospende QUESTA intenzione (non ne crea una
// parallela) finché la credenza "presentato" non diventa vera — è aggiunta
// da +user_message(comeva,_) : not presentato più sopra, al primo "Come va?".
+!start
    :   .my_name( Me )
    <-  +ntpp( Me, salotto );
        +at( Me, salotto ); // Aggiungiamo anche questo per sicurezza!
        +fiducia(0);
        .print("Ciao, mi chiamo Bob! Ho appena traslocato e sono nel salotto.");
        .wait(presentato);
        .wait(4000); // tempo per leggere la battuta e chiudere il dialogo
        !inizia_movimento.

// Vari test di movimento svolti con stampe
+!inizia_movimento
    <-  vesna.rotate(left);
        .wait( 2000 );
        vesna.rotate(backward);
        .wait( 2000 );
        vesna.jump;

        // TEST 1: Movimento nella stessa stanza
        .print("Vado a sedermi sulla poltrona...");
        !go_to( armchair2 );

        .wait( 3000 );

        // TEST 2: Movimento in un'altra stanza
        .print("Ora vado a esplorare la cucina...");
        !go_to( kitchentable_A_large_decorated2 );
        .wait( 3000 );
        .print("Ora vado in sala da pranzo...");
        !go_to( chair_A_wood5 );
        .print("Perfetto!");
        .wait( 3000 );
        .print("Vado in camera");
        !go_to( bed_double_B2 );
        .wait( 3000 ); // Ora aspetterà davvero 10 secondi QUI
        .print("Vado in ufficio...");
        !go_to( chair_desk );
        .wait( 3000 );
        .print("Vado in bagno...");
        !go_to( bathroom_sink );
        .wait( 3000 );
        .print("Vado nel ripostiglio...");
        !go_to( cardboard_box_open );
        .wait( 3000 );

        //TEST 3: Reazione all'oggetto
        .print("Sto andando a fare la guardia alla porta...");
        !go_to( passaggio_corridoio );
        .print("Rimango qui finché qualcuno non mi porta la colazione!").

// EVENTO 1 -> IL GIOCATORE PORTA IL CROISSANT (Reagisce a QUALSIASI oggetto messo su tavolo/sensore)
// Jason legge i piani dall'alto verso il basso. Se l'oggetto è il croissant, esegue questo piano specifico.
+oggetto_appoggiato(croissant, Luogo)
    <-  +ha_mangiato;
        vesna.via.speak("Oh! Hai lasciato un croissant sul tavolo! Che gentile, grazie mille![TOPIC:ringraziamento]");
        !guadagna_fiducia(croissant);
        //+topic(ringraziamento, "Di nulla, mangia pure!");
        .print("Oh! Ho visto il croissant in ", Luogo, "! Vado a prenderlo!");      // Debug su console vesna
        !go_to( Luogo );
        .print("Mmm, buonissimo! Grazie per la colazione.");                        // Debug su console vesna
        .wait(10000);
        .print("Ora che ho la pancia piena, vado a lavorare al mio PC!");
        !proteggo_pc. // Questo sblocca la fase due!

// Se appoggio qualsiasi altro oggetto che non sia il croissant, esegue questo:
+oggetto_appoggiato(Oggetto, Luogo)
    <-  .print("Interessante! Ho notato che ", Oggetto, " è stato appoggiato su ", Luogo);
        .print("Vado subito verso: ", Luogo);
        !go_to( Luogo ).

// Il giocatore aiuta Bob a disfare gli scatoloni del trasloco nel ripostiglio
// (segnale da scatolone_sensor.gd). Il tag TOPIC è fondamentale: senza,
// topic_pendenti resta vuoto e menu_dialog.gd non ha modo di distinguere
// "Bob ha appena detto qualcosa" da "nessun evento in sospeso", quindi la
// prossima apertura del menu sovrascrive il messaggio col saluto generico
// (bug segnalato dall'utente: "non vedo nessun messaggio per gli scatoloni").
+scatolone_sistemato(_, _)
    <-  +scatoloni_completati;
        vesna.via.speak("Oh, grazie per avermi dato una mano con gli scatoloni! Non pensavo che ti saresti offerto...[TOPIC:scatoloni_grazie]");
        !guadagna_fiducia(scatoloni).

// Risposta al "Figurati, ci mancherebbe!": qui si sbloccano lavoro e
// famiglia, il momento giusto secondo il senso logico della conversazione
// (prima ti sei dato da fare per lui con gli scatoloni, ora si apre di più).
+user_message(scatoloni_grazie, _)
    <-  vesna.via.speak("Mi ha fatto piacere non dover disfare tutto da solo.[TOPIC:lavoro][TOPIC:famiglia]").

// EVENTO 2 -> L'AGENTE FA LA GUARDIA AL PC
+!proteggo_pc
    <-  !go_to( chair_desk ); // Bob va alla scrivania
        .print("Sono in posizione al PC. Nessuno potra' hackerarlo ora!").

// EVENTO 3 -> LA DISTRAZIONE DELLA RADIO
+rumore_rilevato( Fonte, Punto)
    <- .print("----------------------------------------");
       .print("ALLARME: Ho appena sentito un rumore!");
       .print("Oggetto: ", Fonte);
       .print("Posizione: ", Punto);
       .print("----------------------------------------");
       !go_to( Punto );
       lookupArtifact("radio", RadioId);
       turn_off [artifact_id(RadioId)];
       .print("Sono riuscito a spegnere la radio!");
       .wait(10000);
       .print("Falso allarme... Torno a sorvegliare il PC!");
       !proteggo_pc.
