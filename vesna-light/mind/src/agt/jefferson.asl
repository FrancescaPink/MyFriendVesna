{ include( "vesna.asl" ) }
{ include( "playgrounds/city/city_map.asl" ) }

// ============================================================
//  ATTO 2 - LA CITTA': Sig. Jefferson, direttore di NovaTech.
//  Ha tagliato il budget sicurezza per risparmiare e vuole chiudere il caso
//  in fretta incolpando Bob. La sua sola presenza blocca la testimonianza
//  di Alex (vedi alex.asl): il giocatore deve convincerlo ad allontanarsi
//  per una pausa perché Alex parli liberamente (vedi docs/story.md, Atto 2).
// ============================================================

+!start
    :   .my_name( Me )
    <-  +ntpp( Me, citta );
        +prove_note(0);
        .print("Sono il Sig. Jefferson, direttore di NovaTech.").

// ------------------------------------------------------------
//  PROVA #5: LA CONTRADDIZIONE - vedi docs/story.md, Atto 2.
//
//  Le prove vivono in Godot (inventario.gd), non qui: a ogni sblocco
//  l'inventario manda a QUESTA mente prova_raccolta(<id>, ottenuta), col
//  formato dei sensori.
//
//  Nota sull'astrazione: non è che il Sig. Jefferson "spii" l'inventario del
//  giocatore. Queste credenze rappresentano ciò che l'avvocato può
//  concretamente mettergli davanti: finché non ha materiale in mano, non ha
//  modo di incalzarlo, e infatti l'argomento non compare proprio.
//
//  Il conteggio lo tiene lui, con lo stesso schema di fiducia(N) in bob.asl,
//  invece di usare .count sulle percezioni: quelle arrivano come messaggi con
//  una performativa non standard e non è garantito che restino nella base di
//  credenze, mentre l'EVENTO sappiamo che arriva (è lo stesso canale di
//  user_message, usato in tutto il gioco).
// ------------------------------------------------------------
+prova_raccolta(Id, _)
    <-  !conta_prova;
        !annota_prova(Id).

+!conta_prova : prove_note(N)
    <-  NewN = N + 1;
        -prove_note(N);
        +prove_note(NewN).

// Rete di sicurezza: se per qualsiasi motivo prove_note non fosse ancora
// inizializzata, il conteggio parte lo stesso invece di perdersi.
+!conta_prova : not prove_note(_)
    <-  +prove_note(1).

// La testimonianza di Alex è quella che lo inchioda davvero (è lei a sapere
// degli allarmi ignorati), quindi la segno a parte: serve come condizione
// necessaria, non basta il numero.
+!annota_prova(alex) : not testimonianza_alex
    <-  +testimonianza_alex.

+!annota_prova(_)
    <-  true.

// Condizione per poterlo incalzare: almeno 2 prove E la testimonianza di Alex
// fra queste. Scritta come regola per non ripeterla in ogni guardia.
puo_essere_incalzato :- prove_note(N) & N >= 2 & testimonianza_alex & not contraddetto.

// ------------------------------------------------------------
//  PETTEGOLEZZO TRA NPC (primo anello) - vedi docs/story.md, Atto 2.
//
//  Il suo PresenzaSensor gli segnala chiunque altro sia nel gruppo "agents"
//  entro 1.5: normalmente e' Alex, che gli sta accanto, ma quando va in
//  pausa al bar il marker jefferson_pausa dista 0.63 da Chloe, quindi la
//  rileva. Questo evento arrivava gia' oggi, semplicemente nessun piano lo
//  ascoltava.
//
//  Si sfoga solo se il giocatore gli ha gia' parlato (presentato): e' quello
//  che lo ha innervosito. Se non lo hai mai avvicinato, va al bar, beve il
//  caffe' e non succede nulla - la conseguenza e' causata da te.
//
//  Nota narrativa: NON parla di Finn, che non ha motivo di conoscere. Dice
//  solo che c'e' un avvocato che gira facendo domande. E' Chloe, che
//  conosce tutti, a far arrivare la voce a chi di dovere (vedi chloe.asl).
// ------------------------------------------------------------
+presenza(chloe, entered)
    :   presentato & not voce_sparsa
    <-  +voce_sparsa;
        .send( chloe, tell, avvocato_in_giro ).

// Guardie complementari, per tenere l'insieme esaustivo e mutuamente
// esclusivo come nel resto del progetto: c'e' sempre esattamente un piano
// applicabile per ogni evento di presenza. Le parentesi sono esplicite per
// non dipendere dalla precedenza fra "not" e "|".
+presenza(chloe, entered)
    :   ( not presentato ) | voce_sparsa
    <-  true.

// Alex gli sta accanto entro il raggio del sensore, quindi questi eventi
// arrivano comunque: li consumo senza farne nulla.
+presenza(Chi, entered)
    :   not ( Chi == chloe )
    <-  true.

+presenza(_, exited)
    <-  true.

+user_message(comeva, _) : not presentato
    <-  +presentato;
        vesna.via.speak("Sono molto impegnato, avvocato. Non ho molto tempo da perdere con questa storia.[TOPIC:pausa_caffe]").

// Il bottone dell'argomento compare da quando il giocatore ha la
// testimonianza di Alex, non da subito: prima di allora l'avvocato non ha
// nessun motivo di sapere che esistono allarmi di sicurezza ignorati, quindi
// non avrebbe nulla da chiedere (segnalato dall'utente: "non posso saperlo
// se prima non parlo con Alex"). testimonianza_alex si imposta esattamente
// quando lei rivela la verità (vesna.via.prova("alex") in alex.asl), non
// quando la si incontra soltanto — è la condizione giusta.
//
// Da quel momento in poi il bottone resta SEMPRE visibile (non solo a
// condizione soddisfatta): senza abbastanza materiale in mano rischierebbe
// di essere una prova che il giocatore non sa nemmeno che esiste. Chi clicca
// senza avere abbastanza in mano viene semplicemente liquidato (vedi sotto).
+user_message(comeva, _) : presentato & not testimonianza_alex
    <-  vesna.via.speak("Ha bisogno d'altro? Ho un'azienda da mandare avanti.[TOPIC:pausa_caffe]").

+user_message(comeva, _) : presentato & testimonianza_alex
    <-  vesna.via.speak("Ha bisogno d'altro? Ho un'azienda da mandare avanti.[TOPIC:pausa_caffe][TOPIC:sicurezza_novatech]").

// I quattro casi sotto sono scritti a partire dalle credenze di base (non da
// puo_essere_incalzato) apposta: quella regola nega se stessa quando
// "contraddetto" è vero, quindi userla per il caso "senza prove" la
// confonderebbe col caso "già confessato". Restano comunque esaustivi e
// mutuamente esclusivi:
//   contraddetto=vero                                -> già confessato
//   contraddetto=falso, incalzabile, non sbilanciato  -> primo tempo
//   contraddetto=falso, incalzabile, sbilanciato      -> ripete il primo tempo
//   contraddetto=falso, non incalzabile               -> liquidazione (ha
//     gia' la testimonianza di Alex, che da sola non basta: gliene manca
//     ancora almeno un'altra per arrivare a 2)

// ---- Senza abbastanza in mano: lo ignora, e la conversazione non si apre ----
// Nessuna credenza toccata: ripetibile all'infinito, senza dare nessun
// indizio su cosa manchi. Il bottone resta comunque cliccabile in ogni
// momento, quindi la prova non è mai davvero persa.
+user_message(sicurezza_novatech, _) : not puo_essere_incalzato & not contraddetto
    <-  vesna.via.speak("Allarmi di sicurezza? Non so di cosa stia parlando, avvocato. Se non ha altro, ho del lavoro da fare.").

// ---- Primo tempo: nega, e proprio negando si sbilancia ----
+user_message(sicurezza_novatech, _) : puo_essere_incalzato & not sbilanciato
    <-  +sbilanciato;
        vesna.via.speak("Allarmi di sicurezza? Non mi risulta niente del genere. E comunque non e' compito mio stare a leggere i report tecnici del reparto sicurezza.[TOPIC:contraddizione_jefferson]").

+user_message(sicurezza_novatech, _) : puo_essere_incalzato & sbilanciato
    <-  vesna.via.speak("Le ho gia' detto che di quegli allarmi non mi risulta nulla.[TOPIC:contraddizione_jefferson]").

+user_message(sicurezza_novatech, _) : contraddetto
    <-  vesna.via.speak("Su quella storia ho gia' detto anche troppo.").

// ---- Secondo tempo: cade sul dettaglio che si è lasciato scappare ----
+user_message(contraddizione_jefferson, _) : sbilanciato & not contraddetto
    <-  +contraddetto;
        // [IO]: questa la dice il GIOCATORE, non il Sig. Jefferson (vedi il
        // tag [IO] gestito in menu_dialog.gd)
        vesna.via.speak("[IO]Un momento. Nessuno le ha detto che quegli allarmi stavano nei report del reparto sicurezza. Come fa a saperlo, se quei report non li legge?");
        .wait(10000); // ~150 caratteri da leggere prima della risposta
        vesna.via.speak("...Senta. Io ho una responsabilita' verso i soci, non verso ogni singolo alert che salta fuori da quel reparto. Se avessi approvato ogni spesa che mi chiedevano, oggi la NovaTech non esisterebbe. Dare delle priorita' non e' un reato.");
        vesna.via.prova("contraddizione_jefferson").

+user_message(contraddizione_jefferson, _) : contraddetto
    <-  vesna.via.speak("Non ho altro da aggiungere su quel punto.").

// Guardia di completezza: il bottone non è raggiungibile prima della negazione,
// ma l'insieme dei piani resta comunque esaustivo.
+user_message(contraddizione_jefferson, _) : not sbilanciato
    <-  vesna.via.speak("Non capisco a cosa si riferisca, avvocato.").

// Distrazione: convincerlo ad andare al bar lo allontana abbastanza a lungo
// da uscire dal raggio del sensore di presenza di Alex (vedi
// sensor_presenza.gd), sbloccando temporaneamente la sua testimonianza.
// "Al bar" invece di una generica pausa in ufficio: siamo all'aperto in
// città, non dentro NovaTech, quindi ha senso solo se lo si manda
// fisicamente da qualche parte a piedi (aggancio anche a Chloe, la barista
// del quartiere, vedi chloe.asl — e al pettegolezzo che parte proprio da
// questo incontro, vedi la sezione piu' sotto e docs/story.md).
//
// Solo UNA pausa concessa per partita: un direttore "molto impegnato" che
// va al bar ogni volta che glielo chiedi non è credibile (segnalato
// dall'utente dopo aver testato 4 richieste consecutive, sempre accettate).
// Al giocatore basta comunque un solo viaggio per far parlare Alex.
+user_message(pausa_caffe, _) : not in_pausa & not pausa_gia_fatta
    <-  +in_pausa;
        +pausa_gia_fatta;
        vesna.via.speak("Un caffe' al bar? In effetti una pausa non mi farebbe male.");
        !vado_in_pausa.

+user_message(pausa_caffe, _) : in_pausa
    <-  vesna.via.speak("Sono gia' stato al bar di recente.").

+user_message(pausa_caffe, _) : not in_pausa & pausa_gia_fatta
    <-  vesna.via.speak("No, ho gia' perso troppo tempo oggi. Devo davvero tornare al lavoro.").

// jefferson_via e' un punto di passaggio: il percorso diretto tra
// jefferson_spot e jefferson_pausa attraversa in linea retta il tavolino
// libero del dehors (ora collisionato), e questo motore di movimento non
// aggira gli ostacoli da solo (nessun rilevamento di collisioni durante il
// cammino, solo un target fisso) — senza deviazione resta bloccato contro
// il tavolino. Vedi diario_sviluppo.md.
+!vado_in_pausa
    <-  !go_to( jefferson_via );
        !go_to( jefferson_pausa );
        .wait(20000);
        !go_to( jefferson_via );
        !go_to( jefferson_spot );
        -in_pausa.
