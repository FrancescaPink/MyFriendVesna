{ include( "vesna.asl" ) }
{ include( "playgrounds/city/city_map.asl" ) }

// ============================================================
//  ATTO 2 - LA CITTA': Finn, ex collega di Bob, ora contractor esterno.
//  E' lui il vero colpevole: ha usato la chiave di riserva (che Bob gli
//  aveva dato per innaffiare le piante durante il trasloco, vedi bob.asl,
//  soglia fiducia >= 3) e le credenziali di Bob per coprire le proprie
//  tracce, spinto dai debiti di cui parla Chloe (vedi chloe.asl, prova
//  "movente_finn"). Vedi docs/story.md, Atto 2.
//
//  A differenza di Chloe/Sullivan, qui la conversazione e' una sequenza a
//  tre passi (guardie incatenate sullo stesso modello di
//  scatoloni_completati in bob.asl e presentato/testimonianza_data in
//  sullivan.asl): chiedere della chiave, poi delle piante, poi mettere
//  insieme i pezzi. Solo l'ultimo passo sblocca la prova. Volutamente
//  autosufficiente (non dipende dalle prove gia' raccolte altrove, vedi
//  nota in chloe.asl) cosi' funziona a prescindere dall'ordine in cui il
//  giocatore visita gli NPC di citta'.
//
//  Finn cammina avanti e indietro sulla carreggiata, piano, per rendere
//  visibile il suo nervosismo prima ancora di parlarci. Il giocatore puo'
//  dirgli di spostarsi in un posto sicuro: allora sale sul marciapiede e si
//  ferma li' (vedi topic "zona_sicura" e i marker finn_* in city_map.asl).
// ============================================================

+!start
    :   .my_name( Me )
    <-  +ntpp( Me, citta );
        +at( Me, citta );
        .print("Sono Finn, faccio lavori come contractor in giro per la citta'.");
        !!passeggia.

// Avanti e indietro finche' resta in mezzo alla strada. Due scelte volute:
//
// 1. !!passeggia (nuova intenzione) e non !passeggia: con la ricorsione
//    normale ogni giro resterebbe impilato sullo stesso stack di intenzioni,
//    che crescerebbe senza fine per tutta la partita.
//
// 2. qui uso vesna.walk direttamente invece di !go_to: !go_to aspetta
//    l'evento di arrivo con .wait({+movement(...)}), e questo ciclo parte
//    subito all'avvio dell'agente, quando la connessione con Godot potrebbe
//    non essere ancora aperta. In quel caso il comando andrebbe perso e
//    l'attesa non finirebbe mai, lasciando Finn immobile per tutta la
//    partita (stessa trappola gia' vista con sensor_presenza.gd). Cosi'
//    invece il passo si limita a un tentativo ogni 2.5 s: se il primo va a
//    vuoto, il giro dopo riprova da solo. Per un dondolio nervoso non serve
//    sapere con precisione quando e' arrivato.
+!passeggia
    :   not in_salvo
    <-  vesna.walk( finn_passo_a, _ );
        .wait( 2500 );
        vesna.walk( finn_passo_b, _ );
        .wait( 2500 );
        !!passeggia.

// Quando il giocatore lo convince, il giro successivo finisce sul marciapiede
// e la ricorsione si ferma. Due dettagli:
//
// - lo spostamento lo faccio QUI e non nel piano del dialogo, cosi' non ci
//   sono mai due movimenti attivi insieme sullo stesso agente (si
//   contenderebbero il NavigationAgent3D);
// - questo e' un vero !go_to, non un vesna.walk come nel dondolio: e' una
//   decisione presa (spostarsi in un posto preciso), a connessione ormai
//   aperta da un pezzo, ed e' giusto che passi dal ragionamento RCC.
+!passeggia
    :   in_salvo
    <-  !go_to( finn_sicuro ).

+user_message(comeva, _) : not presentato
    <-  +presentato;
        vesna.via.speak("Non ho molto tempo, ho dei lavori da finire. L'avvocato di Bob, giusto? Cosa vuole sapere?[TOPIC:chiave_bob][TOPIC:zona_sicura]").

// Spostarsi dal mezzo della strada. Non sblocca prove ne' cambia il percorso
// dell'interrogatorio: serve a caratterizzarlo (accetta, ma senza ammettere
// di essere agitato) e a toglierlo dalla carreggiata.
+user_message(zona_sicura, _) : not in_salvo
    <-  +in_salvo;
        vesna.via.speak("Come? Ah... si', ha ragione, scusi. Non me n'ero nemmeno accorto.").

+user_message(zona_sicura, _) : in_salvo
    <-  vesna.via.speak("Sono gia' qui sul marciapiede, tranquillo.").

// Finche' e' ancora in mezzo alla strada il bottone per farlo spostare resta
// disponibile a ogni riapertura del dialogo (stesso schema di casa_nuova in
// bob.asl e auto_sospetta in sullivan.asl); una volta al sicuro sparisce.
//
// FIX (segnalato dall'utente con un caso riprodotto dal vivo): prima "comeva"
// ritaggava SEMPRE e SOLO [TOPIC:chiave_bob], mai piante/contraddizione_finn.
// Sequenza chiave-bob -> chiudi il dialogo PRIMA di chiedere delle piante ->
// riapri: il bottone delle piante (creato solo dalla risposta di chiave_bob)
// era sparito per sempre (topic_pendenti si svuota alla chiusura, vedi
// menu_dialog.gd), e nulla lo rimetteva. Risultato: "piante" diventava
// irraggiungibile, quindi anche "contraddizione_finn" e "prova_fisica" con
// esso - un vicolo cieco silenzioso, l'unico rimasto nell'intera catena di
// Finn dopo i fix della §26/§27 (che avevano risolto lo stesso problema per
// "contraddizione_finn" stesso, ma non per i due passi precedenti).
//
// Sei piani sotto invece di due: ogni riapertura ritagga il bottone giusto
// per lo stadio in cui il giocatore si trova (chiave_bob -> piante ->
// contraddizione_finn), incrociato con zona_sicura/in_salvo. Guardie
// esaustive e mutuamente esclusive, stesso stile del resto del progetto.
+user_message(comeva, _) : presentato & not smascherato & not chiave_chiesta & not in_salvo
    <-  vesna.via.speak("Ho gia' altro a cui pensare, sinceramente.[TOPIC:chiave_bob][TOPIC:zona_sicura]").

+user_message(comeva, _) : presentato & not smascherato & not chiave_chiesta & in_salvo
    <-  vesna.via.speak("Ho gia' altro a cui pensare, sinceramente.[TOPIC:chiave_bob]").

+user_message(comeva, _) : presentato & not smascherato & chiave_chiesta & not piante_chieste & not in_salvo
    <-  vesna.via.speak("Ho gia' altro a cui pensare, sinceramente.[TOPIC:piante][TOPIC:zona_sicura]").

+user_message(comeva, _) : presentato & not smascherato & chiave_chiesta & not piante_chieste & in_salvo
    <-  vesna.via.speak("Ho gia' altro a cui pensare, sinceramente.[TOPIC:piante]").

+user_message(comeva, _) : presentato & not smascherato & piante_chieste & not in_salvo
    <-  vesna.via.speak("Ho gia' altro a cui pensare, sinceramente.[TOPIC:contraddizione_finn][TOPIC:zona_sicura]").

+user_message(comeva, _) : presentato & not smascherato & piante_chieste & in_salvo
    <-  vesna.via.speak("Ho gia' altro a cui pensare, sinceramente.[TOPIC:contraddizione_finn]").

+user_message(comeva, _) : smascherato
    <-  vesna.via.speak("...non ho altro da aggiungere.").

// ------------------------------------------------------------
//  PETTEGOLEZZO TRA NPC (terzo anello) - vedi docs/story.md, Atto 2.
//
//  avvocato_in_giro gli arriva da chloe.asl con .send(finn, tell, ...)
//  durante la telefonata che il giocatore le sente fare. Da quel momento
//  Finn sa di essere cercato e ha avuto il tempo di prepararsi una versione.
//
//  Volutamente NON diventa inespugnabile: le battute cambiano e la
//  contraddizione richiede un colpo in piu', ma la prova "prova_fisica"
//  resta sempre raggiungibile. Un vicolo cieco creato da una meccanica che
//  il giocatore non controlla del tutto sarebbe una punizione ingiusta.
// ------------------------------------------------------------
+avvocato_in_giro
    <-  +allertato.

+user_message(chiave_bob, _) : not chiave_chiesta & not allertato
    <-  +chiave_chiesta;
        vesna.via.speak("La chiave di casa sua? Gliel'ho restituita subito dopo il trasloco, non ce l'ho piu'. Non so cosa vuole insinuare.[TOPIC:piante]").

// Stessa informazione, ma recitata: ha avuto tempo di ripassarsela.
+user_message(chiave_bob, _) : not chiave_chiesta & allertato
    <-  +chiave_chiesta;
        vesna.via.speak("La chiave. Gliel'ho restituita il giorno dopo il trasloco, di mattina. Puo' controllare quando vuole, non ce l'ho piu' da mesi.[TOPIC:piante]").

+user_message(chiave_bob, _) : chiave_chiesta & not smascherato
    <-  vesna.via.speak("Gliel'ho gia' detto, non ho piu' quella chiave.").

+user_message(piante, _) : chiave_chiesta & not piante_chieste
    <-  +piante_chieste;
        vesna.via.speak("Le piante? Ah... si', certo, sono passato un paio di volte mentre lui era via. Perche' me lo chiede proprio adesso?[TOPIC:contraddizione_finn]").

+user_message(piante, _) : piante_chieste & not smascherato
    <-  vesna.via.speak("Gliel'ho gia' detto, sono passato per le piante. Tutto qui.").

// Se e' stato avvisato ha una risposta pronta e il primo affondo non basta:
// serve insistere una seconda volta. Un solo colpo in piu', non un muro.
// Il topic va ri-taggato: cliccare un bottone lo rimuove (vedi
// rimuovi_bottone_topic in menu_dialog.gd), quindi senza il tag qui il
// secondo affondo diventerebbe irraggiungibile e la prova irrecuperabile.
+user_message(contraddizione_finn, _) : piante_chieste & allertato & not primo_affondo & not smascherato
    <-  +primo_affondo;
        vesna.via.speak("Le date? Le ho ricontrollate proprio stamattina, guardi. Si sara' confuso lei, capita.[TOPIC:contraddizione_finn]").

+user_message(contraddizione_finn, _) : piante_chieste & allertato & primo_affondo & not smascherato
    <-  +smascherato;
        // [IO]: questa la dice il GIOCATORE, non Finn. Il tag la fa comparire
        // di un colore diverso nel riquadro (vedi menu_dialog.gd), altrimenti
        // arrivando dallo stesso canale sembrava una battuta dell'NPC.
        vesna.via.speak("[IO]Ricontrollate stamattina, dice. Nessuno ricontrolla le date di sei mesi fa proprio la mattina in cui arriva un avvocato, Finn. Chi l'ha avvisata?");
        .wait(10000); // ~145 caratteri da leggere prima del crollo
        vesna.via.speak("...Va bene, basta. Avevo dei debiti, dovevo sistemarli in fretta. Ho tenuto una copia della chiave. Non pensavo finisse cosi'. Ho ancora... ho ancora dei log sul portatile, se le servono.");
        vesna.via.prova("prova_fisica").

+user_message(contraddizione_finn, _) : piante_chieste & not allertato & not smascherato
    <-  +smascherato;
        // [IO]: battuta del GIOCATORE, vedi nota nel ramo "allertato" sopra.
        vesna.via.speak("[IO]Senta... se e' passato di li' dopo il trasloco, come ha fatto ad avere ancora la chiave per innaffiare le piante durante? Le date non tornano, Finn.");
        .wait(10000); // ~150 caratteri da leggere prima del crollo
        vesna.via.speak("...Va bene, basta. Avevo dei debiti, dovevo sistemarli in fretta. Ho tenuto una copia della chiave. Non pensavo finisse cosi'. Ho ancora... ho ancora dei log sul portatile, se le servono.");
        vesna.via.prova("prova_fisica").

+user_message(contraddizione_finn, _) : smascherato
    <-  vesna.via.speak("Ho gia' detto tutto quello che dovevo dire.").
