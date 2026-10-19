// ============================================================
//  MAPPA RCC DELLA CITTA' (Atto 2) - vedi playgrounds/home/house_map.asl
//  per il modello equivalente della casa (Atto 1).
//
//  Volutamente minima per ora: contiene solo i due punti che servono al
//  Sig. Jefferson per allontanarsi in pausa su richiesta del giocatore
//  (distrazione per far parlare Alex liberamente, vedi alex.asl/jefferson.asl
//  e docs/story.md, Atto 2). Nessuna delle altre location di città (Chloe,
//  NovaTech, ecc.) è ancora mappata: si aggiunge qui quando servirà davvero,
//  stesso principio già seguito per non costruire in anticipo cose che
//  ancora non servono.
//
//  jefferson_spot e jefferson_pausa sono Marker3D in city.tscn, nella
//  stessa regione "citta" (nessuna porta/corridoio necessario: !go_to usa
//  il caso più semplice, "stessa regione", vedi vesna.asl).
// ============================================================

map_ntpp( jefferson_spot, citta ).
map_ntpp( jefferson_pausa, citta ).
map_ntpp( jefferson_via, citta ).

// I due estremi del breve avanti-e-indietro di Finn sulla carreggiata, e il
// punto sul marciapiede dove si sposta quando il giocatore glielo chiede
// (vedi finn.asl). Anche questi sono Marker3D in city.tscn nella stessa
// regione "citta", quindi !go_to usa sempre il caso "stessa regione".
map_ntpp( finn_passo_a, citta ).
map_ntpp( finn_passo_b, citta ).
map_ntpp( finn_sicuro, citta ).
