# -*- coding: utf-8 -*-
"""Genera le skin degli 8 personaggi a partire dalle due basi "retro" di Kenney
(addons/kenney_animated-characters-retro/Skins/humanMaleA.png e humanFemaleA.png).

    python genera_skin.py            rigenera tutti i PNG in questa cartella
    (poi:  godot --headless --import --path env/home   per farli reimportare)

COME E' FATTA LA TEXTURE (misurato sul modello, non a occhio: vedi il diario,
sezione sulle skin). Coordinate su una griglia 256x256, origine in alto a sx:

    testa      x 0-160,   y 0-120    viso al centro, nuca ai due lati
    busto      x 0-160,   y 120-256  aperto A CROCE attorno al buco del collo
                                     (80,187): la SCHIENA sta SOPRA il buco, il
                                     PETTO SOTTO. Le due braccia orizzontali
                                     sono le maniche (meta' alta = dietro,
                                     meta' bassa = davanti).
    scarpe     x 160-205, y 33-130
    gambe      x 153-256, y 190-256  blocco sinistro = davanti, destro = dietro

Le prime skin (ricolorazioni di judge.png/lawyer.png) avevano cravatta e
revers nella meta' ALTA del busto, cioe' sulla schiena: i personaggi
risultavano vestiti al contrario. Qui ogni dettaglio frontale e' disegnato
sotto il buco del collo.

Si lavora a 512x512 (le basi sono 256: ingrandite 2x) per dare un po' piu' di
definizione a cravatte, revers e bottoni.
"""
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

import sys
QUI = os.path.dirname(os.path.abspath(__file__))
# cartella di uscita: di norma questa; un argomento la cambia (per le prove)
USCITA = sys.argv[1] if len(sys.argv) > 1 else QUI
BASI = os.path.join(QUI, "..", "..", "addons", "kenney_animated-characters-retro", "Skins")
K = 2            # fattore di scala rispetto alla griglia 256
S = 256 * K
SS = 4           # supersampling delle maschere (bordi morbidi)

CX, CY = 80.0, 187.0     # centro del buco del collo


# ----------------------------------------------------------------- utilita'
def carica(nome):
    im = Image.open(os.path.join(BASI, nome)).convert("RGB").resize((S, S), Image.BICUBIC)
    return np.asarray(im).astype(np.float32)


def lum(a):
    return a[..., 0] * 0.299 + a[..., 1] * 0.587 + a[..., 2] * 0.114


def smooth(x, a, b):
    """0 quando x=a, 1 quando x=b (a e b possono essere in ordine inverso)."""
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def rett(x0, y0, x1, y1):
    m = np.zeros((S, S), np.float32)
    m[int(y0 * K):int(y1 * K), int(x0 * K):int(x1 * K)] = 1
    return m


def forma(disegna, sfuma=0.0):
    """Maschera 0..1 disegnata con PIL in coordinate 256, con bordi morbidi."""
    im = Image.new("L", (S * SS, S * SS), 0)
    d = ImageDraw.Draw(im)
    f = K * SS
    disegna(d, f)
    im = im.resize((S, S), Image.LANCZOS)
    if sfuma > 0:
        im = im.filter(ImageFilter.GaussianBlur(sfuma * K))
    return np.asarray(im).astype(np.float32) / 255.0


def poli(punti):
    return forma(lambda d, f: d.polygon([(x * f, y * f) for x, y in punti], fill=255))


def cerchio(x, y, r, sfuma=0.0):
    return forma(lambda d, f: d.ellipse([(x - r) * f, (y - r) * f, (x + r) * f, (y + r) * f], fill=255), sfuma)


def linea(punti, spessore, sfuma=0.0):
    return forma(lambda d, f: d.line([(x * f, y * f) for x, y in punti], fill=255,
                                     width=max(1, int(spessore * f)), joint="curve"), sfuma)


def mescola(img, colore, maschera):
    m = np.clip(maschera, 0, 1)[..., None]
    return img * (1 - m) + np.asarray(colore, np.float32) * m


def scurisci(img, maschera, quanto):
    return img * (1 - np.clip(maschera, 0, 1)[..., None] * quanto)


def tinta(img, zona, colore, rif=228.0, gamma=1.0, minimo=0.0):
    """Ricolora un tessuto conservandone le pieghe: la luminosita' originale
    (pieghe, ombre) modula il colore nuovo."""
    l = np.clip(lum(img) / rif, 0, 1.15) ** gamma
    l = minimo + (1 - minimo) * l
    nuovo = l[..., None] * np.asarray(colore, np.float32)
    z = np.clip(zona, 0, 1)[..., None]
    return img * (1 - z) + nuovo * z


# --------------------------------------------------------------- le regioni
R_TESTA = rett(0, 0, 160, 120)
R_BUSTO = rett(0, 120, 160, 256)
R_SCARPE = rett(160, 33, 205, 130)
R_GAMBE = rett(153, 190, 256, 256)
R_GAMBE_DAVANTI = rett(153, 190, 205, 256)


def maschera_capelli(img, donna):
    """Quanto ogni pixel della testa e' capelli (o barba). I capelli sono scuri,
    la pelle chiara: basta la luminosita', proteggendo occhi e bocca."""
    L = lum(img)
    cap = smooth(L, 150, 95) * R_TESTA
    # Posizioni misurate sulle basi: occhi a (72.5, 54) e (86.5, 54), bocca a
    # (80, 69). Le protezioni sono ellissi SFUMATE: un rettangolo netto lasciava
    # attorno agli occhi un alone che sul modello sembrava un paio di occhiali.
    occhi = forma(lambda d, f: (d.ellipse([67.5 * f, 51 * f, 77.5 * f, 57 * f], fill=255),
                                d.ellipse([81.5 * f, 51 * f, 91.5 * f, 57 * f], fill=255)), 0.8)
    bocca = forma(lambda d, f: d.ellipse([73 * f, 66 * f, 87 * f, 72 * f], fill=255), 0.8)
    if donna:
        # naso, guance e labbra hanno ombre scure che non sono capelli
        centro = forma(lambda d, f: d.ellipse([66 * f, 55 * f, 94 * f, 76 * f], fill=255), 1.5)
        cap = cap * (1 - centro)
        barba = np.zeros_like(cap)
    else:
        zona_barba = forma(lambda d, f: d.ellipse([52 * f, 59 * f, 108 * f, 106 * f], fill=255), 2.0)
        barba = smooth(L, 178, 128) * zona_barba * (1 - bocca * 0.85)
        cap = cap * (1 - zona_barba)
    cap = cap * (1 - occhi)
    barba = barba * (1 - occhi)
    return cap, barba


def occhiali(img, colore=(44, 38, 36)):
    """Montatura sottile: due lenti, ponte e stanghette fino alle orecchie."""
    def lente(cx):
        return forma(lambda d, f: d.rounded_rectangle([(cx - 5.6) * f, 50.2 * f, (cx + 5.6) * f, 58.2 * f],
                                                      radius=2.6 * f, outline=255, width=int(0.9 * f)))
    m = lente(72.5) + lente(86.5)
    m = m + linea([(78.1, 53.6), (80.9, 53.6)], 0.9)
    m = m + linea([(66.9, 53.4), (47, 56.5)], 0.9) + linea([(92.1, 53.4), (112, 56.5)], 0.9)
    img = mescola(img, (255, 255, 255), (cerchio(70.5, 52.6, 1.1, 0.5) + cerchio(84.5, 52.6, 1.1, 0.5)) * 0.25)
    return mescola(img, colore, np.clip(m, 0, 1))


def colora_capelli(img, maschera, colore, chiaro=False):
    L = lum(img)
    if chiaro:      # grigi/bianchi: le ciocche devono restare leggibili
        f = 0.62 + 0.55 * np.clip((L - 30) / 90, 0, 1)
    else:
        f = 0.55 + 0.75 * np.clip((L - 30) / 90, 0, 1)
    nuovo = f[..., None] * np.asarray(colore, np.float32)
    m = maschera[..., None]
    return img * (1 - m) + nuovo * m


def colore_pelle(img):
    """Tono della pelle, letto sul dorso del naso (76-84, 59-63). Un primo
    campione preso piu' in alto cadeva nei capelli: 'radere' voleva dire
    dipingere di marrone, e lo scollo di Alex usciva nero."""
    return np.median(img[int(59 * K):int(63 * K), int(76 * K):int(84 * K)].reshape(-1, 3), axis=0)


def rasa(img, barba, quanto):
    """Toglie (in parte) la barba riportando la pelle, con un'ombra leggera."""
    pelle = colore_pelle(img)
    return mescola(img, pelle * 0.95, barba * quanto)


# ------------------------------------------------------------ pezzi d'abito
def colletto(img, colore, r_int=5.0, r_est=9.5):
    """Anello attorno al buco del collo: colletto della camicia."""
    anello = cerchio(CX, CY, r_est) * (1 - cerchio(CX, CY, r_int))
    img = scurisci(img, cerchio(CX, CY, r_est + 1.5, 0.8) * (1 - cerchio(CX, CY, r_est)), 0.35)
    return mescola(img, colore, anello)


def scollo_v(apice_y, mezza_larghezza=10.0):
    return poli([(CX - mezza_larghezza, CY + 1), (CX + mezza_larghezza, CY + 1), (CX, apice_y)])


def completo(img, giacca, camicia, cravatta, apice=233.0, righe=False, pochette=None):
    """Giacca con revers, camicia e cravatta: tutto SOTTO il collo (= davanti)."""
    img = tinta(img, R_BUSTO, giacca, gamma=1.25, minimo=0.25)
    if righe:      # gessato appena accennato
        yy, xx = np.mgrid[0:S, 0:S]
        riga = ((xx % (6 * K)) < 1).astype(np.float32) * R_BUSTO
        img = mescola(img, np.asarray(giacca) * 1.6 + 25, riga * 0.35)
    v = scollo_v(apice, 11.0)
    # ombra che la giacca fa sulla camicia
    img = mescola(img, camicia, v)
    img = scurisci(img, (linea([(CX - 11, CY + 1), (CX, apice)], 2.2, 1.0) +
                         linea([(CX + 11, CY + 1), (CX, apice)], 2.2, 1.0)) * v, 0.28)
    # revers: due lembi piu' chiari lungo lo scollo, con la tacca
    chiaro = np.clip(np.asarray(giacca, np.float32) * 1.35 + 14, 0, 255)
    rev_sx = poli([(CX - 11, CY + 1), (CX - 19, CY + 3), (CX - 17, CY + 15), (CX - 13.5, CY + 17), (CX - 1, apice)])
    rev_dx = poli([(CX + 11, CY + 1), (CX + 19, CY + 3), (CX + 17, CY + 15), (CX + 13.5, CY + 17), (CX + 1, apice)])
    img = mescola(img, chiaro, (rev_sx + rev_dx) * 0.85)
    bordo = (linea([(CX - 19, CY + 3), (CX - 17, CY + 15), (CX - 13.5, CY + 17), (CX - 1, apice)], 0.9, 0.4) +
             linea([(CX + 19, CY + 3), (CX + 17, CY + 15), (CX + 13.5, CY + 17), (CX + 1, apice)], 0.9, 0.4))
    img = scurisci(img, bordo, 0.45)
    img = colletto(img, camicia)
    if cravatta is not None:
        nodo = poli([(CX - 3.4, CY + 8), (CX + 3.4, CY + 8), (CX + 2.2, CY + 13.5), (CX - 2.2, CY + 13.5)])
        corpo = poli([(CX - 2.2, CY + 13.5), (CX + 2.2, CY + 13.5), (CX + 3.6, apice - 8),
                      (CX, apice - 3), (CX - 3.6, apice - 8)])
        img = mescola(img, cravatta, corpo * v)
        img = mescola(img, np.asarray(cravatta, np.float32) * 0.78, nodo)
        img = scurisci(img, linea([(CX + 1.6, CY + 14), (CX + 2.8, apice - 9)], 1.0, 0.5) * corpo, 0.22)
    # bottoni sotto l'apice
    for by in (apice + 5, apice + 12):
        if by < 252:
            img = mescola(img, np.asarray(giacca, np.float32) * 0.45, cerchio(CX, by, 1.5))
            img = mescola(img, chiaro, cerchio(CX - 0.4, by - 0.4, 0.55) * 0.7)
    # linea di chiusura della giacca
    img = scurisci(img, linea([(CX, apice), (CX, 256)], 0.8, 0.4), 0.35)
    if pochette is not None:
        img = mescola(img, pochette, poli([(CX + 14, CY + 22), (CX + 21, CY + 21), (CX + 21, CY + 24), (CX + 14, CY + 25)]))
        img = scurisci(img, linea([(CX + 13.5, CY + 25.5), (CX + 21.5, CY + 24.5)], 0.8, 0.3), 0.4)
    return img


def polsini_e_orlo(img, colore, orlo=True):
    """Bordino a costine in fondo alle maniche e in vita: maglioni e felpe."""
    m = rett(8, 165, 12.5, 204) + rett(147.5, 165, 152, 204)
    if orlo:
        m = m + rett(53, 247, 107, 256) + rett(53, 120, 107, 128)
    img = mescola(img, colore, np.clip(m, 0, 1) * 0.8)
    yy, xx = np.mgrid[0:S, 0:S]
    costine = ((xx % (2 * K)) < 1).astype(np.float32) * (rett(53, 247, 107, 256) + rett(53, 120, 107, 128))
    costine = costine + ((yy % (2 * K)) < 1).astype(np.float32) * (rett(8, 165, 12.5, 204) + rett(147.5, 165, 152, 204))
    return scurisci(img, costine, 0.18)


def pantaloni(img, colore, gamma=1.0, lunghi_da_donna=False):
    if lunghi_da_donna:     # la base donna ha i pantaloni al polpaccio: li allungo
        y0, y1 = int(214 * K), int(235 * K)
        x0, x1 = int(153 * K), S
        pezzo = img[y0:y1, x0:x1][::-1]
        img = img.copy()
        img[y1:y1 + pezzo.shape[0], x0:x1] = pezzo[:S - y1]
    return tinta(img, R_GAMBE, colore, rif=150.0, gamma=gamma, minimo=0.2)


def scarpe(img, colore):
    return tinta(img, R_SCARPE, colore, rif=245.0, gamma=1.6, minimo=0.12)


def salva(img, nome):
    Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)).save(os.path.join(USCITA, nome))
    print("  creata", nome)


# ------------------------------------------------------------ i personaggi
def base(donna=False, busto_uomo=False):
    img = carica("humanFemaleA.png" if donna else "humanMaleA.png")
    if donna and busto_uomo:
        # maniche lunghe: il tessuto del busto maschile copre tutta la croce
        uomo = carica("humanMaleA.png")
        m = R_BUSTO[..., None]
        img = img * (1 - m) + uomo * m
    return img


def bob():
    """L'imputato: uno qualunque. Maglione blu-grigio su camicia, jeans."""
    img = base()
    cap, barba = maschera_capelli(img, False)
    img = rasa(img, barba, 0.55)                       # barba di due giorni
    img = colora_capelli(img, cap, (88, 62, 44))
    maglione = (78, 98, 124)
    img = tinta(img, R_BUSTO, maglione, gamma=1.15, minimo=0.3)
    img = polsini_e_orlo(img, np.asarray(maglione) * 0.8)
    # girocollo a costine e punte del colletto della camicia
    img = mescola(img, np.asarray(maglione) * 0.78, cerchio(CX, CY, 11.5) * (1 - cerchio(CX, CY, 8.0)))
    img = colletto(img, (232, 236, 240), 5.0, 8.0)
    img = mescola(img, (232, 236, 240), poli([(CX - 7.5, CY + 4), (CX - 1, CY + 7), (CX - 4.5, CY + 13)]))
    img = mescola(img, (232, 236, 240), poli([(CX + 7.5, CY + 4), (CX + 1, CY + 7), (CX + 4.5, CY + 13)]))
    img = scarpe(img, (236, 236, 236))
    salva(img, "bob.png")


def sullivan():
    """Il vicino anziano: capelli e barba grigi, cardigan tabacco aperto su una
    camicia chiara, pantaloni di velluto marroni."""
    img = base()
    cap, barba = maschera_capelli(img, False)
    img = colora_capelli(img, cap, (196, 196, 200), chiaro=True)
    img = colora_capelli(img, barba * 0.85, (205, 205, 208), chiaro=True)
    img = occhiali(img)
    cardigan = (142, 104, 66)
    img = tinta(img, R_BUSTO, cardigan, gamma=1.1, minimo=0.3)
    # trama a maglia: righine verticali leggere
    yy, xx = np.mgrid[0:S, 0:S]
    img = scurisci(img, ((xx % (3 * K)) < 1).astype(np.float32) * R_BUSTO, 0.10)
    # apertura: camicia a quadretti visibile al centro, dal collo all'orlo
    camicia = (226, 220, 204)
    apertura = poli([(CX - 9, CY + 1), (CX + 9, CY + 1), (CX + 4, CY + 26), (CX + 4, 256), (CX - 4, 256), (CX - 4, CY + 26)])
    img = mescola(img, camicia, apertura)
    quadretti = (((xx % (4 * K)) < 1) | ((yy % (4 * K)) < 1)).astype(np.float32)
    img = mescola(img, (150, 120, 96), quadretti * apertura * 0.45)
    # bordo a costine del cardigan e bottoni
    bordo = (linea([(CX - 9, CY + 1), (CX - 4, CY + 26), (CX - 4, 256)], 3.0) +
             linea([(CX + 9, CY + 1), (CX + 4, CY + 26), (CX + 4, 256)], 3.0))
    img = mescola(img, np.asarray(cardigan) * 0.72, np.clip(bordo, 0, 1))
    for by in (CY + 30, CY + 41, CY + 52):
        img = mescola(img, (70, 48, 30), cerchio(CX + 4.3, by, 1.3))
    img = colletto(img, camicia, 5.0, 9.0)
    img = polsini_e_orlo(img, np.asarray(cardigan) * 0.72, orlo=False)
    img = pantaloni(img, (118, 92, 66), gamma=0.9)
    img = scarpe(img, (96, 62, 38))
    salva(img, "sullivan.png")


def alex():
    """Alex e' una DONNA: impiegata NovaTech. Camicetta petrolio a maniche
    lunghe con scollo a V, cartellino aziendale al collo, pantaloni scuri."""
    img = base(donna=True, busto_uomo=True)
    cap, _ = maschera_capelli(img, True)
    img = colora_capelli(img, cap, (46, 36, 32))
    blusa = (40, 118, 128)
    img = tinta(img, R_BUSTO, blusa, gamma=1.15, minimo=0.3)
    # scollo a V con la pelle, colletto morbido
    pelle = colore_pelle(img)
    v = scollo_v(CY + 19, 8.0)
    img = mescola(img, pelle, np.clip(v + cerchio(CX, CY, 7.0), 0, 1))
    img = scurisci(img, cerchio(CX, CY + 3, 6.0, 1.5) * v, 0.10)
    chiaro = np.clip(np.asarray(blusa, np.float32) * 1.3 + 12, 0, 255)
    img = mescola(img, chiaro, poli([(CX - 8, CY + 1), (CX - 14, CY + 3), (CX - 9, CY + 14), (CX - 0.5, CY + 19)]) * 0.9)
    img = mescola(img, chiaro, poli([(CX + 8, CY + 1), (CX + 14, CY + 3), (CX + 9, CY + 14), (CX + 0.5, CY + 19)]) * 0.9)
    img = mescola(img, chiaro, (cerchio(CX, CY, 11.0) * (1 - cerchio(CX, CY, 7.0))) * rett(0, 0, 160, CY) * 0.9)
    # abbottonatura
    img = scurisci(img, linea([(CX, CY + 19), (CX, 256)], 0.8, 0.3), 0.3)
    for by in (CY + 27, CY + 37, CY + 47, CY + 57):
        img = mescola(img, (225, 235, 236), cerchio(CX, by, 1.0))
    # cartellino: laccetto a V e tessera
    laccio = linea([(CX - 6.5, CY + 2), (CX - 9, CY + 30)], 1.1) + linea([(CX + 6.5, CY + 2), (CX - 7, CY + 30)], 1.1)
    img = mescola(img, (26, 30, 46), np.clip(laccio, 0, 1))
    tessera = poli([(CX - 13, CY + 30), (CX - 4, CY + 30), (CX - 4, CY + 42), (CX - 13, CY + 42)])
    img = scurisci(img, forma(lambda d, f: d.rectangle([(CX - 13.5) * f, (CY + 30.5) * f, (CX - 3.5) * f, (CY + 43) * f], fill=255), 0.8), 0.3)
    img = mescola(img, (244, 244, 240), tessera)
    img = mescola(img, (30, 110, 170), poli([(CX - 13, CY + 30), (CX - 4, CY + 30), (CX - 4, CY + 33), (CX - 13, CY + 33)]))
    img = mescola(img, (214, 170, 140), cerchio(CX - 10.3, CY + 36.5, 1.5))
    img = mescola(img, (120, 124, 132), linea([(CX - 8, CY + 36), (CX - 5, CY + 36)], 0.7))
    img = mescola(img, (120, 124, 132), linea([(CX - 8, CY + 38), (CX - 5.5, CY + 38)], 0.7))
    # polsini
    img = mescola(img, chiaro, (rett(8, 165, 12, 204) + rett(148, 165, 152, 204)) * 0.9)
    img = pantaloni(img, (44, 46, 58), gamma=1.1, lunghi_da_donna=True)
    img = scarpe(img, (40, 36, 36))
    salva(img, "alex.png")


def jefferson():
    """Il direttore della NovaTech: completo antracite gessato, cravatta
    bronzo, pochette, capelli brizzolati, barba grigia curata."""
    img = base()
    cap, barba = maschera_capelli(img, False)
    img = colora_capelli(img, cap, (128, 126, 128), chiaro=True)
    img = colora_capelli(img, barba * 0.85, (150, 148, 148), chiaro=True)
    img = completo(img, (54, 58, 68), (240, 240, 236), (168, 118, 44), righe=True, pochette=(236, 232, 220))
    img = pantaloni(img, (52, 56, 66), gamma=1.1)
    img = scarpe(img, (34, 28, 26))
    salva(img, "jefferson.png")


def chloe():
    """La barista: maglietta panna a maniche corte, grembiule bordeaux con
    pettorina e tasca, capelli ramati."""
    img = base(donna=True)
    cap, _ = maschera_capelli(img, True)
    img = colora_capelli(img, cap, (158, 74, 38))
    # la maglietta della base e' gia' chiara: la scaldo appena
    L = lum(img)
    sat = img.max(-1) - img.min(-1)
    maglia = smooth(sat, 46, 26) * smooth(L, 150, 185) * R_BUSTO
    img = tinta(img, maglia, (244, 236, 220), gamma=1.0, minimo=0.2)
    bordeaux = (122, 34, 46)
    # pettorina sul PETTO (sotto il collo) e falda fino in vita
    pett = poli([(CX - 11, CY + 14), (CX + 11, CY + 14), (CX + 20, CY + 36), (CX + 26, 256), (CX - 26, 256), (CX - 20, CY + 36)])
    ombra = poli([(CX - 12, CY + 13), (CX + 12, CY + 13), (CX + 21.5, CY + 36), (CX + 27.5, 256), (CX - 27.5, 256), (CX - 21.5, CY + 36)])
    img = scurisci(img, ombra * (1 - pett), 0.3)
    pieghe = np.clip(lum(img) / 228.0, 0, 1.1) ** 1.2
    img = img * (1 - pett[..., None]) + ((0.3 + 0.7 * pieghe)[..., None] * np.asarray(bordeaux, np.float32)) * pett[..., None]
    # bordo superiore e lacci dietro il collo
    scuro = np.asarray(bordeaux) * 0.65
    img = mescola(img, scuro, linea([(CX - 11, CY + 14.5), (CX + 11, CY + 14.5)], 1.6))
    lacci = (linea([(CX - 10, CY + 14), (CX - 7, CY + 2), (CX - 7.5, CY - 5), (CX, CY - 9), (CX + 7.5, CY - 5), (CX + 7, CY + 2), (CX + 10, CY + 14)], 1.7))
    img = mescola(img, scuro, lacci * (1 - cerchio(CX, CY, 5.0)))
    # fascia in vita che gira dietro (sulla schiena = sopra il collo, specchiata)
    img = mescola(img, scuro, rett(53, 135.5, 107, 138.5))
    img = mescola(img, scuro, linea([(CX - 21, CY + 38), (CX + 21, CY + 38)], 1.4))
    # tasca
    tasca = poli([(CX - 9, CY + 44), (CX + 9, CY + 44), (CX + 9, CY + 56), (CX, CY + 59), (CX - 9, CY + 56)])
    img = scurisci(img, tasca, 0.16)
    img = scurisci(img, linea([(CX - 9, CY + 44), (CX + 9, CY + 44), (CX + 9, CY + 56), (CX, CY + 59), (CX - 9, CY + 56), (CX - 9, CY + 44)], 0.8, 0.3), 0.35)
    # Il grembiule si ferma in vita. Una prima versione lo faceva scendere sul
    # davanti delle gambe, ma le due gambe sono mappate separatamente e sul
    # modello diventava una salopette a pantaloncino.
    img = pantaloni(img, (38, 38, 44), gamma=1.1, lunghi_da_donna=True)
    img = scarpe(img, (236, 236, 236))
    salva(img, "chloe.png")


def finn():
    """L'ex collega indebitato e nervoso: barba incolta, felpa col cappuccio
    oliva sbiadita con tascone e laccetti, jeans grigi consumati."""
    img = base()
    cap, barba = maschera_capelli(img, False)
    img = colora_capelli(img, cap, (40, 32, 28))
    img = colora_capelli(img, barba, (58, 46, 40))
    felpa = (104, 110, 78)
    img = tinta(img, R_BUSTO, felpa, gamma=1.3, minimo=0.25)
    scuro = np.asarray(felpa) * 0.7
    # cappuccio abbassato: sulla SCHIENA (sopra il collo)
    capp = forma(lambda d, f: d.pieslice([(CX - 22) * f, (CY - 34) * f, (CX + 22) * f, (CY + 6) * f], 180, 360, fill=255))
    img = scurisci(img, forma(lambda d, f: d.pieslice([(CX - 24) * f, (CY - 37) * f, (CX + 24) * f, (CY + 6) * f], 180, 360, fill=255), 1.2) * (1 - capp), 0.3)
    img = mescola(img, np.asarray(felpa) * 0.86, capp * 0.9)
    img = scurisci(img, linea([(CX, CY - 33), (CX, CY - 8)], 0.8, 0.4), 0.3)
    # bordo del collo, laccetti sul davanti
    img = mescola(img, scuro, cerchio(CX, CY, 10.5) * (1 - cerchio(CX, CY, 6.0)))
    img = mescola(img, (222, 220, 205), linea([(CX - 4.5, CY + 8), (CX - 5.5, CY + 25)], 1.0))
    img = mescola(img, (222, 220, 205), linea([(CX + 4.5, CY + 8), (CX + 5.5, CY + 22)], 1.0))
    # tascone a marsupio
    tasca = poli([(CX - 15, CY + 44), (CX + 15, CY + 44), (CX + 20, CY + 60), (CX - 20, CY + 60)])
    img = scurisci(img, tasca, 0.14)
    img = scurisci(img, linea([(CX - 20, CY + 60), (CX - 15, CY + 44), (CX + 15, CY + 44), (CX + 20, CY + 60)], 0.9, 0.3), 0.4)
    img = polsini_e_orlo(img, scuro)
    # macchia scolorita: la felpa ha visto giorni migliori
    img = mescola(img, np.asarray(felpa) * 1.18 + 8, cerchio(CX + 12, CY + 30, 6.0, 3.0) * 0.35)
    img = pantaloni(img, (108, 110, 116), gamma=0.9)
    img = scarpe(img, (120, 112, 100))
    salva(img, "finn.png")


def giudice():
    """Toga nera con le due facciole bianche sul petto, capelli e barba bianchi."""
    img = base()
    cap, barba = maschera_capelli(img, False)
    img = colora_capelli(img, cap, (224, 224, 226), chiaro=True)
    img = colora_capelli(img, barba * 0.9, (232, 232, 232), chiaro=True)
    toga = (30, 30, 36)
    img = tinta(img, R_BUSTO, toga, gamma=1.2, minimo=0.45)
    # pieghe verticali della toga, davanti e dietro
    yy, xx = np.mgrid[0:S, 0:S]
    pieghe = ((xx % (7 * K)) < K).astype(np.float32) * rett(53, 120, 107, 256)
    img = mescola(img, (64, 64, 74), pieghe * 0.5)
    # sprone sulle spalle
    img = mescola(img, (52, 52, 62), cerchio(CX, CY, 19.0) * (1 - cerchio(CX, CY, 17.5)) * 0.9)
    bianco = (240, 240, 236)
    img = colletto(img, bianco, 5.0, 9.0)
    # le due facciole: sul PETTO, sotto il collo
    for dx in (-3.4, 0.6):
        f_ = poli([(CX + dx, CY + 7), (CX + dx + 2.8, CY + 7), (CX + dx + 3.4, CY + 25), (CX + dx - 0.6, CY + 25)])
        img = scurisci(img, forma(lambda d, f, dx=dx: d.rectangle([(CX + dx - 1) * f, (CY + 7) * f, (CX + dx + 4) * f, (CY + 26.5) * f], fill=255), 0.8) * (1 - f_), 0.3)
        img = mescola(img, bianco, f_)
    img = pantaloni(img, (28, 28, 34), gamma=1.1)
    img = scarpe(img, (22, 22, 24))
    salva(img, "judge.png")


def procuratore():
    """L'accusa: completo blu notte, camicia bianca, cravatta bordeaux, rasato."""
    img = base()
    cap, barba = maschera_capelli(img, False)
    img = rasa(img, barba, 0.92)
    img = colora_capelli(img, cap, (30, 26, 26))
    img = completo(img, (34, 48, 84), (242, 242, 240), (134, 30, 44))
    img = pantaloni(img, (32, 44, 76), gamma=1.1)
    img = scarpe(img, (24, 22, 22))
    salva(img, "lawyer.png")


if __name__ == "__main__":
    print("Genero le skin in", USCITA)
    for f in (bob, sullivan, alex, jefferson, chloe, finn, giudice, procuratore):
        f()
    print("fatto")
