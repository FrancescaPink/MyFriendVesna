{ include( "vesna.asl" ) }
{ include( "negoziazione/dnm_patteggiamento.asl" ) }
{ include( "negoziazione/gnp_partecipante.asl" ) }

// ============================================================
//  ATTO 3 - IL TRIBUNALE: la Difesa (la parte del giocatore).
//
//  Ruolo di AUCTION PARTICIPANT (AP) secondo Muscar et al. 2012, stessa
//  equazione del procuratore:
//
//      AP = GNP_participant + DNM_participant + CNS
//
//  Per ora c'e' solo l'impalcatura (vedi docs/diario_sviluppo.md §35).
//
//  Sulla scala 0..10 degli esiti la difesa vuole valori BASSI: funzione di
//  punteggio secondo Faratin et al. 1998 V_d(x) = 1 - x/10, decrescente.
//
//  Parte da 0 (assoluzione piena) e sale verso il proprio valore di riserva
//  ris_d, che e' il massimo che accetterebbe:
//
//      x_d(t) = 0 + alfa_d(t) * ris_d
//
//  Nota: la difesa NON e' il giocatore. Il giocatore ha gia' giocato la sua
//  partita nella fase 1 (l'udienza), presentando prove e rispondendo alle
//  domande; qui la difesa negozia per lui usando quello che le ha lasciato in
//  mano. E' anche l'agente che spende gli ARGOMENTI: secondo Rahwan et al.
//  2004 ogni proposta puo' portare con se' la citazione di una prova, e un
//  argomento forte sposta il valore di riserva dell'avversario DURANTE la
//  trattativa. Le prove utilizzabili sono solo quelle davvero raccolte, e
//  ognuna e' spendibile una volta sola.
//
//  L'elenco delle prove arriva dall'inventario tramite il canale gia' esistente
//  prova_raccolta(<id>, ottenuta) (vedi §27): va aperto anche a questo agente.
// ============================================================

+!start
    :   .my_name( Me )
    <-  +ntpp( Me, tribunale );
        +at( Me, tribunale );
        +riserva( 5 );      // oltre la meta' della scala non ha senso trattare
        +beta( 1.0 );       // lineare finche' la fase 1 non dice altro
        +kappa( 0.0 );     // prima offerta = assoluzione piena
        +verso( sale );    // direzione in cui concede
        +t_max( 8 );       // durata della trattativa, come il giudice
        +peso_depositato( 0 ); // si riempie al deposito in udienza
        !registrati;       // il "register" del GNP: mi costituisco
        .print("Sono la Difesa. Pronta a trattare per Bob.").

// Ogni prova raccolta in citta' diventa una munizione argomentativa per la
// trattativa (Rahwan). Qui la registro soltanto: sara' la CNS a decidere
// quando spenderla.
+prova_raccolta(Id, _) : not prova_in_mano(Id)
    <-  +prova_in_mano(Id).

+prova_raccolta(_, _)
    <-  true.

// ---- Il deposito in udienza e' cio' che le rende spendibili -----------
//  Una prova raccolta in citta' e' solo "in mano"; diventa un argomento
//  utilizzabile nella trattativa (Rahwan) SOLO se il giocatore la deposita
//  formalmente davanti al giudice (vedi giudice.asl, fase 1). Se salta quel
//  passaggio, la difesa arriva alla trattativa disarmata: e' l'atto del
//  depositare a dare senso all'udienza, invece di renderla una formalita'.
+prove_depositate
    <-  !deposita_tutte.

+!deposita_tutte
    :   prova_in_mano( P ) & peso_argomento( P, W ) & peso_depositato( T )
    <-  -prova_in_mano( P );
        +argomento_disponibile( P );
        T1 = T + W;
        -+peso_depositato( T1 );
        !deposita_tutte.

//  Finito il deposito, la difesa rivede QUANTO E' DISPOSTA AD ACCETTARE.
//  Con prove pesanti in mano non ha motivo di accontentarsi di un
//  patteggiamento alto: se l'accusa non scende abbastanza, tanto vale
//  affrontare il dibattimento.
//
//  Serve anche a correggere un difetto misurato in taratura: la riserva
//  dell'accusa tocca presto il fondo scala, e da li' in poi le prove in piu'
//  non spostavano piu' nulla. Tutti i profili di giocatore bravo finivano
//  sullo stesso identico esito. Legando anche la riserva della difesa al peso
//  delle prove, il materiale raccolto continua a contare.
+!deposita_tutte
    :   peso_depositato( T ) & riserva( R )
    <-  Sconto = math.floor( T / 3 );
        NuovaR = math.max( 0, R - Sconto );
        -+riserva( NuovaR );
        .count( argomento_disponibile( _ ), N );
        .print("[DIFESA] depositate ", N, " prove (peso ", T,
               "): non accetto oltre ", NuovaR).

// ---- Effetto dell'udienza sulla propria strategia (CNS) ---------------
//  Un'udienza andata bene rende la difesa piu' sicura di se': tiene la
//  posizione piu' a lungo invece di correre verso il proprio valore di
//  riserva. In termini di Faratin, beta scende verso il comportamento
//  BOULWARE (beta < 1: si concede solo verso la fine).
//
//  Serve anche a correggere un difetto visto al banco: con l'accusa ormai
//  alle corde, una difesa lineare svendeva comunque, chiudendo molto sopra
//  il minimo che avrebbe potuto ottenere.
+udienza_conclusa( C )
    <-  NuovoB = 1.0 - 0.25 * C;
        -+beta( NuovoB );
        .print("[DIFESA] dopo l'udienza il mio beta e' ", NuovoB).

// ---- Come parla ------------------------------------------------------
//  In aula parla solo l'arbitro: procuratore e difesa non narrano nulla, si
//  limitano a proporre (vedi gnp_partecipante.asl). Questa resta quindi una
//  stampa di servizio per il registro di Jason, utile a seguire la trattativa
//  dalla console senza doverla leggere a schermo.
+!narra( T )
    <-  .print("[LA DIFESA] ", T).
