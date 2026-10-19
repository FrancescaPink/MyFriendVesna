# Banco di prova della negoziazione (Atto 3)

Esegue il protocollo di negoziazione con il **solo interprete Jason**: niente Godot, niente
partita da giocare, niente rete. Serve a verificare che il motore produca esiti diversi al variare
degli input, e a ri-verificarlo dopo ogni modifica agli `.asl`.

## Due banchi diversi

- **`banco.py`** — prova gli **strati** del protocollo (`negoziazione/*.asl`) con agenti finti
  minimi. Serve a tarare il modello: è veloce e permette di variare i parametri da riga di comando.
- **`_prova_reali.py`** — prova i **file di produzione** (`giudice.asl`, `procuratore.asl`,
  `difesa.asl`) esattamente come li carica il gioco, compreso l'innesco che arriva da Godot.
  Serve a verificare il collegamento, non la taratura.

```
python _prova_reali.py alex,sullivan      # con quelle due prove in mano alla difesa
python _prova_reali.py                    # senza prove
```

Fuori dal gioco non esiste `vesna.asl` (contiene il ragionamento RCC e le azioni di movimento, che
richiedono l'ambiente JaCaMo e il corpo in Godot): il banco lo toglie dagli include e inietta al
suo posto le credenze che in partita arriverebbero dall'inventario e dal varco del tribunale.

## Come si usa

```
cd vesna-light/mind/banco_negoziazione

python banco.py                          # tutti gli scenari, tabella  (~5 min)
python banco.py -v                       # un solo scenario, tracciato completo
python banco.py --lista                  # elenco delle prove e dei loro pesi
python banco.py -h                       # tutte le opzioni
```

### Provare un caso proprio

Si possono scegliere **le prove che la difesa ha in mano** e vedere come cambia l'esito:

```
python banco.py --prove nessuna
python banco.py --prove sullivan
python banco.py --prove alex,sullivan
python banco.py --prove tutte
python banco.py --prove alex,sullivan -v       # con il tracciato battuta per battuta
```

I nomi validi sono quelli degli id dell'inventario: `confessione`, `sullivan`, `movente_finn`,
`alex`, `contraddizione_jefferson`, `prova_fisica`. Se se ne scrive uno sbagliato, il banco lo dice
e mostra l'elenco corretto.

Si possono anche muovere i parametri della trattativa, per capire quanto pesano:

```
python banco.py --prove alex,sullivan --round 4          # meno tempo per accordarsi
python banco.py --prove alex,sullivan --beta-accusa 0.1  # accusa inflessibile
python banco.py --prove alex,sullivan --riserva-accusa 9 # accusa che parte molto dura
```

| Opzione | Significato | Default |
|---|---|---|
| `--riserva-accusa N` | il minimo che l'accusa accetta | 7 |
| `--riserva-difesa N` | il massimo che la difesa accetta | 5 |
| `--beta-accusa N` | < 1 tiene duro (Boulware), > 1 cede in fretta (Conceder) | 0.4 |
| `--beta-difesa N` | idem, per la difesa | 1.0 |
| `--round N` | round disponibili prima che si vada a verdetto | 8 |

L'accordo è possibile solo se **riserva accusa ≤ riserva difesa**; gli argomenti giocati dalla
difesa abbassano la riserva dell'accusa durante la trattativa, ed è così che una zona di accordo
inizialmente vuota può aprirsi.

Alla **prima esecuzione** chiede a Gradle il classpath del progetto e lo mette in cache in
`_classpath.txt`; dalla seconda in poi parte subito. Se cambiano le dipendenze in `build.gradle`,
basta cancellare quel file.

Serve Java e Gradle già installati — gli stessi che servono per `gradle run`. Nessuna dipendenza
in più.

## Cosa prova esattamente

A ogni giro **copia i file veri** da `../src/agt/negoziazione/` dentro `_lavoro/`, quindi prova
sempre il codice di produzione e non una copia che potrebbe essere rimasta indietro.

I tre agenti di prova (`_lavoro/b_*.asl`, rigenerati ogni volta) includono gli stessi tre strati
usati in gioco. Le uniche differenze:

- `!narra(Testo)` stampa invece di parlare a Godot;
- i parametri della strategia (riserva, β, prove disponibili come argomenti) sono scritti
  direttamente nel file, invece di arrivare dalla fase 1 dell'udienza.

È proprio per rendere possibile questa prova che i tre strati **non chiamano mai** `vesna.via.*`.

## Come leggere il risultato

La tabella riporta, per ogni scenario, se la trattativa si è chiusa con un **accordo** o è finita a
**verdetto**, e con quale esito sulla scala 0–10 (0 = assoluzione piena, 10 = condanna piena).

Con `-v` si vede l'intero scambio: le offerte che si avvicinano, e soprattutto gli **argomenti**
che la difesa spende uno alla volta (`alex`, `movente_finn`, `sullivan`), ognuno dei quali abbassa
il valore di riserva dell'accusa. È lì che si vede la meccanica di Rahwan in funzione: senza quegli
argomenti, a parità di parametri iniziali, la trattativa fallirebbe.

## Modificare gli scenari

In fondo a `banco.py`, nella lista `SCENARI`: nome, elenco delle prove che la difesa può usare come
argomenti, e il β dell'accusa (< 1 = tiene duro, > 1 = cede in fretta).

I **pesi** delle prove sono invece definiti in `../src/agt/negoziazione/dnm_patteggiamento.asl`;
se si cambiano lì, vanno aggiornati anche nel dizionario `PESI` di `banco.py`, che li usa solo per
calcolare il peso complessivo passato al giudice.

## Cartelle generate

`_lavoro/` e `_classpath.txt` sono rigenerabili e si possono cancellare in qualsiasi momento.
