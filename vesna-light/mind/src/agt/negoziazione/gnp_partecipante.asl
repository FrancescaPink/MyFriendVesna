// ============================================================
//  GNP - Generic Negotiation Protocol, ruolo PARTECIPANTE (AP)
//
//  Primo strato dell'architettura di Muscar et al. (2012), lato partecipante.
//  Incluso da procuratore.asl e difesa.asl, che sono identici come protocollo
//  e differiscono solo per la STRATEGIA (il CNS: riserva, beta, kappa) e per
//  la direzione in cui concedono.
//
//      AP = GNP_partecipante + DNM_partecipante + CNS
//
//  Le azioni corrispondono a quelle del paper (register, bid, fold):
//      registra   -> register
//      proponi    -> bid
//      accetta    -> (accettazione, implicita nel loro close)
//      rinuncia   -> fold
//
//  Questo file NON parla mai con Godot ne' narra alcunche': i partecipanti
//  si limitano a proporre, accettare o ritirarsi, ed e' l'ARBITRO a
//  raccontare in aula quello che succede (vedi gnp_host.asl -> !narra).
//  Concentrare la voce in un solo agente ha un vantaggio pratico: il
//  riquadro di dialogo di Godot accetta le battute di un interlocutore per
//  volta, quindi cosi' resta utilizzabile anche per la trattativa.
// ============================================================

// ---- Registrazione presso l'arbitro (il "register" del GNP) -----------
+!registrati
    <-  .send( giudice, tell, registra ).

// ---- Formule di Faratin et al. (1998) ---------------------------------
//
//      alpha(t) = kappa + (1 - kappa) * ( min(t, tmax) / tmax )^(1/beta)
//
//  alpha(0) = kappa e alpha(tmax) = 1: alla scadenza si offre esattamente il
//  proprio valore di riserva. Il parametro beta decide il carattere:
//      beta < 1  -> Boulware: tiene la posizione e cede solo alla fine
//      beta > 1  -> Conceder: va subito al valore di riserva
//      beta = 1  -> concessione lineare
alpha( T, A ) :-
    kappa( K ) & beta( B ) & t_max( TM ) &
    ( ( T >= TM & A = 1 ) | ( T < TM & A = K + (1 - K) * ((T / TM) ** (1 / B)) ) ).

//  L'accusa scende dal massimo verso la propria riserva, la difesa sale dal
//  minimo verso la propria. E' la stessa formula del paper applicata alle due
//  direzioni opposte di una contrattazione bilaterale.
mia_offerta( T, X ) :-
    verso( scende ) & riserva( R ) & esito_max( Max ) & alpha( T, A ) &
    X = math.round( Max - A * (Max - R) ).

mia_offerta( T, X ) :-
    verso( sale ) & riserva( R ) & esito_min( Min ) & alpha( T, A ) &
    X = math.round( Min + A * (R - Min) ).

// ---- Utilita' (le scoring function di Faratin) ------------------------
//  Normalizzate in [0,1] come nel paper. Per l'accusa vale di piu' un esito
//  severo, per la difesa uno mite.
utilita( X, U ) :- verso( scende ) & esito_max( Max ) & U = X / Max.
utilita( X, U ) :- verso( sale )   & esito_max( Max ) & U = 1 - X / Max.

// ---- Regola di accettazione (Faratin) ---------------------------------
//  Accetto l'offerta avversaria se vale almeno quanto quella che avrei
//  proposto io al round successivo: se sto per offrire qualcosa di peggiore
//  per me, tanto vale accettare adesso.
accetto( XAvv, T ) :-
    T1 = T + 1 & mia_offerta( T1, XMio ) &
    utilita( XAvv, UAvv ) & utilita( XMio, UMio ) &
    UAvv >= UMio.

// ---- Il turno di mossa (il "bid" del GNP) -----------------------------
//
//  IMPORTANTE - determinismo. Prima si SVUOTA la posta (offerta avversaria e
//  argomenti ricevuti), poi si decide. Nella versione precedente questi
//  arrivi erano gestiti da piani reattivi separati, e siccome in Jason ogni
//  agente e' un thread a se', capitava che l'offerta venisse calcolata PRIMA
//  che l'argomento appena ricevuto avesse abbassato il valore di riserva: lo
//  stesso scenario, rieseguito, chiudeva a volte a 3 e a volte a 4. Dentro
//  una fascia narrativa non si notava, ma a cavallo fra due fasce avrebbe
//  cambiato il finale a parita' di partita giocata. Svuotando la posta
//  all'inizio del turno l'ordine e' garantito.
+!tua_mossa( T )
    <-  !incassa_posta;
        !decidi_mossa( T ).

//  Tre piani con guardie mutuamente esclusive ed esaustive, come in tutto il
//  resto del progetto.

// (1) L'avversario ha gia' offerto qualcosa che mi va bene: accetto.
+!decidi_mossa( T )
    :   offerta_avversaria( XAvv ) & accetto( XAvv, T )
    <-  .send( giudice, tell, mossa( accetta( XAvv ) ) ).

// (2) Altrimenti faccio la mia controproposta, accompagnata se possibile da
//     un argomento (Rahwan): una prova che sostiene la richiesta.
+!decidi_mossa( T )
    :   mia_offerta( T, X )
    <-  -+ultima_offerta( io, X );
        !scegli_argomento( Mot );
        .send( giudice, tell, mossa( proponi( X, Mot ) ) ).

// (3) Rete di sicurezza: se per qualche motivo non riesco a calcolare
//     un'offerta, mi ritiro invece di bloccare la trattativa (il "fold").
+!decidi_mossa( _ )
    <-  .send( giudice, tell, mossa( rinuncia ) ).

// ---- Scelta dell'argomento (Rahwan) -----------------------------------
//  Spendo una prova alla volta, e ognuna una volta sola: altrimenti basterebbe
//  ripetere la stessa all'infinito. Se non ne ho piu', propongo senza motivare.
+!scegli_argomento( Mot )
    :   argomento_disponibile( P )
    <-  -argomento_disponibile( P );
        +argomento_speso( P );
        Mot = P.

+!scegli_argomento( nessuna ).

// ---- Svuotamento della posta ------------------------------------------
//  Consuma tutto quello che l'arbitro ha inviato dall'ultimo turno. Le
//  credenze ricevute vanno rimosse: in Jason aggiungere una credenza gia'
//  presente non genera evento, e inoltre si accumulerebbero, facendo leggere
//  alle guardie un valore vecchio invece dell'ultimo.
//
//  ATTENZIONE all'annotazione [source(_)]: una cancellazione scritta come
//  "-credenza(X)" sottintende [source(self)] e quindi NON tocca una credenza
//  arrivata per messaggio, che porta [source(giudice)]. Senza quell'aggiunta
//  la credenza resta, la guardia continua a essere vera e questi cicli non
//  terminano piu'. (Nella versione precedente, reattiva, lo stesso errore era
//  innocuo: il piano scattava una volta sola per ogni credenza aggiunta.)
+!incassa_posta
    <-  !incassa_argomenti;
        !incassa_offerta.

+!incassa_argomenti
    :   argomento_ric( P )
    <-  -argomento_ric( P )[source(_)];
        !valuta_argomento( P );
        !incassa_argomenti.

+!incassa_argomenti.

+!incassa_offerta
    :   offerta_ric( X )
    <-  -offerta_ric( X )[source(_)];
        -offerta_avversaria( _ );
        +offerta_avversaria( X );
        !incassa_offerta.

+!incassa_offerta.

// ---- Effetto di un argomento (il cuore di Rahwan) ---------------------
//  Un argomento altrui SPOSTA il mio valore di riserva: e' la tesi di Rahwan
//  resa eseguibile - gli argomenti non sono decorazione, modificano lo stato
//  interno di chi li riceve, e quindi l'esito della trattativa.
//  Chi concede scendendo (l'accusa) viene spinto piu' in basso; chi concede
//  salendo (la difesa) viene spinto piu' in alto. Ogni prova conta una volta.
+!valuta_argomento( P )
    :   P \== nessuna & not argomento_subito( P ) & peso_argomento( P, W ) &
        verso( scende ) & riserva( R ) & esito_min( Min )
    <-  +argomento_subito( P );
        NuovaR = math.max( Min, R - W );
        -+riserva( NuovaR ).

+!valuta_argomento( P )
    :   P \== nessuna & not argomento_subito( P ) & peso_argomento( P, W ) &
        verso( sale ) & riserva( R ) & esito_max( Max )
    <-  +argomento_subito( P );
        NuovaR = math.min( Max, R + W );
        -+riserva( NuovaR ).

+!valuta_argomento( _ ).
