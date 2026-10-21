#!/usr/bin/env python3
"""Mar com o cenário inteiro (Rodada 21) e continuando atrás do templo (Rodada 28).

Na Rodada 18 as duas pedras com escritas viraram planos recortados por cima
de um fundo sem elas (remendado). Com a câmera andando cada pixel pela
distância dele, o remendo aparecia nas beiradas; e as lascas, a poeira e as
bolhas do tiro na pedra saíam por baixo dela e desenhavam o recorte. Agora:

  sprites/atlantis_fundo.png   a pintura inteira (atlantis_jogo.png): a cena
                               anda junta e a pedra é pintada com os mesmos
                               pixels do fundo (shaders/mar_pedra.gdshader lê
                               a textura do fundo), sem remendo nenhum.
                               Onde era o navio, a Rodada 21 tinha posto uma
                               névoa (ficava um borrão atrás do templo); na
                               Rodada 28 é o cenário continuando: a pintura
                               original (atlantis.png), sem o navio e sem o
                               poneglifo apagado do meio, com o buraco
                               preenchido com pedaços dela mesma
                               (tools/completar_textura.py): a água aberta e o
                               penhasco da esquerda, a cidade com a cachoeira
                               descendo atrás do Poseidon e o chão de água
                               clara (achatado, mais longe) até o pé do
                               templo. O templo, o Poseidon e o poneglifo
                               pequeno voltam nítidos por cima, sem névoa
  sprites/mar_pedra_esq/dir.png  contorno liso (sem tufos de água e coral
                               soltos em volta): é só a forma que esconde o que
                               passa atrás da pedra
  tools/hd/atlantis_fundo@2x.png / @hd.png  a alta refeita só onde mudou
                               (EDSR, como tools/gerar_hd.py; sem o modelo,
                               Lanczos). Depois tools/gerar_hd.gd.

    MODELO=/caminho/EDSR_x2.pb python3 tools/gerar_mar_inteiro.py [--pedras]
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
from completar_textura import completar, poisson  # noqa: E402

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
# templo e do Poseidon (desenhada lá para cobrir o preenchimento velho)
NAVIO = [(188, 538), (330, 488), (382, 452), (412, 442), (518, 435), (524, 468), (492, 570),
         (487, 632), (480, 698), (542, 762), (538, 802), (502, 872), (462, 912), (410, 934),
         (290, 934), (222, 898), (186, 770), (182, 670)]
ROCHA = [(392, 500), (470, 468), (560, 476), (648, 492), (652, 800), (540, 800), (396, 620)]
# o poneglifo apagado do meio da pintura original (a Rodada 11 tirou os
# apagados; o templo e o Poseidon ficam na frente dele)
PEDRA_MEIO = [(492, 700), (500, 680), (515, 667), (535, 660), (556, 665), (571, 678), (581, 700),
              (587, 760), (592, 884), (484, 884), (487, 760)]
NAVIO_CANTO = (176, 429)        # scripts/mar_vida.gd NAVIO_CANTO (mar_navio_cor.png)
FRENTE_CANTO = (195, 530)       # scripts/mar_vida.gd FRENTE_CANTO
Y_CHAO = 795                    # pé do templo: daqui para baixo o buraco é chão
JANELA = (150, 1060)            # faixa de linhas onde o preenchimento procura
# de onde o chão copia: areia e água clara sem pedra, e a névoa da cachoeira
# ao lado do Poseidon (a passagem para ela sai sem emenda)
CHAO_LIMPO = [(300, 955, 560, 1015), (470, 880, 560, 950), (500, 790, 610, 905)]
LONGE = (0.55, 0.75)            # o chão limpo achatado: o chão de trás, mais longe


def poli(p, forma, ss=4):
    H, W = forma
    m = Image.new("L", (W * ss, H * ss), 0)
    ImageDraw.Draw(m).polygon([(x * ss, y * ss) for x, y in p], fill=255)
    return np.asarray(m.resize((W, H), Image.LANCZOS)).astype(np.float32) / 255


def continuar_onde_era_o_navio(jogo, original, pedras):
    """jogo/original: RGB 0..1 (atlantis_jogo / atlantis). pedras: alfa das
    pedras grandes na imagem inteira. Devolve o fundo com o cenário
    continuando onde era o navio."""
    H, W = jogo.shape[:2]
    nav = np.asarray(Image.open(os.path.join(SP, "mar_navio_cor.png")).convert("RGBA"))[..., 3]
    A = np.zeros((H, W), np.uint8)
    A[NAVIO_CANTO[1]:NAVIO_CANTO[1] + nav.shape[0], NAVIO_CANTO[0]:NAVIO_CANTO[0] + nav.shape[1]] = nav > 5
    fm = np.asarray(Image.open(os.path.join(SP, "mar_frente_navio_mascara.png")).convert("L")).astype(np.float32) / 255
    obj = np.zeros((H, W), np.float32)
    x0, y0 = FRENTE_CANTO
    obj[y0:y0 + fm.shape[0], x0:x0 + fm.shape[1]] = fm
    # onde o jogo tinha o preenchimento velho vale a pintura original; o
    # navio (com os vãos pequenos fechados e folga maior no casco: a quilha
    # escura e as algas penduradas na popa) e o poneglifo do meio viram buraco
    regiao = cv2.dilate((np.maximum(poli(NAVIO, (H, W)), poli(ROCHA, (H, W))) > 0.5).astype(np.uint8), k(3)).astype(bool)
    base = np.where(regiao[..., None], original, jogo)
    nav = cv2.morphologyEx(A, cv2.MORPH_CLOSE, k(7))
    buraco = cv2.dilate(nav, k(3)).astype(bool)
    casco = nav.copy()
    casco[:820] = 0
    buraco |= cv2.dilate(casco, k(9)).astype(bool)
    buraco |= poli(PEDRA_MEIO, (H, W)) > 0.3
    buraco &= regiao
    # na beirada da região, o que difere do jogo (ponta de mastro, peixe
    # parado que o jogo já tinha tirado) também vira buraco: sem emenda
    dif = (np.abs(original - jogo).max(2) > 8 / 255) & (obj < 0.05)
    beira = regiao & ~cv2.erode(regiao.astype(np.uint8), k(6)).astype(bool)
    buraco |= cv2.dilate((dif & beira).astype(np.uint8), k(3)).astype(bool) & regiao
    # as pedras grandes ficam intactas (o recorte delas lê estes pixels)
    buraco &= pedras < 0.01
    # fonte: o resto, menos as pedras grandes e as coisas da frente
    ys, xs = np.mgrid[0:H, 0:W]
    fonte = ~buraco & (ys >= 200)
    fonte &= ~cv2.dilate((pedras > 0.05).astype(np.uint8), k(4)).astype(bool)
    fonte &= ~cv2.dilate((obj > 0.05).astype(np.uint8), k(3)).astype(bool)
    chao = np.zeros((H, W), bool)
    for a, b, c, d in CHAO_LIMPO:
        chao[b:d, a:c] = True
    zona = (ys >= Y_CHAO).astype(np.int32)
    zonas = [ys <= Y_CHAO - 5, chao]
    # a janela de trabalho e, embaixo dela, o chão limpo achatado
    t0, t1 = JANELA
    img, bur, fon = base[t0:t1], buraco[t0:t1], fonte[t0:t1]
    zon, zfs = zona[t0:t1], [z[t0:t1] for z in zonas]
    a, b, c, d = CHAO_LIMPO[0]
    tira = base[b:d, a:c]
    for e in LONGE:
        hh = int(round(tira.shape[0] * e))
        faixa = np.empty((hh + 8, W, 3), np.float32)
        faixa[:] = tira.mean((0, 1))
        faixa[4:4 + hh, a:c] = cv2.resize(tira, (c - a, hh), interpolation=cv2.INTER_AREA)
        ok = np.zeros(faixa.shape[:2], bool)
        ok[4:4 + hh, a:c] = True
        nada = np.zeros(ok.shape, bool)
        img = np.concatenate([img, faixa])
        bur = np.concatenate([bur, nada])
        fon = np.concatenate([fon, ok])
        zon = np.concatenate([zon, np.zeros(ok.shape, np.int32)])
        zfs = [np.concatenate([zfs[0], nada]), np.concatenate([zfs[1], ok])]
    print("preenchendo onde era o navio (%d px)" % int(buraco.sum()), flush=True)
    feito = base.copy()
    feito[t0:t1] = completar(img, bur, fon, zon, zfs)[:t1 - t0]
    feito = poisson(feito, base, buraco)
    # o templo, o Poseidon e o poneglifo pequeno por cima, nítidos; as pedras
    # grandes exatamente como eram
    fim = feito * (1 - obj[..., None]) + jogo * obj[..., None]
    fim = np.where((pedras > 0)[..., None], jogo, fim)
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
    original = np.asarray(Image.open(os.path.join(SP, "atlantis.png")).convert("RGB"))
    antes = np.asarray(Image.open(os.path.join(SP, "atlantis_fundo.png")).convert("RGB"))
    H, W = orig.shape[:2]
    pedras = np.zeros((H, W), np.float32)
    # o contorno liso das pedras (Rodada 21) só é refeito com --pedras; sem
    # isso vale o recorte que o jogo já usa
    refazer = "--pedras" in sys.argv
    for nome, canto in PEDRAS:
        caminho = os.path.join(SP, "mar_pedra_%s.png" % nome)
        tex = np.asarray(Image.open(caminho).convert("RGBA"))
        x0, y0 = max(canto[0] - FOLGA, 0), max(canto[1] - FOLGA, 0)
        h, w = tex.shape[:2]
        if refazer:
            rgb = orig[y0:y0 + h, x0:x0 + w].astype(np.float32)
            alfa = silhueta(tex[..., 3])
            Image.fromarray(np.dstack([rgb, alfa * 255 + 0.5]).astype(np.uint8), "RGBA").save(caminho, optimize=True)
            print("mar_pedra_%s.png" % nome, (w, h))
        else:
            alfa = tex[..., 3].astype(np.float32) / 255
        pedras[y0:y0 + h, x0:x0 + w] = np.maximum(pedras[y0:y0 + h, x0:x0 + w], alfa)
    fundo = continuar_onde_era_o_navio(orig.astype(np.float32) / 255, original.astype(np.float32) / 255, pedras)
    fundo = (fundo * 255 + 0.5).astype(np.uint8)
    mudou = (np.abs(antes.astype(np.int16) - fundo.astype(np.int16)).max(2) > 2).astype(np.uint8)
    Image.fromarray(fundo).save(os.path.join(SP, "atlantis_fundo.png"), optimize=True)
    print("atlantis_fundo.png: pintura inteira + cenário continuando onde era o navio (%d px mudaram)" % int(mudou.sum()))
    if mudou.any():
        alta_onde_mudou(fundo, mudou)


if __name__ == "__main__":
    main()
