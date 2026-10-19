{ include( "vesna.asl" ) }
{ include( "negoziazione/dnm_patteggiamento.asl" ) }
{ include( "negoziazione/gnp_host.asl" ) }

// ============================================================
//  ATTO 3 - IL TRIBUNALE: il Giudice.
//
//  Nei termini di Muscar et al. 2012 (vedi docs/diario_sviluppo.md §35) questo
//  agente ricopre il ruolo di AUCTION HOST (AH): l'arbitro della negoziazione.
//  L'equazione del paper e'
//
//      AH = GNP_host + DNM_host
//
//  cioe' protocollo generico + regole specifiche del tipo di negoziazione. I
//  due pezzi diventeranno due include separati (gnp_host.asl e
//  dnm_patteggiamento.asl) quando ci sara' la logica vera: per ora questo file
//  contiene solo l'impalcatura, cioe' quanto basta a verificare che l'agente
//  parta e sia collegato al proprio corpo in Godot.
//
//  Scelta gia' presa con l'utente: il giudice e' un ARBITRO VERO, non un
//  narratore. Riceve ogni proposta e la valida contro le regole del DNM
//  (concessione monotona, fase corretta, valore nell'intervallo ammesso),
//  respingendola se non e' lecita. E' la lettura fedele del paper e rende lo
//  strato DNM un pezzo attivo del sistema invece che decorativo.
//
//  Durata della trattativa fissata a 8 round (t_max), compromesso scelto
//  dall'utente fra i 6 proposti e i 10: abbastanza perche' la curva di
//  concessione di Faratin si veda, non tanto da annoiare chi guarda.
// ============================================================

+!start
    :   .my_name( Me )
    <-  +ntpp( Me, tribunale );
        +at( Me, tribunale );
        +t_max( 8 );
        +fase( attesa );
        +forza_difesa( 0 );
        .print("Sono il Giudice. L'aula e' pronta.").

// ---- Il giudice tiene il conto di cosa ha in mano la difesa ------------
//  Le prove arrivano dall'inventario di Godot. Al giudice servono per due
//  cose: dire in udienza quante ne sono state depositate, e soprattutto
//  pesare il VERDETTO quando la trattativa fallisce (forza_difesa in
//  gnp_host.asl). Prima era fissa a 0, quindi senza accordo la condanna era
//  sempre piena a prescindere dal lavoro fatto in Atto 2.
+prova_raccolta( Id, _ )
    :   not prova_nota( Id ) & peso_argomento( Id, W ) & forza_difesa( F )
    <-  +prova_nota( Id );
        NuovaF = F + W;
        -+forza_difesa( NuovaF ).

+prova_raccolta( _, _ ).

// ============================================================
//  FASE 1 - L'UDIENZA
//
//  Parte quando il giocatore prende posto al banco della difesa e preme Q
//  (banco_difesa.gd). Due momenti: il deposito delle prove e l'esame.
//
//  La divisione fra i due e' voluta e non si sovrappone:
//    - le PROVE sono la sostanza: depositarle e' cio' che le rende spendibili
//      come argomenti dalla difesa durante la trattativa (vedi difesa.asl);
//    - le RISPOSTE sono la prestazione dell'avvocato: fissano i parametri di
//      partenza delle due parti.
//
//  Le risposte giuste si possono sapere solo avendo davvero indagato in Atto
//  2: chi arriva in tribunale tirando dritto puo' solo tirare a indovinare.
// ============================================================
+processo( iniziato, _ )
    :   not fase( udienza ) & not fase( trattativa ) & not fase( chiusa )
    <-  -+fase( udienza );
        +credibilita( 0 );
        .print("[GIUDICE] udienza aperta.");
        vesna.via.speak("Il tribunale e' riunito nel procedimento a carico di Bob Parker. Avvocato, prima di ogni altra cosa: intende depositare le prove raccolte?[TOPIC:deposita_prove]").

+processo( _, _ ).

// ---- Deposito delle prove ---------------------------------------------
+user_message( deposita_prove, _ )
    :   forza_difesa( F ) & F > 0
    <-  .send( difesa, tell, prove_depositate );
        vesna.via.speak("Il tribunale prende atto delle prove depositate dalla difesa e le acquisisce agli atti. Si passa all'esame.");
        .wait( 7000 );
        !domanda( 1 ).

+user_message( deposita_prove, _ )
    <-  vesna.via.speak("La difesa non deposita alcun elemento. Il tribunale ne prende atto. Si passa all'esame.");
        .wait( 7000 );
        !domanda( 1 ).

// ---- L'esame: tre domande ---------------------------------------------
//  Ogni risposta passa da !risposta(N, Esito), che rifiuta le risposte a una
//  domanda gia' evasa. Serve perche' i bottoni delle domande precedenti
//  potevano restare a schermo e venire cliccati: la credibilita' arrivava
//  cosi' a 4 su un massimo di 3, e l'udienza si concludeva piu' volte.
//  Il rimedio principale e' lato Godot (in modalita' processo ogni battuta
//  ripulisce i bottoni), ma la guardia qui rende la cosa impossibile a
//  prescindere da cosa arriva dall'interfaccia.
+!domanda( 1 )
    <-  vesna.via.speak("Avvocato, chi aveva accesso alle chiavi di casa del suo assistito?[TOPIC:ud_r1a][TOPIC:ud_r1b][TOPIC:ud_r1c]").

+!domanda( 2 )
    <-  vesna.via.speak("L'accusa rileva che l'accesso e' partito dalla rete di casa del suo assistito. Come lo spiega?[TOPIC:ud_r2a][TOPIC:ud_r2b][TOPIC:ud_r2c]").

+!domanda( 3 )
    <-  vesna.via.speak("Un'ultima cosa: risulta qualcosa sulla sicurezza informatica della NovaTech?[TOPIC:ud_r3a][TOPIC:ud_r3b][TOPIC:ud_r3c]").

+!domanda( 4 )
    <-  !chiudi_udienza.

+user_message( ud_r1a, _ ) <- !risposta( 1, sbagliata ).
+user_message( ud_r1b, _ ) <- !risposta( 1, giusta ).
+user_message( ud_r1c, _ ) <- !risposta( 1, sbagliata ).

+user_message( ud_r2a, _ ) <- !risposta( 2, sbagliata ).
+user_message( ud_r2b, _ ) <- !risposta( 2, giusta ).
+user_message( ud_r2c, _ ) <- !risposta( 2, sbagliata ).

+user_message( ud_r3a, _ ) <- !risposta( 3, sbagliata ).
+user_message( ud_r3b, _ ) <- !risposta( 3, giusta ).
+user_message( ud_r3c, _ ) <- !risposta( 3, sbagliata ).

// Domanda gia' evasa: la risposta viene ignorata in silenzio.
+!risposta( N, _ )
    :   risposto( N )
    <-  true.

+!risposta( N, Esito )
    <-  +risposto( N );
        !annota( Esito );
        .wait( 6000 );
        Prossima = N + 1;
        !domanda( Prossima ).

+!annota( giusta )
    :   credibilita( C )
    <-  NuovaC = C + 1;
        -+credibilita( NuovaC );
        vesna.via.speak("Il tribunale ne prende nota. L'argomento e' fondato.").

+!annota( _ )
    <-  vesna.via.speak("Il tribunale prende atto, ma l'argomento non regge.").

// ---- Chiusura dell'udienza e passaggio alla trattativa -----------------
//  Il giudice NON impone i parametri alle parti: comunica com'e' andata
//  l'udienza e ciascuna ne trae le proprie conclusioni (vedi procuratore.asl
//  e difesa.asl). E' coerente col ruolo di arbitro nel paper di Muscar: non
//  ha una strategia propria e non decide per gli altri.
+!chiudi_udienza
    :   credibilita( C )
    <-  .print("[GIUDICE] udienza conclusa, credibilita' della difesa = ", C);
        .send( procuratore, tell, udienza_conclusa( C ) );
        .send( difesa, tell, udienza_conclusa( C ) );
        vesna.via.speak("L'esame e' concluso. Invito le parti a verificare se vi siano margini per un accordo. Puo' accomodarsi, avvocato.");
        .wait( 9000 );
        !apri_trattativa.

// ---- Come il giudice "parla" ------------------------------------------
//  Gli strati del protocollo (gnp_host.asl) non conoscono Godot: chiamano
//  !narra, e ogni agente decide come renderlo. Qui va a schermo; nel banco di
//  prova la stessa chiamata diventa una stampa, ed e' quello che permette di
//  far girare il protocollo senza Godot (vedi mind/banco_negoziazione/).
//
//  Il riquadro di dialogo si puo' usare, contrariamente a quanto temevo: il
//  filtro sul mittente lascia passare un solo interlocutore per volta, ma
//  TUTTA la narrazione della trattativa passa dal giudice (procuratore e
//  difesa non chiamano mai !narra, si limitano a proporre). Quindi in aula
//  parla una voce sola e il filtro non da' fastidio.
//
//  La pausa serve a rendere leggibile la trattativa: le battute arrivano una
//  dietro l'altra e senza attesa si sovrascriverebbero prima di poterle
//  leggere. Sta qui e non nei singoli piani cosi' vale per tutte.
//  Rete di sicurezza sul tipo: vesna.via.speak accetta SOLO stringhe, e
//  passargli un atomo solleva un ClassCastException che fa cadere l'intera
//  intenzione. In aula significava trattativa bloccata a meta' senza verdetto.
//  Qui qualunque termine non-stringa viene convertito invece di far saltare
//  tutto (successo dopo che l'annuncio di un argomento passava l'id grezzo).
+!narra( T )
    :   .string( T )
    <-  .print("[AULA] ", T);
        vesna.via.speak( T );
        !pausa_di_lettura( T ).

+!narra( T )
    <-  .term2string( T, S );
        .print("[AULA] (convertito) ", S);
        vesna.via.speak( S );
        !pausa_di_lettura( S ).

//  L'attesa e' PROPORZIONALE alla lunghezza della battuta invece che fissa:
//  in aula si alternano frasi lunghe (le posizioni motivate) e frasi corte
//  ("L'accusa mantiene la propria richiesta"), e un unico valore o annoia
//  sulle corte o taglia le lunghe. Circa 45 ms per carattere piu' 2 secondi
//  di margine: e' la stessa regola usata per le pause dei dialoghi in citta'.
+!pausa_di_lettura( T )
    <-  .length( T, N );
        Attesa = 2000 + N * 45;
        .wait( Attesa ).

// ---- Fine del procedimento --------------------------------------------
//  esito_finale viene aggiunta da gnp_host.asl alla chiusura, con accordo o
//  con verdetto. Il tag [FINE:tono] dice a Godot che il processo e' concluso
//  e con che tono mostrare la schermata finale (richiesta del prof.: prima
//  non c'era alcun segnale esplicito di fine partita, solo il tono di una
//  battuta). Il tono e' scelto in base alla FASCIA dell'esito numerico:
//    assoluzione            -> vittoria
//    sospesa o ridotta      -> parziale
//    attenuata o piena      -> sconfitta
//  E' un giudizio narrativo di QUESTO agente, non del protocollo: sta qui e
//  non in gnp_host.asl, che dell'esito conosce solo il numero. I tre piani
//  sono guardie mutuamente esclusive ed esaustive sulle cinque fasce di
//  banda/2 (dnm_patteggiamento.asl), come nel resto del progetto.
+esito_finale( _, X )
    :   banda( X, assoluzione )
    <-  .wait( 1500 );
        vesna.via.speak("Il procedimento e' concluso. La seduta e' tolta.[FINE:vittoria]").

+esito_finale( _, X )
    :   banda( X, sospesa ) | banda( X, ridotta )
    <-  .wait( 1500 );
        vesna.via.speak("Il procedimento e' concluso. La seduta e' tolta.[FINE:parziale]").

+esito_finale( _, X )
    :   banda( X, attenuata ) | banda( X, piena )
    <-  .wait( 1500 );
        vesna.via.speak("Il procedimento e' concluso. La seduta e' tolta.[FINE:sconfitta]").
