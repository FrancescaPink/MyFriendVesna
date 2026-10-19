{ include( "vesna.asl" ) }
{ include( "negoziazione/dnm_patteggiamento.asl" ) }
{ include( "negoziazione/gnp_partecipante.asl" ) }

// ============================================================
//  ATTO 3 - IL TRIBUNALE: il Procuratore (l'accusa).
//
//  Ruolo di AUCTION PARTICIPANT (AP) secondo Muscar et al. 2012, con
//  l'equazione
//
//      AP = GNP_participant + DNM_participant + CNS
//
//  dove la CNS (Custom Negotiation Strategy) e' la parte propria di questo
//  agente. Per ora c'e' solo l'impalcatura (vedi docs/diario_sviluppo.md §35).
//
//  Sulla scala 0..10 degli esiti (0 = assoluzione piena, 10 = condanna piena)
//  il procuratore vuole valori ALTI: la sua funzione di punteggio secondo
//  Faratin et al. 1998 e' V_p(x) = x/10, crescente.
//
//  Parte da 10 (condanna piena) e scende verso il proprio valore di riserva
//  ris_p, che e' il minimo che accetterebbe:
//
//      x_p(t) = 10 - alfa_p(t) * (10 - ris_p)
//      alfa(t) = k + (1-k) * ( min(t,t_max) / t_max )^(1/beta)
//
//  ris_p e beta_p NON sono costanti: li fissa la fase 1 (l'udienza). Ogni
//  prova presentata dal giocatore abbassa ris_p, e la credibilita' delle sue
//  risposte determina beta_p, cioe' il carattere del procuratore:
//  beta < 1 = Boulware (tiene la posizione e cede solo alla fine),
//  beta > 1 = Conceder (va subito al valore di riserva).
//
//  I valori qui sotto sono solo di partenza, quelli di un'accusa che non ha
//  ancora subito nessun contraddittorio: caso peggiore per il giocatore.
// ============================================================

+!start
    :   .my_name( Me )
    <-  +ntpp( Me, tribunale );
        +at( Me, tribunale );
        +riserva( 7 );      // non scende sotto 7 finche' non lo si incalza
        +beta( 0.4 );       // Boulware: parte duro
        +kappa( 0.0 );     // prima offerta = massimo della scala
        +verso( scende );    // direzione in cui concede
        +t_max( 8 );       // durata della trattativa, come il giudice
        !registrati;       // il "register" del GNP: mi costituisco
        .print("Sono il Procuratore. L'accusa e' pronta.").

// ---- Come parla ------------------------------------------------------
//  In aula parla solo l'arbitro: procuratore e difesa non narrano nulla, si
//  limitano a proporre (vedi gnp_partecipante.asl). Questa resta quindi una
//  stampa di servizio per il registro di Jason, utile a seguire la trattativa
//  dalla console senza doverla leggere a schermo.
+!narra( T )
    <-  .print("[L'ACCUSA] ", T).

// ---- Effetto dell'udienza sulla propria strategia (CNS) ---------------
//  Il giudice comunica quanto e' stata credibile la difesa (0-3). Non impone
//  nulla: e' il procuratore a decidere cosa farsene. Piu' la difesa e' stata
//  solida in aula, meno l'accusa e' sicura di reggere al dibattimento, quindi
//  abbassa il minimo che accetterebbe.
//
//  E' la leva che conta davvero: misurando col banco di prova si e' visto che
//  il VALORE DI RISERVA sposta l'esito, mentre beta (la testardaggine) quasi
//  no, perche' governa il ritmo della concessione e non il punto d'arrivo.
+udienza_conclusa( C )
    :   riserva( R )
    <-  NuovaR = math.max( 0, R - C );
        -+riserva( NuovaR );
        .print("[PROCURATORE] dopo l'udienza scendo a una riserva di ", NuovaR).

+udienza_conclusa( _ ).
