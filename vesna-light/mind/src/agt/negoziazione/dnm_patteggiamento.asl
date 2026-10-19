// ============================================================
//  DNM - Declarative Negotiation Mechanism: PATTEGGIAMENTO
//
//  Secondo strato dell'architettura di Muscar et al. (2012). Il GNP e' lo
//  scheletro generico dell'interazione; questo file contiene le regole che lo
//  specializzano per il nostro tipo di negoziazione. Nel paper lo stesso posto
//  e' occupato dalle regole dell'asta inglese e di quella olandese: e' proprio
//  qui che si verifica la loro tesi di riusabilita', perche' cambiamo tipo di
//  negoziazione senza toccare il GNP.
//
//  Incluso da TUTTI E TRE gli agenti (giudice, procuratore, difesa): il
//  giudice lo usa per validare le proposte, i partecipanti per sapere cosa
//  possono proporre.
//
//  Come nel paper, le regole portano l'annotazione di FASE (li' era
//  [state(bidding)], qui [fase(trattativa)]): sono applicabili solo nella fase
//  giusta del processo.
// ============================================================

// ---- L'oggetto della negoziazione -------------------------------------
// Una sola dimensione: la severita' dell'esito, da 0 a 10.
//   0 = assoluzione piena          5-6 = patteggiamento medio
//   1-2 = assoluzione/archiviazione  7-8 = patteggiamento pesante
//   3-4 = pena sospesa               9-10 = condanna piena
// Faratin e' multi-issue, ma tratta esplicitamente anche il caso a issue
// singola; restare a una dimensione e' onesto e verificabile.
esito_min(0).
esito_max(10).

// ---- Chi concede in che direzione -------------------------------------
// L'accusa parte dal massimo e concede SCENDENDO, la difesa parte dal minimo
// e concede SALENDO. E' la differenza di fondo con l'asta del paper, dove
// tutte le offerte si muovono nella stessa direzione.
verso_di( procuratore, scende ).
verso_di( difesa,      sale   ).

concede( scende, Precedente, Nuova ) :- Nuova <= Precedente.
concede( sale,   Precedente, Nuova ) :- Nuova >= Precedente.

// ---- Validita' di una proposta (il check_proposal del paper) ----------
// Una proposta e' ammissibile se: siamo in fase di trattativa, sta nella
// scala, ed e' una concessione rispetto alla propria offerta precedente
// (la prima proposta e' sempre valida perche' non c'e' un precedente).
// Il vincolo di monotonia e' la traduzione bilaterale del "non si torna
// indietro" delle offerte alternate di Rubinstein.
check_proposta( Chi, Nuova )[fase(trattativa)] :-
    esito_min( Min ) & esito_max( Max ) &
    Nuova >= Min & Nuova <= Max &
    verso_di( Chi, Verso ) &
    ( ( not ultima_offerta( Chi, _ ) )
      | ( ultima_offerta( Chi, Prec ) & concede( Verso, Prec, Nuova ) ) ).

// ---- Zona di possibile accordo ----------------------------------------
// Esiste un accordo raggiungibile solo se il minimo che accetta l'accusa non
// supera il massimo che accetta la difesa. Se la zona e' vuota la trattativa
// fallisce e si va a verdetto: e' un esito legittimo del modello, non un bug.
zona_di_accordo( RisAccusa, RisDifesa ) :- RisAccusa <= RisDifesa.

// ---- Peso degli argomenti (Rahwan) ------------------------------------
// Quanto sposta il valore di riserva dell'avversario una prova usata come
// argomento durante la trattativa. La somma fa 10, cioe' l'intera scala:
// con tutte e sei le prove la difesa puo' in teoria portare l'accusa fino
// all'assoluzione. Sono i pesi da tarare in fase di bilanciamento.
// Come si annuncia in aula una prova usata come argomento. Serve per due
// motivi: in aula deve sentirsi una frase, non l'identificativo tecnico della
// prova; e vesna.via.speak accetta SOLO stringhe, quindi passargli l'atomo
// "sullivan" faceva cadere l'intenzione con un errore di cast.
descrizione_argomento( confessione,
    "A sostegno, la difesa richiama la dichiarazione dell'imputato sulla copia delle chiavi." ).
descrizione_argomento( sullivan,
    "A sostegno, la difesa richiama la deposizione del vicino sull'auto sospetta." ).
descrizione_argomento( movente_finn,
    "A sostegno, la difesa richiama i debiti che gravavano sull'ex collega dell'imputato." ).
descrizione_argomento( alex,
    "A sostegno, la difesa richiama la testimonianza sugli allarmi di sicurezza ignorati." ).
descrizione_argomento( contraddizione_jefferson,
    "A sostegno, la difesa richiama la contraddizione in cui e' caduto il direttore della NovaTech." ).
descrizione_argomento( prova_fisica,
    "A sostegno, la difesa deposita i registri recuperati dal portatile dell'ex collega." ).

peso_argomento( confessione,              1 ).
peso_argomento( sullivan,                 1 ).
peso_argomento( movente_finn,             1 ).
peso_argomento( alex,                     2 ).
peso_argomento( contraddizione_jefferson, 2 ).
peso_argomento( prova_fisica,             3 ).

// ---- Traduzione dell'esito numerico in linguaggio d'aula --------------
//  Le soglie stanno in UN SOLO posto (banda/2): le frasi qui sotto si
//  appoggiano tutte a quella, cosi' ritoccare la scala non obbliga a
//  rincorrere gli stessi numeri in cinque tabelle diverse.
//  Fasce riequilibrate in fase di taratura: prima "pena sospesa" copriva da
//  sola tre valori su undici (2, 3, 4) e si portava dentro meta' dei finali
//  possibili, mentre le fasce alte erano quasi irraggiungibili. Ora ogni
//  fascia vale due valori, salvo le due estreme.
banda( X, assoluzione ) :- X <= 1.
banda( X, sospesa )     :- X > 1 & X <= 3.
banda( X, ridotta )     :- X > 3 & X <= 5.
banda( X, attenuata )   :- X > 5 & X <= 7.
banda( X, piena )       :- X > 7.

descrizione_esito( X, D ) :- banda( X, B ) & nome_banda( B, D ).

nome_banda( assoluzione, "assoluzione piena" ).
nome_banda( sospesa,     "pena sospesa" ).
nome_banda( ridotta,     "pena ridotta" ).
nome_banda( attenuata,   "condanna attenuata" ).
nome_banda( piena,       "condanna piena" ).

// ---- Come si annuncia una proposta in aula ----------------------------
//  Sentire scandire "condanna piena" e "assoluzione piena" a turno non fa
//  capire NULLA: non si sa chi parla ne' se si sta avvicinando o irrigidendo.
//  Ogni frase dice quindi tre cose: quale parte parla, dove si e' spostata e
//  con che atteggiamento. Sono scritte a mano una per una perche' l'accusa
//  che "arretra" a una pena ridotta e la difesa che "cede" fino alla stessa
//  pena stanno facendo due movimenti opposti, e devono suonare diversi.
frase_proposta( procuratore, piena,
    "L'accusa chiede la condanna piena: ritiene i fatti pienamente provati e non vede margini." ).
frase_proposta( procuratore, attenuata,
    "L'accusa arretra su una condanna attenuata, pur continuando a ritenere provata la responsabilita'." ).
frase_proposta( procuratore, ridotta,
    "L'accusa si dichiara disposta a una pena ridotta: qualche incrinatura nel suo impianto comincia a vedersi." ).
frase_proposta( procuratore, sospesa,
    "L'accusa apre a una pena sospesa. La sua posizione si e' notevolmente indebolita." ).
frase_proposta( procuratore, assoluzione,
    "L'accusa non insiste oltre e dichiara di non opporsi all'assoluzione." ).

frase_proposta( difesa, assoluzione,
    "La difesa chiede l'assoluzione piena: sostiene che il suo assistito sia del tutto estraneo ai fatti." ).
frase_proposta( difesa, sospesa,
    "La difesa si dice disponibile a una pena sospesa, pur ribadendo l'estraneita' dell'imputato." ).
frase_proposta( difesa, ridotta,
    "La difesa arriva a prendere in considerazione una pena ridotta, pur di chiudere qui la vicenda." ).
frase_proposta( difesa, attenuata,
    "La difesa cede fino ad accettare una condanna attenuata." ).
frase_proposta( difesa, piena,
    "La difesa non ha piu' margini e dichiara di non potersi opporre alla condanna piena." ).

// Quando una parte ripete la posizione del giro precedente non ha senso
// rileggere la frase per intero: si dice solo che tiene il punto.
frase_immobile( procuratore, "L'accusa mantiene la propria richiesta." ).
frase_immobile( difesa,      "La difesa mantiene la propria posizione." ).

// ---- Come si annuncia l'esito finale ----------------------------------
frase_esito( assoluzione, "Bob Parker e' assolto: il tribunale non ravvisa alcuna responsabilita' a suo carico." ).
frase_esito( sospesa,     "Bob Parker e' condannato a una pena sospesa: non scontera' il carcere." ).
frase_esito( ridotta,     "Bob Parker e' condannato a una pena ridotta." ).
frase_esito( attenuata,   "Bob Parker e' condannato, con le attenuanti riconosciute." ).
frase_esito( piena,       "Bob Parker e' condannato alla pena piena." ).
