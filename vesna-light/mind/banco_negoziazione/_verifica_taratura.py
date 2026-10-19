# -*- coding: utf-8 -*-
"""Verifica la taratura eseguendo i file di PRODUZIONE, profilo per profilo.
Scrive i risultati man mano, cosi' si possono leggere anche a meta' corsa."""
import io, os, re, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _prova_reali

CASI = [
    ("tirato dritto",  [], "aaa"),
    ("appena passato", ["sullivan"], "baa"),
    ("mezzo lavoro",   ["sullivan", "movente_finn"], "baa"),
    ("discreto",       ["sullivan", "movente_finn", "alex"], "bba"),
    ("buono",          ["confessione", "sullivan", "alex",
                        "contraddizione_jefferson"], "bbb"),
    ("tutto",          ["confessione", "sullivan", "movente_finn", "alex",
                        "contraddizione_jefferson", "prova_fisica"], "bbb"),
]

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "_risultati.txt")


def scrivi(riga):
    with io.open(OUT, "a", encoding="utf-8") as f:
        f.write(riga + "\n")
    print(riga, flush=True)


if __name__ == "__main__":
    io.open(OUT, "w", encoding="utf-8").write("")
    scrivi("%-16s %-9s %-4s %-22s %s" % ("profilo", "esito", "val", "descrizione", "ris.difesa"))
    scrivi("-" * 78)
    for nome, prove, risp in CASI:
        out = _prova_reali.esegui(prove, risp)
        m = re.search(r"\[ESITO\] (\w+) esito=(\d+) \(([^)]*)\)", out)
        d = re.search(r"non accetto oltre (\d+)", out)
        if m:
            scrivi("%-16s %-9s %-4s %-22s %s"
                   % (nome, m.group(1), m.group(2), m.group(3), d.group(1) if d else "-"))
        else:
            scrivi("%-16s ERRORE: %s" % (nome, out.strip().splitlines()[-1][:60] if out.strip() else "nessun output"))
