# -*- coding: utf-8 -*-
"""Taratura del processo: prova una serie di PROFILI DI GIOCATORE (quante prove
ha raccolto e quante risposte ha azzeccato) e mostra che esito ottiene ciascuno.

Serve a rispondere a una domanda sola: giocare meglio porta davvero a un
finale migliore, o gli esiti si schiacciano tutti nella stessa fascia?

    python taratura.py           profili con i parametri attuali
    python taratura.py --prova   confronta i parametri attuali con quelli nuovi
"""
import io
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import banco

PESI = banco.PESI

# Profili realistici, dal giocatore che ha tirato dritto a quello che ha fatto
# tutto. "risposte" = quante delle tre domande dell'udienza ha azzeccato.
PROFILI = [
    ("tirato dritto",        [], 0),
    ("appena passato",       ["sullivan"], 1),
    ("mezzo lavoro",         ["sullivan", "movente_finn"], 1),
    ("discreto",             ["sullivan", "movente_finn", "alex"], 2),
    ("buono",                ["confessione", "sullivan", "alex",
                              "contraddizione_jefferson"], 3),
    ("quasi perfetto",       ["confessione", "sullivan", "movente_finn", "alex",
                              "contraddizione_jefferson"], 3),
    ("tutto",                list(PESI.keys()), 3),
]


class Taratura:
    """I numeri che vogliamo tarare, raccolti in un posto solo."""

    def __init__(self, nome, ris_p_base, beta_p, ris_d_base, cal_beta_d, tmax,
                 cal_ris_d=0.0):
        self.nome = nome
        self.ris_p_base = ris_p_base      # riserva di partenza dell'accusa
        self.beta_p = beta_p              # testardaggine dell'accusa
        self.ris_d_base = ris_d_base      # massimo che la difesa accetta, di base
        self.cal_beta_d = cal_beta_d      # di quanto scende beta_d per risposta giusta
        self.cal_ris_d = cal_ris_d        # di quanto scende ris_d per punto di prove
        self.tmax = tmax

    def parametri(self, credibilita, peso):
        ris_p = max(0, self.ris_p_base - credibilita)
        beta_d = round(1.0 - self.cal_beta_d * credibilita, 3)
        # Una difesa con prove schiaccianti non ha motivo di accettare un
        # patteggiamento alto: abbassa cio' che e' disposta ad accettare.
        ris_d = max(0, self.ris_d_base - int(self.cal_ris_d * peso))
        return ris_p, beta_d, ris_d


ATTUALE = Taratura("attuale", ris_p_base=7, beta_p=0.4, ris_d_base=5,
                   cal_beta_d=0.2, tmax=8, cal_ris_d=0.0)

# Proposta: la difesa diventa piu' Boulware quando ha fatto bene in udienza,
# e abbassa cio' che accetterebbe quando ha prove pesanti in mano.
PROPOSTA = Taratura("proposta", ris_p_base=7, beta_p=0.4, ris_d_base=5,
                    cal_beta_d=0.25, tmax=8, cal_ris_d=1.0/3)


def prova(t, profili=PROFILI):
    righe = []
    for nome, prove, cred in profili:
        forza = sum(PESI[p] for p in prove)
        ris_p, beta_d, ris_d = t.parametri(cred, forza)
        tipo, val, desc = banco.esegui(ris_p, t.beta_p, ris_d, beta_d, prove,
                                       tmax=t.tmax, forza=forza)
        righe.append((nome, len(prove), cred, forza, ris_p, ris_d, beta_d, tipo, val, desc))
    return righe


def stampa(titolo, righe):
    print()
    print(titolo)
    print("%-17s %-5s %-6s %-5s %-7s %-7s %-8s %-9s %-4s %s"
          % ("profilo", "prove", "rispo", "peso", "ris_acc", "ris_dif", "beta_dif",
             "esito", "val", "descrizione"))
    print("-" * 104)
    for r in righe:
        print("%-17s %-5d %-6d %-5d %-7d %-7d %-8s %-9s %-4d %s" % r)


if __name__ == "__main__":
    if "--prova" in sys.argv:
        stampa("PROPOSTA", prova(PROPOSTA))
    else:
        stampa("PARAMETRI ATTUALI", prova(ATTUALE))
