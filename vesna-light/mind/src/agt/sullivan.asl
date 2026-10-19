{ include( "vesna.asl" ) }

// ============================================================
//  ATTO 2 - LA CITTA': primo testimone, il Sig. Sullivan.
//  Vicino di casa di Bob: ha visto un'auto sospetta la notte del fatto,
//  con una targa parziale che punta a Finn (vedi docs/story.md, Atto 2,
//  "Prove raccolte" #3).
//
//  Sketch volutamente semplice per validare l'intera pipeline (nodo scena,
//  agente, dialogo, prova nell'inventario) prima di affrontare NPC più
//  complessi (Alex/Sig. Jefferson con la meccanica di presenza reciproca).
//  Nessuna meccanica di fiducia: la testimonianza è disponibile da subito,
//  a differenza di Bob in Atto 1.
//
//  Sullivan non si muove (non chiama mai !go_to): non serve quindi una
//  city_map.asl per farlo funzionare. Andrà creata quando un NPC dovrà
//  davvero spostarsi (es. Chloe, o Finn che scappa).
// ============================================================

+!start
    :   .my_name( Me )
    <-  +ntpp( Me, citta );
        +at( Me, citta );
        .print("Ciao, sono il Sig. Sullivan! Sono il vicino di casa di Bob.").

// Primo incontro: si presenta e offre subito la sua testimonianza
+user_message(comeva, _) : not presentato
    <-  +presentato;
        vesna.via.speak("Buongiorno. Lei e' l'avvocato di Bob, giusto? Ho visto qualcosa la notte del fatto, se le interessa.[TOPIC:auto_sospetta]").

// Se non ha ancora dato la testimonianza, ogni saluto la ripropone
+user_message(comeva, _) : presentato & not testimonianza_data
    <-  vesna.via.speak("Le ho gia' detto che ho visto qualcosa quella notte, se vuole sentirla.[TOPIC:auto_sospetta]").

// Anche dopo la testimonianza il bottone resta raggiungibile (a differenza
// di scatoloni_grazie in Atto 1, qui non c'e' motivo di nasconderlo per
// sempre): cosi' il giocatore puo' rifarsi ripetere i dettagli quando vuole,
// e il piano "auto_sospetta : testimonianza_data" qui sotto diventa davvero
// raggiungibile invece di restare codice morto.
+user_message(comeva, _) : testimonianza_data
    <-  vesna.via.speak("Spero che le informazioni che le ho dato siano utili.[TOPIC:auto_sospetta]").

// Ultima frase aggiunta come piccolo rimando diegetico al passo successivo
// (richiesta dell'utente): non specifica nulla, si limita a suggerire di
// chiedere in giro — è Chloe a raccogliere davvero il filo, se le porti la
// targa (vedi chloe.asl, topic targa_fn7).
+user_message(auto_sospetta, _) : not testimonianza_data
    <-  +testimonianza_data;
        vesna.via.speak("Quella notte ho visto un'auto che non avevo mai visto, parcheggiata qui vicino fino a tardi. Sono riuscito a leggere solo parte della targa: 'FN-7...'. Mi e' sembrata sospetta. Magari qualcuno in centro la riconosce.");
        vesna.via.prova("sullivan").

+user_message(auto_sospetta, _) : testimonianza_data
    <-  vesna.via.speak("Come le ho detto, la targa dell'auto iniziava con 'FN-7'.").
