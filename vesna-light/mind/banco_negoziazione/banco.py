# -*- coding: utf-8 -*-
"""
BANCO DI PROVA DELLA NEGOZIAZIONE (Atto 3)
==========================================

Esegue il protocollo di negoziazione con il SOLO interprete Jason: niente
Godot, niente partita, niente rete. Serve a verificare che il motore produca
esiti diversi al variare degli input, e a ri-verificarlo dopo ogni modifica.

Come si usa:

    cd vesna-light/mind/banco_negoziazione
    python banco.py                  esegue tutti gli scenari e stampa la tabella
    python banco.py -v               esegue solo il primo scenario, mostrando
                                     l'intero tracciato battuta per battuta

Cosa prova esattamente: copia a ogni giro i file veri da
`mind/src/agt/negoziazione/` dentro una cartella di lavoro, quindi prova
sempre il codice di produzione e non una copia che potrebbe divergere.

Perche' funziona senza Godot: i tre file del protocollo non chiamano mai
`vesna.via.*`. Quando devono far parlare qualcuno invocano `!narra(Testo)`,
che qui e' implementato come semplice stampa.
"""
import io
import os
import re
import shutil
import subprocess
import sys
import time

QUI = os.path.dirname(os.path.abspath(__file__))
MIND = os.path.dirname(QUI)
STRATI = os.path.join(MIND, "src", "agt", "negoziazione")
LAVORO = os.path.join(QUI, "_lavoro")
CP_CACHE = os.path.join(QUI, "_classpath.txt")


# ---------------------------------------------------------------------------
# Classpath: serve quello COMPLETO del progetto, non il solo jar di Jason
# (senza le altre dipendenze l'interprete parte e poi muore). Lo chiediamo a
# Gradle una volta sola e lo mettiamo in cache.
# ---------------------------------------------------------------------------
def classpath():
    if os.path.exists(CP_CACHE):
        cp = io.open(CP_CACHE, encoding="utf-8").read().strip()
        if cp:
            return cp
    print("(prima esecuzione: chiedo il classpath a Gradle, ci vuole un minuto...)")
    r = subprocess.run(["gradle", "-q", "stampaClasspath", "--offline"],
                       cwd=MIND, capture_output=True, text=True, shell=True)
    cp = [l for l in r.stdout.splitlines() if ".jar" in l]
    if not cp:
        print("ERRORE: Gradle non ha restituito il classpath.")
        print(r.stdout[-500:], r.stderr[-500:])
        sys.exit(1)
    io.open(CP_CACHE, "w", encoding="utf-8").write(cp[-1].strip())
    return cp[-1].strip()


def chiudi_java_rimasti():
    """Un giro andato in timeout lascia un java appeso che tiene aperti i file.
    Chiude SOLO i processi di questo banco, riconoscibili dal loro mas2j."""
    subprocess.run(["powershell", "-NoProfile", "-Command",
                    "Get-CimInstance Win32_Process -Filter \"Name='java.exe'\" | "
                    "Where-Object { $_.CommandLine -like '*banco.mas2j*' } | "
                    "ForEach-Object { Stop-Process -Id $_.ProcessId -Force }"],
                   capture_output=True)
    time.sleep(1.0)


def prepara():
    chiudi_java_rimasti()
    if os.path.isdir(LAVORO):
        for _ in range(5):
            try:
                shutil.rmtree(LAVORO)
                break
            except PermissionError:
                time.sleep(1.0)
    os.makedirs(LAVORO, exist_ok=True)
    shutil.copytree(STRATI, os.path.join(LAVORO, "negoziazione"))
    io.open(os.path.join(LAVORO, "logging.properties"), "w", encoding="utf-8").write(
        "handlers= java.util.logging.ConsoleHandler\n"
        ".level= INFO\n"
        "java.util.logging.ConsoleHandler.level = INFO\n"
        "java.util.logging.ConsoleHandler.formatter = java.util.logging.SimpleFormatter\n"
        "java.util.logging.SimpleFormatter.format = %5$s%n\n")


# ---------------------------------------------------------------------------
# I tre agenti di prova. Includono gli stessi strati del gioco; l'unica
# differenza e' che !narra stampa invece di parlare a Godot, e che i parametri
# del CNS (riserva, beta, kappa) sono scritti direttamente qui invece di
# arrivare dalla fase 1 dell'udienza.
# ---------------------------------------------------------------------------
GIUDICE = '''{ include( "negoziazione/dnm_patteggiamento.asl" ) }
{ include( "negoziazione/gnp_host.asl" ) }
!start.
+!start <- +t_max( %(tmax)d ); +fase( attesa ); +forza_difesa( %(forza)d );
           .wait( 500 ); !apri_trattativa.
+!narra( T ) <- .print( "  > ", T ).
+esito_finale( _, _ ) <- .wait( 300 ); .stopMAS.
'''

PARTE = '''{ include( "negoziazione/dnm_patteggiamento.asl" ) }
{ include( "negoziazione/gnp_partecipante.asl" ) }
!start.
+!start <- +verso( %(verso)s ); +t_max( %(tmax)d ); +riserva( %(ris)d );
           +beta( %(beta)s ); +kappa( 0.0 );
           %(prove)s
           !registrati.
+!narra( T ) <- .print( "  > ", T ).
'''

MAS = '''MAS banco {
    agents:
        giudice      b_giudice.asl;
        procuratore  b_procuratore.asl;
        difesa       b_difesa.asl;
}
'''


def esegui(ris_p, beta_p, ris_d, beta_d, prove, tmax=8, forza=0, verbose=False):
    prepara()
    scrivi = lambda n, t: io.open(os.path.join(LAVORO, n), "w", encoding="utf-8").write(t)
    scrivi("b_giudice.asl", GIUDICE % {"tmax": tmax, "forza": forza})
    scrivi("b_procuratore.asl", PARTE % {
        "verso": "scende", "tmax": tmax, "ris": ris_p, "beta": beta_p, "prove": ""})
    scrivi("b_difesa.asl", PARTE % {
        "verso": "sale", "tmax": tmax, "ris": ris_d, "beta": beta_d,
        "prove": " ".join("+argomento_disponibile(%s);" % p for p in prove)})
    scrivi("banco.mas2j", MAS)

    proc = subprocess.Popen(
        ["java", "-Djava.util.logging.config.file=logging.properties",
         "-cp", classpath(), "jason.infra.local.RunLocalMAS", "banco.mas2j"],
        cwd=LAVORO, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    try:
        out, _ = proc.communicate(timeout=60)
    except subprocess.TimeoutExpired:
        proc.kill()
        out, _ = proc.communicate()
        out += chr(10) + "[BANCO] timeout: la trattativa non si e' chiusa"

    if verbose:
        for l in out.splitlines():
            if not re.search(r"jason\.jar|Classpath|Config|^\s+[C/]:|RTS is|inspector|^\s*$", l):
                print("   ", l)

    m = re.search(r"\[ESITO\] (\w+) esito=(\d+) \(([^)]*)\)", out)
    if m:
        return m.group(1), int(m.group(2)), m.group(3)
    err = [l for l in out.splitlines() if "error" in l.lower()]
    return "ERRORE", -1, (err[0][:80] if err else "nessun esito prodotto")


# ---------------------------------------------------------------------------
# Scenari. Pesi presi da dnm_patteggiamento.asl: cambiando li' vanno
# aggiornati anche qui.
# ---------------------------------------------------------------------------
PESI = {"confessione": 1, "sullivan": 1, "movente_finn": 1, "alex": 2,
        "contraddizione_jefferson": 2, "prova_fisica": 3}
TUTTE = list(PESI.keys())

SCENARI = [
    ("niente fatto in Atto 2",      [], 0.4),
    ("1 prova debole",              ["sullivan"], 0.4),
    ("2 prove",                     ["sullivan", "movente_finn"], 0.4),
    ("3 prove (con Alex)",          ["sullivan", "movente_finn", "alex"], 0.4),
    ("4 prove",                     ["sullivan", "movente_finn", "alex",
                                     "contraddizione_jefferson"], 0.4),
    ("tutte e 6",                   TUTTE, 0.4),
    ("3 prove, accusa arrendevole", ["sullivan", "movente_finn", "alex"], 2.0),
    ("3 prove, accusa durissima",   ["sullivan", "movente_finn", "alex"], 0.2),
]

# ---------------------------------------------------------------------------
# Riga di comando
# ---------------------------------------------------------------------------
AIUTO = """
BANCO DI PROVA DELLA NEGOZIAZIONE

  python banco.py                        esegue tutti gli scenari predefiniti
  python banco.py --prove alex,sullivan  esegue UN caso con le prove indicate
  python banco.py --lista                elenca le prove disponibili e il loro peso

Opzioni per il caso singolo:
  --prove X,Y,Z     prove in mano alla difesa; anche "tutte" o "nessuna"
  -v                mostra il tracciato completo, battuta per battuta
  --riserva-accusa N   il minimo che l'accusa accetta          (default 7)
  --riserva-difesa N   il massimo che la difesa accetta        (default 5)
  --beta-accusa N      < 1 tiene duro, > 1 cede in fretta      (default 0.4)
  --beta-difesa N                                              (default 1.0)
  --round N            round disponibili prima del verdetto    (default 8)

Esempi:
  python banco.py --prove nessuna
  python banco.py --prove alex,sullivan -v
  python banco.py --prove tutte --round 4
"""


def valore(nome, default):
    if nome in sys.argv:
        return sys.argv[sys.argv.index(nome) + 1]
    return default


def leggi_prove(testo):
    testo = testo.strip().lower()
    if testo in ("tutte", "tutto"):
        return TUTTE
    if testo in ("nessuna", "niente", ""):
        return []
    scelte = [p.strip() for p in testo.split(",") if p.strip()]
    sconosciute = [p for p in scelte if p not in PESI]
    if sconosciute:
        print("Prove non riconosciute: %s" % ", ".join(sconosciute))
        print("Quelle valide sono: %s" % ", ".join(TUTTE))
        sys.exit(1)
    return scelte


if __name__ == "__main__":
    if "--aiuto" in sys.argv or "-h" in sys.argv or "--help" in sys.argv:
        print(AIUTO)
        sys.exit(0)

    if "--lista" in sys.argv:
        print("Prove utilizzabili come argomenti dalla difesa:" + chr(10))
        for nome, peso in PESI.items():
            print("  %-28s peso %d" % (nome, peso))
        print(chr(10) + "Il peso e' di quanto ogni prova abbassa il valore di riserva")
        print("dell'accusa quando viene usata come argomento (Rahwan).")
        print("Sono definiti in ../src/agt/negoziazione/dnm_patteggiamento.asl")
        sys.exit(0)

    # ---- caso singolo scelto dall'utente ----
    if "--prove" in sys.argv:
        prove = leggi_prove(valore("--prove", ""))
        ris_p = int(valore("--riserva-accusa", 7))
        ris_d = int(valore("--riserva-difesa", 5))
        beta_p = float(valore("--beta-accusa", 0.4))
        beta_d = float(valore("--beta-difesa", 1.0))
        tmax = int(valore("--round", 8))
        forza = sum(PESI[p] for p in prove)

        print("Prove in mano alla difesa: %s"
              % (", ".join(prove) if prove else "nessuna"))
        print("Peso complessivo: %d   |   riserva accusa %d, riserva difesa %d, "
              "beta accusa %s, %d round" % (forza, ris_p, ris_d, beta_p, tmax) + chr(10))

        tipo, val, desc = esegui(ris_p, beta_p, ris_d, beta_d, prove,
                                 tmax=tmax, forza=forza, verbose=("-v" in sys.argv))
        print()
        if tipo == "accordo":
            print("ESITO: le parti hanno PATTEGGIATO  ->  %s  (%d su 10)" % (desc, val))
        elif tipo == "verdetto":
            print("ESITO: trattativa FALLITA, decide il tribunale  ->  %s  (%d su 10)"
                  % (desc, val))
        else:
            print("ESITO: %s - %s" % (tipo, desc))
        sys.exit(0)

    # ---- tabella completa ----
    if "-v" in sys.argv:
        print("Tracciato completo del terzo scenario (3 prove, con Alex):" + chr(10))
        nome, prove, beta_p = SCENARI[3]
        print(esegui(7, beta_p, 5, 1.0, prove,
                     forza=sum(PESI[p] for p in prove), verbose=True))
        sys.exit(0)

    print("Parametri fissi: riserva accusa 7, riserva difesa 5, 8 round.")
    print("(per un caso tuo:  python banco.py --prove alex,sullivan)" + chr(10))
    print("%-30s %-6s %-7s %-9s %-4s %s"
          % ("scenario", "prove", "beta_p", "esito", "val", "descrizione"))
    print("-" * 86)
    for nome, prove, beta_p in SCENARI:
        forza = sum(PESI[p] for p in prove)
        tipo, val, desc = esegui(7, beta_p, 5, 1.0, prove, forza=forza)
        print("%-30s %-6d %-7s %-9s %-4s %s"
              % (nome, len(prove), beta_p, tipo, val, desc))
