# -*- coding: utf-8 -*-
"""Esegue i file di PRODUZIONE (giudice/procuratore/difesa.asl) come li carica
il gioco, simulando anche i click del giocatore durante l'udienza.

Serve a verificare il collegamento e il percorso completo udienza -> trattativa,
non a tarare il modello (per quello c'e' banco.py).

    python _prova_reali.py alex,sullivan bbb    prove + risposte tutte giuste
    python _prova_reali.py alex,sullivan aaa    stesse prove, risposte sbagliate
    python _prova_reali.py "" bbb               nessuna prova
"""
import io
import os
import re
import shutil
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import banco

QUI = os.path.dirname(os.path.abspath(__file__))
AGT = os.path.join(QUI, "..", "src", "agt")
LAV = os.path.join(QUI, "_lavoro_reali")

# Attese tarate sui .wait dei piani di giudice.asl: ogni click va iniettato
# DOPO che il giudice ha finito di parlare e ha posto la domanda.
TEMPI = {"processo": 1000, "deposito": 3000, "r1": 11000, "r2": 18000, "r3": 25000}

SIMULA = """
!simula_giocatore.
+!simula_giocatore
    <-  .wait( {t0} ); +processo( iniziato, banco );
        .wait( {t1} ); +user_message( deposita_prove, clicked );
        .wait( {t2} ); +user_message( ud_r1{a1}, clicked );
        .wait( {t3} ); +user_message( ud_r2{a2}, clicked );
        .wait( {t4} ); +user_message( ud_r3{a3}, clicked ).
"""


def iniezione_prove(prove):
    """Consegna le prove come EVENTI, con lo stesso effetto dei messaggi che in
    partita arrivano dall'inventario di Godot.

    Non vanno messe come credenze iniziali: in Jason una credenza dichiarata nel
    file finisce nella base SENZA far scattare alcun piano, quindi il giudice non
    conterebbe il peso delle prove e la difesa resterebbe senza munizioni."""
    if not prove:
        return "\n"
    corpo = "; ".join("+prova_raccolta(%s, ottenuta)" % p for p in prove)
    # niente "true" in coda: senza ambiente configurato Jason lo tratta come
    # un'azione esterna e il piano fallisce, riempiendo la console di errori
    return ("\n!consegna_prove.\n"
            "+!consegna_prove <- .wait(400); %s.\n" % corpo)


def prepara(prove, risposte):
    banco.chiudi_java_rimasti()
    _chiudi_java_banco()
    if os.path.isdir(LAV):
        for _ in range(6):
            try:
                shutil.rmtree(LAV)
                break
            except PermissionError:
                time.sleep(1)
    os.makedirs(LAV, exist_ok=True)
    shutil.copytree(os.path.join(AGT, "negoziazione"),
                    os.path.join(LAV, "negoziazione"), dirs_exist_ok=True)

    for f in ["giudice.asl", "procuratore.asl", "difesa.asl"]:
        s = io.open(os.path.join(AGT, f), encoding="utf-8").read()
        # fuori dal gioco non c'e' vesna.asl (RCC + movimento) ne' il corpo in
        # Godot: le azioni interne che parlano a schermo diventano stampe.
        s = s.replace('{ include( "vesna.asl" ) }', "!start.")
        s = s.replace("vesna.via.speak(", '.print("[UDIENZA] ", ')
        # Le pause servono a chi legge a schermo, non a un test automatico:
        # accorciandole un giro passa da ~90 secondi a una ventina. Non
        # toccano l'ESITO, solo il ritmo con cui le battute si susseguono.
        # La pausa e' proporzionale alla lunghezza della battuta
        # (vedi !pausa_di_lettura in giudice.asl): qui la azzero.
        s = s.replace("Attesa = 2000 + N * 45", "Attesa = 20")
        # Il MAS di produzione non si ferma da solo (in partita deve
        # restare vivo): qui lo faccio terminare appena c'e' il verdetto,
        # altrimenti ogni prova arriva al timeout e il banco si impianta.
        # Il marcatore e' [FINE:tono] (vittoria/parziale/sconfitta): lo si
        # riconosce con un'espressione regolare, non piu' con "[FINE]" secco.
        s = re.sub(r'(\[FINE:\w+\]")\)', r'\1); .wait(300); .stopMAS', s)
        io.open(os.path.join(LAV, f), "w", encoding="utf-8").write(s)

    _accoda("difesa.asl", iniezione_prove(prove))
    _accoda("giudice.asl", iniezione_prove(prove) + SIMULA.format(
        t0=TEMPI["processo"],
        t1=TEMPI["deposito"] - TEMPI["processo"],
        t2=TEMPI["r1"] - TEMPI["deposito"], a1=risposte[0],
        t3=TEMPI["r2"] - TEMPI["r1"], a2=risposte[1],
        t4=TEMPI["r3"] - TEMPI["r2"], a3=risposte[2]))

    io.open(os.path.join(LAV, "banco.mas2j"), "w", encoding="utf-8").write(
        "MAS reali {\n    agents:\n        giudice giudice.asl;\n"
        "        procuratore procuratore.asl;\n        difesa difesa.asl;\n}\n")
    # logging.properties lo scrive banco.prepara() nella sua cartella di lavoro:
    # se quella non esiste ancora (prima esecuzione, o dopo una pulizia) la creo.
    if not os.path.exists(os.path.join(QUI, "_lavoro", "logging.properties")):
        banco.prepara()
    shutil.copy(os.path.join(QUI, "_lavoro", "logging.properties"), LAV)


def _accoda(nome, testo):
    p = os.path.join(LAV, nome)
    s = io.open(p, encoding="utf-8").read() + testo
    io.open(p, "w", encoding="utf-8").write(s)


def _chiudi_java_banco():
    subprocess.run(["powershell", "-NoProfile", "-Command",
                    "Get-CimInstance Win32_Process -Filter \"Name='java.exe'\" | "
                    "Where-Object { $_.CommandLine -like '*banco.mas2j*' } | "
                    "ForEach-Object { Stop-Process -Id $_.ProcessId -Force }"],
                   capture_output=True)
    time.sleep(1.0)


def esegui(prove, risposte="bbb", timeout=150):
    prepara(prove, risposte)
    p = subprocess.Popen(
        ["java", "-Djava.util.logging.config.file=logging.properties",
         "-cp", banco.classpath(), "jason.infra.local.RunLocalMAS", "banco.mas2j"],
        cwd=LAV, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    try:
        out, _ = p.communicate(timeout=timeout)
    except subprocess.TimeoutExpired:
        p.kill()
        out, _ = p.communicate()
        out += chr(10) + "[TIMEOUT]"
    return out


if __name__ == "__main__":
    prove = [x for x in (sys.argv[1] if len(sys.argv) > 1 else "").split(",") if x]
    risposte = sys.argv[2] if len(sys.argv) > 2 else "bbb"
    print("prove: %s   risposte: %s" % (prove or "nessuna", risposte))
    out = esegui(prove, risposte)
    for l in out.splitlines():
        if re.search(r"UDIENZA|AULA|ESITO|GIUDICE|PROCURATORE|DIFESA|TIMEOUT|error", l, re.I) \
                and not re.search(r"jason\.jar|Classpath|Config", l):
            print("  " + l.strip())
