// ============================================================
//  GNP - Generic Negotiation Protocol, ruolo ARBITRO (AH)
//
//  Incluso da giudice.asl.        AH = GNP_host + DNM_host
//
//  Corrisponde all'Auction Host del paper di Muscar et al. (2012): coordina i
//  partecipanti, VALIDA le proposte contro le regole del DNM e dichiara
//  l'esito. Come nel paper, l'arbitro non ha una strategia propria - non
//  "vuole" un esito - si limita a far rispettare il protocollo.
//
//  Azioni corrispondenti a quelle del paper:
//      registra -> register      chiudi -> close       esito -> winner
//
//  Anche questo file non parla con Godot: chiama !narra(Testo), che
//  giudice.asl implementa con vesna.via.speak e il banco di prova con .print.
// ============================================================

// ---- Registrazione dei partecipanti (il "register" del GNP) -----------
+registra[source(A)]
    :   not registrato( A )
    <-  +registrato( A ).

+registra[source(_)].

// ---- Apertura della trattativa ----------------------------------------
//  Il tag [TRATTATIVA] in testa alla prima battuta segnala a Godot che da
//  qui in poi la negoziazione e' automatica: il giocatore passa dal riquadro
//  a riga singola a un log scorrevole (richiesta del prof. in sede di
//  controllo: prima le battute si sovrascrivevano ed erano impossibili da
//  rileggere). E' solo un marcatore testuale per l'interfaccia, come i
//  [TOPIC:...] gia' usati altrove: non tocca il protocollo.
+!apri_trattativa
    :   registrato( procuratore ) & registrato( difesa )
    <-  -+fase( trattativa );
        -+round( 0 );
        !narra( "[TRATTATIVA]Il tribunale invita le parti a verificare se vi sia spazio per un accordo. La parola all'accusa." );
        !turno( procuratore ).

+!apri_trattativa
    <-  !narra( "Non tutte le parti si sono costituite: si procede a verdetto." );
        !verdetto_senza_accordo.

// ---- Gestione dei turni -----------------------------------------------
//  Il tempo costa (Rubinstein): ogni round consumato avvicina la scadenza, e
//  alla scadenza NON c'e' accordo ma verdetto. E' la pressione che nel paper
//  di Rubinstein e' resa dal fattore di sconto.
+!turno( A )
    :   round( T ) & t_max( TM ) & T <= TM
    <-  .send( A, achieve, tua_mossa( T ) ).

+!turno( _ )
    <-  !narra( "Il tempo concesso alle parti e' esaurito senza che si sia raggiunta un'intesa." );
        !verdetto_senza_accordo.

// ---- Ricezione di una mossa -------------------------------------------
//  La credenza che ha scatenato l'evento viene RIMOSSA subito: in Jason
//  aggiungere una credenza gia' presente non genera un nuovo evento, quindi
//  senza questa rimozione una seconda proposta identica alla precedente (cosa
//  normalissima quando un agente Boulware tiene la posizione) verrebbe
//  ignorata e la trattativa si bloccherebbe.
+mossa( M )[source(A)]
    <-  -mossa( M )[source(A)];
        !gestisci( A, M ).

// ---- Validazione (qui l'arbitro fa il suo mestiere) -------------------
//  check_proposta viene dal DNM. Se la proposta non rispetta le regole (fuori
//  scala, oppure un passo indietro rispetto alla propria offerta precedente)
//  l'arbitro la respinge, esattamente come l'AH del paper.
+!gestisci( A, proponi( X, Mot ) )
    :   check_proposta( A, X )
    <-  !ricorda_offerta( A, X );
        !annuncia_proposta( A, X, Mot );
        !inoltra( A, X, Mot );
        !passa_turno( A ).

+!gestisci( A, proponi( X, _ ) )
    <-  !narra( "Il tribunale dichiara la proposta irricevibile: non si puo' tornare su posizioni gia' superate." );
        .print( "[GIUDICE] proposta non valida da ", A, ": ", X );
        !passa_turno( A ).

// ---- Accettazione: la trattativa si chiude con un accordo -------------
+!gestisci( _, accetta( X ) )
    <-  !chiudi_con_accordo( X ).

// ---- Ritiro (il "fold" del GNP) ---------------------------------------
+!gestisci( A, rinuncia )
    <-  .print( "[GIUDICE] ", A, " si ritira dalla trattativa." );
        !verdetto_senza_accordo.

// ---- Inoltro all'altra parte ------------------------------------------
//  L'arbitro passa all'avversario l'offerta e, separatamente, l'eventuale
//  argomento: e' l'argomento a spostare il valore di riserva di chi lo riceve
//  (vedi gnp_partecipante.asl).
+!inoltra( procuratore, X, Mot ) <- !manda( difesa, X, Mot ).
+!inoltra( difesa,      X, Mot ) <- !manda( procuratore, X, Mot ).

+!manda( A, X, Mot )
    <-  .send( A, tell, argomento_ric( Mot ) );
        .send( A, tell, offerta_ric( X ) ).

// ---- Alternanza dei turni ---------------------------------------------
//  Dopo l'accusa tocca alla difesa; dopo la difesa il round e' completo e si
//  riparte dall'accusa. Sono le offerte alternate di Rubinstein.
+!passa_turno( procuratore )
    <-  !turno( difesa ).

//  L'espressione aritmetica va valutata PRIMA di finire in una credenza:
//  -+round(T+1) memorizzerebbe il termine non calcolato.
+!passa_turno( difesa )
    :   round( T )
    <-  T1 = T + 1;
        -+round( T1 );
        !turno( procuratore ).

// ---- Chiusure (il "close" e il "winner" del GNP) ----------------------
+!chiudi_con_accordo( X )
    :   banda( X, B ) & frase_esito( B, F ) & descrizione_esito( X, D )
    <-  -+fase( chiusa );
        !narra( "Le parti hanno raggiunto un accordo. Il tribunale lo recepisce." );
        !narra( F );
        .print( "[ESITO] accordo esito=", X, " (", D, ")" );
        +esito_finale( accordo, X ).

//  Senza accordo decide il tribunale, e il peso complessivo delle prove
//  portate dalla difesa sposta il verdetto: chi non ha lavorato in Atto 2
//  arriva qui senza nulla con cui difendersi.
+!verdetto_senza_accordo
    :   forza_difesa( Fo ) & esito_max( Max ) & banda( Max - Fo, B ) &
        frase_esito( B, Fr ) & descrizione_esito( Max - Fo, D )
    <-  -+fase( chiusa );
        V = Max - Fo;
        !narra( "Le parti non hanno trovato un accordo. Decide il tribunale, sulla base di quanto e' stato prodotto in giudizio." );
        !narra( Fr );
        .print( "[ESITO] verdetto esito=", V, " (", D, ")" );
        +esito_finale( verdetto, V ).

+!verdetto_senza_accordo
    <-  -+fase( chiusa );
        !narra( "Le parti non hanno trovato un accordo e la difesa non ha prodotto nulla in giudizio. Il tribunale condanna Bob Parker alla pena piena." );
        .print( "[ESITO] verdetto esito=10 (condanna piena)" );
        +esito_finale( verdetto, 10 ).

// ---- Annuncio delle proposte ------------------------------------------
//  Due parti: la posizione (chi propone e dove si e' spostato) e l'eventuale
//  argomento a sostegno. L'argomento si annuncia con la sua FRASE, non con
//  l'identificativo tecnico: in aula suonerebbe come un codice di database, e
//  per giunta farebbe cadere vesna.via.speak, che accetta solo stringhe.
+!annuncia_proposta( A, X, Mot )
    <-  !annuncia_posizione( A, X );
        !annuncia_argomento( Mot ).

//  Se la parte ripete la fascia del giro precedente non si rilegge la frase
//  intera: nelle prime battute entrambe restano ferme sulle posizioni di
//  partenza, e sentirsele ripetere per quattro giri identici e' illeggibile.
+!annuncia_posizione( A, X )
    :   banda( X, B ) & ultima_banda( A, B ) & frase_immobile( A, F )
    <-  !narra( F ).

+!annuncia_posizione( A, X )
    :   banda( X, B ) & frase_proposta( A, B, F )
    <-  !ricorda_banda( A, B );
        !narra( F ).

//  Rete di sicurezza: se manca la frase per quella combinazione, si annuncia
//  almeno la fascia invece di restare muti.
+!annuncia_posizione( _, X )
    :   descrizione_esito( X, D )
    <-  !narra( D ).

+!annuncia_posizione( _, _ ).

+!annuncia_argomento( nessuna ).

+!annuncia_argomento( Mot )
    :   descrizione_argomento( Mot, DescMot )
    <-  !narra( DescMot ).

//  Argomento senza descrizione nota: meglio tacere che leggere un id grezzo.
+!annuncia_argomento( _ ).

// ---- Memorie per parte: attenzione a NON usare "-+" -------------------
//  In Jason "-+p(A,B)" non sostituisce la credenza corrispondente: e' un
//  aggiornamento che azzera TUTTE le credenze con quel nome. Con una memoria
//  indicizzata per parte, quindi, salvare il dato della difesa cancellava
//  quello dell'accusa.
//
//  Sulle frasi si vedeva solo un fastidio (le posizioni immobili venivano
//  riannunciate per intero), ma su ultima_offerta il danno era serio: e' la
//  credenza che check_proposta usa per verificare la concessione monotona.
//  Cancellata a ogni turno, la guardia trovava sempre "nessuna offerta
//  precedente" e approvava qualunque proposta: la validazione dell'arbitro,
//  cioe' il compito che il paper assegna all'AH, era di fatto disattivata.
//
//  Qui si rimuove esplicitamente SOLO la voce di quella parte. Il piano di
//  riserva serve perche' una "-" che non trova nulla farebbe fallire il piano.
+!ricorda_offerta( A, X )
    :   ultima_offerta( A, Vecchia )
    <-  -ultima_offerta( A, Vecchia );
        +ultima_offerta( A, X ).

+!ricorda_offerta( A, X )
    <-  +ultima_offerta( A, X ).

+!ricorda_banda( A, B )
    :   ultima_banda( A, Vecchia )
    <-  -ultima_banda( A, Vecchia );
        +ultima_banda( A, B ).

+!ricorda_banda( A, B )
    <-  +ultima_banda( A, B ).
