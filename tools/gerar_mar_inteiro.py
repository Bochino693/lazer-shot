#!/usr/bin/env python3
"""Mar com o cenário inteiro (Rodada 21).

Na Rodada 18 as duas pedras com escritas viraram planos recortados por cima
de um fundo sem elas (remendado). Com a câmera andando cada pixel pela
distância dele, o remendo aparecia nas beiradas; e as lascas, a poeira e as
bolhas do tiro na pedra saíam por baixo dela e desenhavam o recorte. Agora:

  sprites/atlantis_fundo.png   volta a ser a pintura inteira (atlantis_jogo.png):
                               a cena anda junta e a pedra é pintada com os
                               mesmos pixels do fundo (shaders/mar_pedra.gdshader
                               lê a textura do fundo), sem remendo nenhum.
                               E onde era o navio (o preenchimento deixava
                               blocos em escada, um vulto cinza e uma rocha
                               chapada atrás do templo) agora é distância de
                               água: névoa em degradê da água aberta de cima
                               até o chão, a textura de fora continuando
                               (espelhada) só perto da borda e a névoa
                               saindo suave para fora da área (sem linha de
                               corte); o chão de perto continua para trás com
                               as ondinhas; o templo e o Poseidon levam um
                               pouco de névoa (estão longe)
  sprites/mar_pedra_esq/dir.png  contorno liso (sem tufos de água e coral
                               soltos em volta): é só a forma que esconde o que
                               passa atrás da pedra
  tools/hd/atlantis_fundo@2x.png / @hd.png  a alta refeita só onde mudou
                               (EDSR, como tools/gerar_hd.py; sem o modelo,
                               Lanczos). Depois tools/gerar_hd.gd.

    MODELO=/caminho/EDSR_x2.pb python3 tools/gerar_mar_inteiro.py
"""
import os
import sys
import cv2
import numpy as np
from PIL import Image, ImageDraw

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SP = os.path.join(RAIZ, "sprites")
sys.path.insert(0, os.path.join(RAIZ, "tools"))
import gerar_hd  # noqa: E402
from gerar_camadas import espelhar_dois_lados  # noqa: E402

# tools/gerar_camadas.py MAR_PEDRAS / MAR_FOLGA
PEDRAS = [("esq", (0, 466)), ("dir", (523, 523))]
FOLGA = 24


def k(r):
    return cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (2 * r + 1, 2 * r + 1))


def maior_pedaco(m):
    n, lab, st, _ = cv2.connectedComponentsWithStats(m.astype(np.uint8), 8)
    if n <= 1:
        return m
    return (lab == 1 + int(np.argmax(st[1:, cv2.CC_STAT_AREA]))).astype(np.uint8)


def sem_furos(m):
    h, w = m.shape
    fora = np.pad(m, 1).astype(np.uint8)
    cv2.floodFill(fora, np.zeros((h + 4, w + 4), np.uint8), (0, 0), 2)
    return (fora[1:-1, 1:-1] != 2).astype(np.uint8)


def silhueta(alfa):
    """O contorno do GrabCut, alisado: um pedaço só, sem furos, sem os fiapos
    (água e folhas de coral) e com a borda de 1 px esfumada. Rodar de novo
    sobre o resultado dá o mesmo contorno."""
    m = sem_furos(maior_pedaco(alfa > 127))
    m = cv2.morphologyEx(m, cv2.MORPH_OPEN, k(10))
    m = cv2.morphologyEx(m, cv2.MORPH_CLOSE, k(9))
    m = maior_pedaco(m).astype(np.float32)
    m = (cv2.GaussianBlur(m, (0, 0), 4.0) > 0.5).astype(np.float32)
    return cv2.GaussianBlur(m, (0, 0), 0.9)


# onde era o navio (tools/gerar_mar.py NAVIO) e a rocha chapada atrás do
# templo e do Poseidon (desenhada lá para cobrir o preenchimento)
NAVIO = [(188, 538), (330, 488), (382, 452), (412, 442), (518, 435), (524, 468), (492, 570),
         (487, 632), (480, 698), (542, 762), (538, 802), (502, 872), (462, 912), (410, 934),
         (290, 934), (222, 898), (186, 770), (182, 670)]
ROCHA = [(392, 500), (470, 468), (560, 476), (648, 492), (652, 800), (540, 800), (396, 620)]
FRENTE_CANTO = (195, 530)       # scripts/mar_vida.gd FRENTE_CANTO
Y_TOPO, Y_CHAO, Y_PERTO = 440, 790, 935   # água aberta / pé do templo / chão da frente


def poli(p, forma, ss=4):
    H, W = forma
    m = Image.new("L", (W * ss, H * ss), 0)
    ImageDraw.Draw(m).polygon([(x * ss, y * ss) for x, y in p], fill=255)
    return np.asarray(m.resize((W, H), Image.LANCZOS)).astype(np.float32) / 255


def nevoa_no_lugar_do_navio(img, alfas):
    """img: RGB 0..1 (atlantis_jogo). alfas: [(alfa, (x0, y0))] das pedras."""
    H, W = img.shape[:2]
    fm = np.asarray(Image.open(os.path.join(SP, "mar_frente_navio_mascara.png")).convert("L")).astype(np.float32) / 255
    obj = np.zeros((H, W), np.float32)
    x0, y0 = FRENTE_CANTO
    obj[y0:y0 + fm.shape[0], x0:x0 + fm.shape[1]] = fm
    for a, (px, py) in alfas:
        obj[py:py + a.shape[0], px:px + a.shape[1]] = np.maximum(obj[py:py + a.shape[0], px:px + a.shape[1]], a)
    regiao = np.clip(np.maximum(cv2.dilate(poli(NAVIO, (H, W)), np.ones((7, 7))), poli(ROCHA, (H, W))), 0, 1)
    fica = np.clip(cv2.dilate(obj, np.ones((3, 3))), 0, 1)
    M = cv2.GaussianBlur(np.clip(regiao - fica, 0, 1), (0, 0), 1.2) * (1 - fica)
    reg = M > 0.02
    objb = cv2.dilate((obj > 0.3).astype(np.uint8), np.ones((3, 3), np.uint8)).astype(bool)
    # a textura de fora continuando para dentro (espelhada, sem emenda)
    esp = espelhar_dois_lados((img * 255 + 0.5).astype(np.uint8), (reg | objb).astype(np.uint8)).astype(np.float32) / 255
    # névoa: da água aberta de cima à água clara perto do chão, e no chão
    # até a cor do chão da frente
    ys = np.arange(H, dtype=np.float32)
    topo = img[395:440, 300:520].reshape(-1, 3).mean(0)
    meio = np.array([0.19, 0.60, 0.80], np.float32)
    chao = img[940:985, 330:470].reshape(-1, 3).mean(0)
    t = np.clip((ys - Y_TOPO) / (Y_CHAO - Y_TOPO), 0, 1)[:, None]
    tc = np.clip((ys - Y_CHAO) / (Y_PERTO - Y_CHAO), 0, 1)[:, None]
    nev = (topo[None] * (1 - t) + meio[None] * t) * (1 - tc) + chao[None] * tc
    nev = np.repeat(nev[:, None, :], W, axis=1)
    rng = np.random.default_rng(7)

    def fbm(escalas):
        acc = np.zeros((H, W), np.float32)
        for e, a in escalas:
            n = rng.normal(0, 1, (H // e + 3, W // e + 3)).astype(np.float32)
            acc += cv2.resize(n, (W + 3 * e, H + 3 * e), interpolation=cv2.INTER_CUBIC)[:H, :W] * a
        return acc / acc.std()
    nev = nev * (1 + 0.045 * fbm(((110, 1.0), (55, 0.6), (26, 0.3)))[..., None])
    # o chão de perto continua para trás: as ondinhas dele espelhadas para
    # cima, comprimidas pela perspectiva (só as da areia clara, nada de pedra)
    alta = img - cv2.GaussianBlur(img, (0, 0), 2.5)
    claro = np.clip((img @ np.array([0.3, 0.55, 0.15], np.float32) - 0.33) / 0.15, 0, 1)
    ond = np.zeros_like(img)
    for y in range(Y_CHAO - 10, Y_PERTO + 1):
        sy = min(int(round((Y_PERTO - 1) + ((Y_PERTO - 1) - y) * 0.55)), H - 1)
        ond[y] = alta[sy] * claro[sy][:, None]
    faixa = np.zeros((H, W), np.float32)
    faixa[:, 320:545] = 1
    faixa = cv2.GaussianBlur(faixa, (0, 0), 12)
    nev = nev + ond * (tc * 0.9)[..., None] * faixa[..., None]
    # quanto de névoa: tudo dentro (longe da borda) e saindo suave para fora
    # da área, só sobre o fundo (as coisas da frente ficam nítidas)
    sd = cv2.distanceTransform(reg.astype(np.uint8), cv2.DIST_L2, 5) - cv2.distanceTransform((~reg).astype(np.uint8), cv2.DIST_L2, 5)
    F = np.clip((sd + 40.0) / 75.0, 0, 1)
    F = F * F * (3 - 2 * F) * (1 - np.clip(obj, 0, 1))
    base = np.where(reg[..., None], esp, img)
    fim = base * (1 - F[..., None]) + nev * F[..., None]
    # o templo e o Poseidon, lá longe, levam um pouco de névoa também
    longe = np.zeros((H, W), np.float32)
    longe[470:792, 335:645] = 1
    longe = cv2.GaussianBlur(longe, (0, 0), 3) * obj
    cor_obj = img * (1 - 0.38 * longe[..., None]) + nev * (0.38 * longe[..., None])
    fim = fim * (1 - obj[..., None]) + cor_obj * obj[..., None]
    fino = cv2.GaussianBlur(rng.normal(0, 1, (H, W)).astype(np.float32), (0, 0), 0.6)
    fim = fim + 0.007 * (fino / fino.std())[..., None] * F[..., None]
    return np.clip(fim, 0, 1)


def alta_onde_mudou(orig, mudou):
    """Refaz a @2x do fundo só nos pedaços que mudaram e gera a @hd."""
    caminho = os.path.join(gerar_hd.SAIDA, "atlantis_fundo@2x.png")
    if not os.path.exists(caminho):
        print("  sem %s: rode tools/gerar_hd.py atlantis_fundo" % caminho)
        return
    alta = np.asarray(Image.open(caminho).convert("RGB")).astype(np.float32)
    sr = None
    if os.path.exists(gerar_hd.MODELO):
        sr = cv2.dnn_superres.DnnSuperResImpl_create()
        sr.readModel(gerar_hd.MODELO)
        sr.setModel("edsr", 2)
    else:
        print("  sem o modelo EDSR: Lanczos")
    H, W = mudou.shape
    peso = cv2.GaussianBlur(cv2.dilate(mudou, k(6)).astype(np.float32), (0, 0), 2.0)
    peso2 = cv2.resize(peso, (W * 2, H * 2), interpolation=cv2.INTER_LINEAR)
    n, lab, st, _ = cv2.connectedComponentsWithStats(cv2.dilate(mudou, k(12)), 8)
    for i in range(1, n):
        x, y, w, h = st[i, :4]
        x0, y0 = max(x - 24, 0), max(y - 24, 0)
        x1, y1 = min(x + w + 24, W), min(y + h + 24, H)
        pedaco = np.ascontiguousarray(orig[y0:y1, x0:x1])
        if sr is not None:
            bgr = cv2.cvtColor(pedaco, cv2.COLOR_RGB2BGR)
            up = cv2.cvtColor(gerar_hd.super_res(sr, bgr), cv2.COLOR_BGR2RGB)
        else:
            up = np.asarray(Image.fromarray(pedaco).resize(((x1 - x0) * 2, (y1 - y0) * 2), Image.LANCZOS))
        p = peso2[y0 * 2:y1 * 2, x0 * 2:x1 * 2, None]
        alta[y0 * 2:y1 * 2, x0 * 2:x1 * 2] = up.astype(np.float32) * p + alta[y0 * 2:y1 * 2, x0 * 2:x1 * 2] * (1 - p)
        print("  alta refeita em", (x0, y0, x1, y1), flush=True)
    Image.fromarray(np.clip(alta, 0, 255).astype(np.uint8)).save(caminho, optimize=True)
    gerar_hd.para_tv("atlantis_fundo")


def main():
    orig = np.asarray(Image.open(os.path.join(SP, "atlantis_jogo.png")).convert("RGB"))
    antes = np.asarray(Image.open(os.path.join(SP, "atlantis_fundo.png")).convert("RGB"))
    alfas = []
    for nome, canto in PEDRAS:
        caminho = os.path.join(SP, "mar_pedra_%s.png" % nome)
        tex = np.asarray(Image.open(caminho).convert("RGBA"))
        x0, y0 = max(canto[0] - FOLGA, 0), max(canto[1] - FOLGA, 0)
        h, w = tex.shape[:2]
        rgb = orig[y0:y0 + h, x0:x0 + w].astype(np.float32)
        alfa = silhueta(tex[..., 3])
        Image.fromarray(np.dstack([rgb, alfa * 255 + 0.5]).astype(np.uint8), "RGBA").save(caminho, optimize=True)
        alfas.append((alfa, (x0, y0)))
        print("mar_pedra_%s.png" % nome, (w, h))
    fundo = (nevoa_no_lugar_do_navio(orig.astype(np.float32) / 255, alfas) * 255 + 0.5).astype(np.uint8)
    mudou = (np.abs(antes.astype(np.int16) - fundo.astype(np.int16)).max(2) > 2).astype(np.uint8)
    Image.fromarray(fundo).save(os.path.join(SP, "atlantis_fundo.png"), optimize=True)
    print("atlantis_fundo.png: pintura inteira + névoa onde era o navio (%d px mudaram)" % int(mudou.sum()))
    if mudou.any():
        alta_onde_mudou(fundo, mudou)


if __name__ == "__main__":
    main()
