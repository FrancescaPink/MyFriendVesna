{ include( "vesna.asl" ) }

// ============================================================
//  ATTO 2 - LA CITTA': Alex, collega di Bob alla NovaTech.
//  Sa che il Sig. Jefferson ignorava gli allarmi di sicurezza da settimane,
//  ma ha troppa paura di dirlo se lui è nei paraggi (vedi docs/story.md,
//  Atto 2, "Prove raccolte" #2 — la meccanica di presenza reciproca
//  esplicitamente richiesta dal professore).
//
//  Alex non si muove (non chiama mai !go_to): resta ferma, ma "percepisce"
//  chi le è vicino tramite sensor_presenza.gd (un Area3D nuovo, diverso dal
//  sensore di dialogo col giocatore), che aggiorna la credenza vicino(Chi).
// ============================================================

+!start
    :   .my_name( Me )
    <-  +ntpp( Me, citta );
        .print("Sono Alex, collega di Bob alla NovaTech.").

// Percezione di presenza: sensor_presenza.gd manda +presenza(Chi, entered)
// quando un altro agente (non il giocatore) entra nel raggio, e
// +presenza(Chi, exited) quando se ne va. Qui la trasformo in una credenza
// semplice "vicino(Chi)" da usare come guardia nei piani di dialogo.
+presenza(Chi, entered)
    <-  +vicino(Chi).

+presenza(Chi, exited)
    :   vicino(Chi)
    <-  -vicino(Chi).

+user_message(comeva, _) : not presentato
    <-  +presentato;
        vesna.via.speak("Salve avvocato, sono Alex. Lavoravo con Bob alla NovaTech... e' una situazione difficile.[TOPIC:lamentela_capo]").

+user_message(comeva, _) : presentato
    <-  vesna.via.speak("Mi dispiace per quello che sta succedendo a Bob.[TOPIC:lamentela_capo]").

// Il cuore della meccanica: la stessa domanda ha risposte diverse a seconda
// che il Sig. Jefferson sia nelle vicinanze o no. La battuta accenna al
// motivo (lui è lì vicino) invece di limitarsi a rifiutare, come piccolo
// indizio diegetico verso "va allontanato" — nessun bottone nuovo, solo
// testo (richiesta dell'utente).
+user_message(lamentela_capo, _) : vicino(jefferson)
    <-  vesna.via.speak("Non posso parlarne ora, mi scusi... non con lui qui vicino.[TOPIC:lamentela_capo]").

+user_message(lamentela_capo, _) : not vicino(jefferson) & not verita_detta
    <-  +verita_detta;
        vesna.via.speak("Va bene, gliela dico: il Sig. Jefferson sapeva degli allarmi di sicurezza ignorati da settimane, ma ha troppa paura di ammetterlo davanti a lui.");
        vesna.via.prova("alex").

+user_message(lamentela_capo, _) : verita_detta
    <-  vesna.via.speak("Le ho gia' detto quello che sapevo sugli allarmi ignorati.").
