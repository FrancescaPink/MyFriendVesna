{ include( "vesna.asl" ) }

// ============================================================
//  ATTO 2 - LA CITTA': Chloe, barista del quartiere.
//  Amica di Bob, gestisce il bar dove il Sig. Jefferson va in pausa (vedi
//  jefferson.asl). Hub di pettegolezzi: sa dei debiti di Finn perche' lui
//  viene spesso al bar a lamentarsene (vedi docs/story.md, Atto 2, "Prove
//  raccolte" #4 - movente di Finn).
//
//  Sketch semplice come sullivan.asl: nessuna meccanica di fiducia. Il canale
//  prove Godot->Jason (inventario.gd -> prova_raccolta(Id,_)) e' stato
//  costruito per la prova #5 del Sig. Jefferson (vedi jefferson.asl) e Chloe
//  lo riusa per reagire alla targa FN-7 del Sig. Sullivan (vedi sotto,
//  targa_nota) e per il pettegolezzo in arrivo dal Sig. Jefferson
//  (avvocato_in_giro). Chloe non si muove: non serve city_map.asl.
// ============================================================

+!start
    :   .my_name( Me )
    <-  +ntpp( Me, citta );
        +at( Me, citta );
        .print("Ciao, sono Chloe! Gestisco il bar qui in centro.").

// ------------------------------------------------------------
//  PETTEGOLEZZO TRA NPC (secondo anello) - vedi docs/story.md, Atto 2.
//
//  avvocato_in_giro le arriva da jefferson.asl con .send(chloe, tell, ...)
//  quando lui va in pausa al bar e la incontra. Jason lo annota da solo con
//  source(jefferson): lei non sa solo COSA, sa DA CHI l'ha saputo, ed e'
//  proprio quello che le fa venire voglia di richiamare Finn.
//
//  Questo piano viene PRIMA degli altri +user_message(comeva, _) apposta:
//  in Jason vince il primo piano applicabile in ordine di file, quindi
//  finche' la telefonata non e' stata fatta e' questo a rispondere.
//  Il giocatore la trova gia' al telefono e ne sente solo la meta': e'
//  cosi' che la meccanica diventa udibile invece di restare idraulica
//  invisibile. Ed e' anche il modo in cui la voce raggiunge Finn senza
//  dover far attraversare la citta' a nessuno (lui sta dall'altra parte
//  della mappa e non incontra mai nessuno).
// ------------------------------------------------------------
+user_message(comeva, _) : avvocato_in_giro & not telefonata_fatta
    <-  +telefonata_fatta;
        vesna.via.speak("(e' al telefono, ti fa cenno di aspettare) ...ma no, Finn, tranquillo. Pero' te lo dico: e' passato di qui il tuo direttore, quello della NovaTech.");
        .wait(10000); // ~147 caratteri da leggere nella battuta precedente
        vesna.via.speak("Si', proprio lui. Dice che c'e' un avvocato che gira a fare domande su quella notte. Senti, ti richiamo dopo. Ciao.");
        .wait(8000); // ~115 caratteri da leggere nella battuta precedente
        .send( finn, tell, avvocato_in_giro );
        +presentato;
        vesna.via.speak("Scusa! Era Finn. Dicevi?[TOPIC:finn_al_bar][TOPIC:telefonata_finn]").

// La telefonata resta commentabile anche riaprendo il dialogo, cosi' non la
// perdi se l'hai chiusa per sbaglio (stesso schema di casa_nuova in bob.asl).
+user_message(telefonata_finn, _) : not telefonata_commentata
    <-  +telefonata_commentata;
        vesna.via.speak("Finn? Mi ha chiamato lui, e' da giorni che e' agitato. Gli ho solo detto quello che si dice in giro, non pensavo fosse un problema... l'ho fatta grossa?").

+user_message(telefonata_finn, _) : telefonata_commentata
    <-  vesna.via.speak("Guarda, io ripeto quello che sento. Se poi la gente si agita, non e' colpa mia.").

+user_message(comeva, _) : not presentato
    <-  +presentato;
        vesna.via.speak("Ciao! Non ti avevo mai visto da queste parti. Sei l'avvocato di Bob, vero? Ne sento parlare in continuazione qui al bancone.[TOPIC:finn_al_bar]").

// Le quattro combinazioni pettegolezzo_dato / telefonata_fatta sono scritte
// per esteso: una volta sentita la telefonata, il bottone per chiederle conto
// resta disponibile a ogni riapertura del dialogo.
+user_message(comeva, _) : presentato & not pettegolezzo_dato & not telefonata_fatta
    <-  vesna.via.speak("Allora, ti interessa sapere qualcosa? Qui passa gente tutto il giorno, si sente di tutto.[TOPIC:finn_al_bar]").

+user_message(comeva, _) : presentato & not pettegolezzo_dato & telefonata_fatta
    <-  vesna.via.speak("Allora, ti interessa sapere qualcosa? Qui passa gente tutto il giorno, si sente di tutto.[TOPIC:finn_al_bar][TOPIC:telefonata_finn]").

+user_message(comeva, _) : pettegolezzo_dato & not telefonata_fatta
    <-  vesna.via.speak("Se ti serve altro, sono sempre qui.[TOPIC:finn_al_bar]").

+user_message(comeva, _) : pettegolezzo_dato & telefonata_fatta
    <-  vesna.via.speak("Se ti serve altro, sono sempre qui.[TOPIC:finn_al_bar][TOPIC:telefonata_finn]").

// ------------------------------------------------------------
//  LA TARGA DEL SIG. SULLIVAN (FN-7) - Chloe reagisce a cio' che le porti tu.
//
//  targa_nota le arriva dall'inventario quando il giocatore ottiene la
//  testimonianza del Sig. Sullivan: prova_raccolta(sullivan, ottenuta), stesso
//  canale usato dal Sig. Jefferson per contare le prove.
//
//  Il bottone della targa e' agganciato al topic su Finn e non al saluto
//  apposta: cosi' salta fuori proprio mentre si sta gia' parlando di lui, ed
//  evita di moltiplicare le combinazioni di guardie sul saluto (che ne ha gia'
//  quattro fra pettegolezzo_dato e telefonata_fatta).
// ------------------------------------------------------------
+prova_raccolta(sullivan, _) : not targa_nota
    <-  +targa_nota.

+prova_raccolta(_, _)
    <-  true.

+user_message(finn_al_bar, _) : not pettegolezzo_dato & not targa_nota
    <-  +pettegolezzo_dato;
        vesna.via.speak("Finn? Certo che lo conosco, viene qui spesso. Ultimamente si lamenta sempre di soldi - debiti, mi ha detto, con piu' di una persona. L'ho sentito litigare al telefono proprio qui fuori, la settimana scorsa.");
        vesna.via.prova("movente_finn").

+user_message(finn_al_bar, _) : not pettegolezzo_dato & targa_nota
    <-  +pettegolezzo_dato;
        vesna.via.speak("Finn? Certo che lo conosco, viene qui spesso. Ultimamente si lamenta sempre di soldi - debiti, mi ha detto, con piu' di una persona. L'ho sentito litigare al telefono proprio qui fuori, la settimana scorsa.[TOPIC:targa_fn7]");
        vesna.via.prova("movente_finn").

+user_message(finn_al_bar, _) : pettegolezzo_dato & targa_nota & not targa_chiesta
    <-  vesna.via.speak("Come ti dicevo, Finn e i suoi debiti... non e' un segreto, qui lo sanno tutti.[TOPIC:targa_fn7]").

+user_message(finn_al_bar, _) : pettegolezzo_dato & ( ( not targa_nota ) | targa_chiesta )
    <-  vesna.via.speak("Come ti dicevo, Finn e i suoi debiti... non e' un segreto, qui lo sanno tutti.").

+user_message(targa_fn7, _) : not targa_chiesta
    <-  +targa_chiesta;
        vesna.via.speak("FN-7? Aspetta... l'auto di Finn ha la targa che inizia proprio cosi', ci metterei la mano sul fuoco. Lui parcheggia sempre dalle parti del cantiere dove lavora, dall'altro lato della citta' verso ovest.").

+user_message(targa_fn7, _) : targa_chiesta
    <-  vesna.via.speak("Te l'ho detto, quella targa e' dell'auto di Finn. Lo trovi verso ovest, dove lavora.").
