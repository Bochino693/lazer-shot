#!/usr/bin/env python3
"""Artes e sons do Mar (scripts/mar_vida.gd).

Parte de sprites/atlantis.png (a foto do menu, que não muda) e gera:

  sprites/atlantis_jogo.png          fundo da partida: sem o navio (ele cai aos
                                     9 s) e sem os peixinhos parados (agora
                                     são cardumes que nadam); no lugar dos
                                     tabletes desbotados (e das cópias que o
                                     preenchimento deixava) um templo de
                                     Atlântida em ruínas ao longe, com luz de
                                     cristal na porta
  sprites/mar_navio.png              o navio recortado (só o navio) para cair
  sprites/mar_navio_pouso.png        a foto na caixa do navio: entra quando ele
                                     pousa (o cenário volta a ser a foto)
  sprites/mar_pedra_esq_mascara.png  pedras com escritas, 1x da caixa de cada
  sprites/mar_pedra_dir_mascara.png  uma: R=runas G=altura (0 topo, 1 base)
                                     B=pedra A=halo das runas
  sprites/mar_peixe.png              peixinho dos cardumes (silhueta)
  sprites/mar_bolha.png, mar_lodo.png, mar_farpa.png
                                     bolha de verdade, nuvem de lodo e farpa de
                                     madeira (água em volta do navio)
  songs/baleia.wav                   canto de baleia ao longe
  songs/navio_desce.wav              água correndo, madeira rangendo, bolhas
  songs/navio_impacto.wav            batida surda no fundo + areia + bolhas
  songs/pedra_lasca.wav              pedra rachando debaixo d'água

Precisa de opencv-contrib-python-headless (preenchimento por deslocamento,
xphoto.INPAINT_SHIFTMAP) além de numpy, scipy e Pillow.

    python3 tools/gerar_mar.py
"""
import os
import wave
import numpy as np
import cv2
from PIL import Image, ImageDraw
from scipy import ndimage as ndi
from scipy.signal import fftconvolve

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SP = os.path.join(RAIZ, "sprites")
SONGS = os.path.join(RAIZ, "songs")
rng = np.random.default_rng(11)
rng_agua = np.random.default_rng(23)   # só para bolha/lodo/pontos (não mexe nos outros sorteios)
W, H = 1024, 1536

# Contornos em px de atlantis.png (mesmos números em scripts/mar_vida.gd).
NAVIO = [(188, 538), (330, 488), (382, 452), (412, 442), (518, 435), (524, 468), (492, 570),
         (487, 632), (480, 698), (542, 762), (538, 802), (502, 872), (462, 912), (410, 934),
         (290, 934), (222, 898), (186, 770), (182, 670)]
PEDRA_ESQ = [(70, 486), (100, 468), (145, 468), (165, 494), (180, 570), (195, 650), (205, 720),
             (215, 790), (225, 860), (236, 925), (0, 935), (0, 740), (14, 640), (30, 565), (55, 512)]
PEDRA_DIR = [(725, 540), (760, 525), (830, 525), (850, 545), (880, 590), (905, 660), (925, 760),
             (940, 850), (948, 930), (900, 942), (856, 952), (850, 1060), (800, 1065), (790, 1130),
             (785, 1230), (525, 1230), (530, 1150), (550, 1050), (580, 950), (610, 850), (630, 760),
             (665, 670), (700, 580)]
# água aberta onde havia peixinhos parados
AGUA = [(196, 150), (700, 150), (700, 236), (650, 300), (566, 334), (476, 420), (414, 462),
        (330, 474), (258, 444), (212, 384), (196, 300)]


def poligono(p, ss=1):
    m = Image.new("L", (W * ss, H * ss), 0)
    ImageDraw.Draw(m).polygon([(x * ss, y * ss) for x, y in p], fill=255)
    if ss > 1:
        m = m.resize((W, H), Image.LANCZOS)
    return np.asarray(m).astype(np.float32) / 255.0


def gravar_img(arr, nome, modo=None):
    img = Image.fromarray((np.clip(arr, 0, 1) * 255 + 0.5).astype(np.uint8), modo)
    img.save(os.path.join(SP, nome), optimize=True)
    print("%-30s %dx%d" % (nome, img.width, img.height))


# ───────────────────────────────────────────── fundo sem navio e sem peixes
def fundo_sem_navio(orig_bgr):
    nav = poligono(NAVIO) > 0.5
    pe = poligono(PEDRA_ESQ) > 0.5
    buraco = ndi.binary_dilation(nav, iterations=2) & ~pe
    # espelhado: o deslocamento acha ruínas e pedras ao fundo (sem esse giro
    # ele copiava estruturas estranhas do lado esquerdo)
    img = orig_bgr[:, ::-1].copy()
    valido = (~buraco[:, ::-1]).astype(np.uint8) * 255
    dst = np.zeros_like(img)
    cv2.xphoto.inpaint(img, valido, dst, cv2.xphoto.INPAINT_SHIFTMAP)
    return dst[:, ::-1].copy()


def tirar_peixes(bg_bgr):
    rgb = bg_bgr[..., ::-1].astype(np.float32) / 255
    lum = rgb @ np.array([0.3, 0.59, 0.11], np.float32)
    agua = poligono(AGUA) > 0.5
    bh = ndi.grey_closing(lum, size=(15, 15)) - lum
    cand = (bh > 0.075) & agua
    lab, _ = ndi.label(cand)
    ok = np.zeros_like(cand)
    for i, sl in enumerate(ndi.find_objects(lab)):
        if sl is None:
            continue
        reg = lab[sl] == i + 1
        t = reg.sum()
        h = sl[0].stop - sl[0].start
        w = sl[1].stop - sl[1].start
        if 5 <= t <= 260 and w >= h * 0.8 and h <= 22:
            ok[sl] |= reg
    m = ndi.binary_dilation(ok, iterations=2)
    return cv2.inpaint(bg_bgr, m.astype(np.uint8) * 255, 4, cv2.INPAINT_TELEA)



# ───────────────────────────────────────────── templo de Atlântida ao longe
# Onde ficavam os tabletes desbotados (e as cópias deles que o preenchimento
# do navio deixava): o fundo é refeito com a própria textura da foto (água,
# chão, pedras; nada borrado) e, por cima, tudo nítido: um templo em ruínas
# (escadaria, colunas com caneluras, duas quebradas, arquitrave, frontão com
# a ponta partida, tambores caídos), a estátua de Poseidon com o tridente num
# pedestal, rochas, corais e algas fechando os cantos, e a luz de cristal na
# porta (ela pulsa no jogo: scripts/mar_vida.gd, TEMPLO_PORTA).
TEMPLO_AREA = [(318, 552), (470, 544), (566, 552), (600, 598), (602, 796), (318, 796)]
TEMPLO_PORTA = (439, 724)
LUZ = np.array([0.45, -0.65, 0.62], np.float32)     # luz da superfície, alto à direita
LUZ /= np.linalg.norm(LUZ)


def _fbm(forma, escalas, semente):
    g = np.random.default_rng(semente)
    out = np.zeros(forma, np.float32)
    for e, pw in escalas:
        n = g.standard_normal((forma[0] // e + 3, forma[1] // e + 3)).astype(np.float32)
        out += pw * ndi.zoom(n, e, order=3)[:forma[0], :forma[1]]
    return out


class Quadro4x:
    """Desenho em 4x numa caixa da imagem; cada peça é uma máscara."""

    def __init__(self, x0, y0, x1, y1, ss=4):
        self.x0, self.y0, self.ss = x0, y0, ss
        self.w, self.h = (x1 - x0) * ss, (y1 - y0) * ss
        gy, gx = np.mgrid[0:self.h, 0:self.w].astype(np.float32)
        self.X = gx / ss + x0
        self.Y = gy / ss + y0

    def P(self, x, y):
        return ((x - self.x0) * self.ss, (y - self.y0) * self.ss)

    def poli(self, pts):
        im = Image.new("L", (self.w, self.h), 0)
        ImageDraw.Draw(im).polygon([self.P(x, y) for x, y in pts], fill=255)
        return np.asarray(im).astype(np.float32) / 255

    def elipse(self, cx, cy, rx, ry):
        return (((self.X - cx) / rx) ** 2 + ((self.Y - cy) / ry) ** 2 <= 1).astype(np.float32)

    def caixa(self, xa, ya, xb, yb):
        return ((self.X >= xa) & (self.X <= xb) & (self.Y >= ya) & (self.Y <= yb)).astype(np.float32)

    def linhas(self, segs, larg):
        im = Image.new("L", (self.w, self.h), 0)
        d = ImageDraw.Draw(im)
        for a, b, w in segs:
            d.line([self.P(*a), self.P(*b)], fill=255, width=max(1, int(w * larg * self.ss)))
        return np.asarray(im).astype(np.float32) / 255

    def reduzir(self, a):
        s = self.ss
        if a.ndim == 3:
            return a.reshape(self.h // s, s, self.w // s, s, a.shape[2]).mean((1, 3))
        return a.reshape(self.h // s, s, self.w // s, s).mean((1, 3))


def _volume(m, raio):
    """Altura arredondada de uma peça (forma de almofada) a partir da máscara."""
    d = ndi.distance_transform_edt(m > 0.5)
    return np.sqrt(np.clip(d / raio, 0, 1))


def _luz(alt, forca=1.0):
    gy, gx = np.gradient(alt)
    nx, ny, nz = -gx * forca, -gy * forca, np.ones_like(alt)
    n = np.sqrt(nx * nx + ny * ny + nz * nz)
    return np.clip((nx * LUZ[0] + ny * LUZ[1] + nz * LUZ[2]) / n, 0, 1)


def templo_atlantida(bg):
    """bg: float RGB 1x. Devolve (nova imagem, máscara 0..1 do que mudou)."""
    # 1) fundo refeito com a textura da própria foto (sem borrar)
    u8 = np.ascontiguousarray((bg[..., ::-1] * 255).astype(np.uint8))
    buraco = poligono(TEMPLO_AREA, 2) > 0.3
    valido = (~buraco).astype(np.uint8) * 255
    dst = np.zeros_like(u8)
    cv2.xphoto.inpaint(u8, valido, dst, cv2.xphoto.INPAINT_SHIFTMAP)
    out = bg.copy()
    out[buraco] = dst[..., ::-1][buraco].astype(np.float32) / 255

    q = Quadro4x(300, 480, 628, 800)
    X, Y = q.X, q.Y
    tex = _fbm(X.shape, ((40, 1.0), (14, 0.6), (5, 0.35), (2, 0.2)), 17)
    pecas = []      # (máscara, altura, cor base, brilho do topo)

    # 2) rocha alta atrás do Poseidon (fecha o canto direito, por trás de tudo)
    gr = np.random.default_rng(13)
    contorno = []
    for k in range(28):
        t = k / 27
        y = 514 + t * 282
        lado_e = 548 + 22 * t + 6 * np.sin(t * 9 + 1) + gr.uniform(-3, 3)
        contorno.append((lado_e, y))
    contorno += [(624, 796)]
    for k in range(22):                       # lado direito irregular, subindo
        t = k / 21
        y = 796 - t * 270
        contorno.append((616 - 8 * t + 6 * np.sin(t * 11 + 2) + gr.uniform(-2.5, 2.5), y))
    for k in range(9):                        # topo pontudo e quebrado
        t = k / 8
        contorno.append((606 - t * 52, 524 - 12 * np.sin(t * np.pi) + gr.uniform(-4, 4)))
    morro = q.poli(contorno)
    # plataforma de rocha atrás do templo, ligada à rocha alta (cobre os
    # remendos retos que o preenchimento do navio deixava ali)
    plat = []
    for k in range(16):
        t = k / 15
        x = 396 + t * 176
        topo_y = 556 - 52 * np.sin(np.clip((t - 0.25) / 0.75, 0, 1) * np.pi * 0.5) ** 0.7
        plat.append((x, topo_y + 5 * np.sin(t * 13) + gr.uniform(-2.5, 2.5)))
    plat += [(574, 610), (540, 616), (470, 616), (420, 604), (396, 584)]
    morro = np.maximum(morro, q.poli(plat))
    alt_morro = _volume(morro, 10 * q.ss) * (1 + 0.6 * tex)
    estratos = q.linhas([((552 + k * 2, 560 + k * 38 + gr.uniform(-6, 6)), (612, 552 + k * 38 + gr.uniform(-6, 6)), 0.7)
                         for k in range(6)], 1.0) * morro

    # 3) templo
    deg = np.zeros_like(X)
    alt_deg = np.zeros_like(X)
    for xa, xb, ya, yb in ((322, 548, 777, 790), (329, 541, 766, 777), (336, 534, 756, 766)):
        m = q.caixa(xa, ya, xb, yb)
        deg = np.maximum(deg, m)
        alt_deg = np.maximum(alt_deg, m * (0.5 + 0.5 * np.clip((Y - ya) / 3.0, 0, 1)))
    interior = q.caixa(346, 650, 524, 756)
    blocos = np.zeros_like(X)
    for yb in np.arange(650, 756, 9.0):
        blocos = np.maximum(blocos, q.caixa(346, yb - 0.5, 524, yb + 0.5))
        desloc = 0 if int((yb - 650) / 9) % 2 == 0 else 9
        for xb in np.arange(346 + desloc, 524, 18.0):
            blocos = np.maximum(blocos, q.caixa(xb - 0.5, yb, xb + 0.5, yb + 9))
    porta = q.poli([(431, 756), (431, 704), (434, 696), (439, 692), (444, 696), (447, 704), (447, 756)])
    col = np.zeros_like(X)
    alt_col = np.zeros_like(X)
    xs = [354, 388, 422, 456, 490, 524]
    for i, cx in enumerate(xs):
        alto = np.full_like(X, 650.0)
        if i == 1:
            alto = 700 + 5 * np.sin((X - cx) * 0.9)
        if i == 4:
            alto = 726 + 5 * np.sin((X - cx) * 0.8 + 1)
        meia = 7.4 + 1.3 * np.clip((Y - 650) / 106, 0, 1)
        dentro = (np.abs(X - cx) <= meia) & (Y >= alto) & (Y <= 756)
        rel = np.clip((X - cx) / meia, -1, 1)
        h = np.sqrt(1 - rel ** 2) * (1 - 0.12 * (np.cos(rel * np.pi * 4.5) > 0.55))
        col = np.where(dentro, 1.0, col)
        alt_col = np.where(dentro, h, alt_col)
        if i not in (1, 4):
            cap = q.caixa(cx - 11.5, 642, cx + 11.5, 650)
            col = np.maximum(col, cap)
            alt_col = np.maximum(alt_col, cap * (0.6 + 0.4 * np.clip((650 - Y) / 3, 0, 1)))
    entab = np.maximum(q.caixa(338, 626, 532, 642), 0)
    fr = q.poli([(336, 626), (435, 586), (522, 621), (516, 624), (532, 626)])
    quebra = q.poli([(500, 600), (536, 600), (536, 626), (516, 626), (512, 616), (506, 612)])
    fr = np.clip(fr - quebra, 0, 1)
    timpano = q.poli([(352, 622), (435, 592), (504, 620)])
    tambores = np.maximum.reduce([q.elipse(508, 750, 8, 6.4), q.elipse(523, 761, 7, 5.6), q.elipse(498, 762, 6, 4.8)])
    ent = np.clip(entab + fr + tambores, 0, 1)
    alt_ent = _volume(ent, 3.0 * q.ss) * (1 - 0.35 * timpano)
    # dentículos e juntas
    junta = np.zeros_like(X)
    for k in range(26):
        junta = np.maximum(junta, q.caixa(340 + k * 7.3, 636, 343 + k * 7.3, 640))
    for yj in (642.5, 766, 777):
        junta = np.maximum(junta, q.caixa(330, yj - 0.4, 545, yj + 0.4) * deg if yj > 700 else q.caixa(338, yj - 0.4, 532, yj + 0.4))

    # 3) Poseidon no pedestal
    ped = np.maximum(q.caixa(552, 772, 598, 790), q.caixa(556, 738, 594, 772))
    friso_ped = q.caixa(556, 748, 594, 751)
    corpo_partes = [
        q.poli([(566, 738), (573, 738), (575, 692), (563, 692)]),                     # perna esq.
        q.poli([(578, 738), (585, 738), (588, 692), (577, 692)]),                     # perna dir.
        q.poli([(560, 676), (591, 676), (594, 708), (585, 713), (575, 705), (566, 714), (557, 708)]),   # pano na cintura
        q.poli([(561, 680), (589, 680), (593, 641), (587, 631), (563, 631), (557, 641)]),   # tronco
        q.caixa(571, 621, 579, 632),                                                   # pescoço
        q.elipse(575, 613, 7.2, 8.5),                                                  # cabeça
        q.poli([(568, 615), (582, 615), (579, 630), (575, 634), (571, 630)]),          # barba
        q.poli([(566, 606), (584, 606), (583, 610), (567, 610)]),                      # coroa (aro)
        q.poli([(567, 607), (569, 597), (571, 607)]), q.poli([(573, 606), (575, 593), (577, 606)]),
        q.poli([(579, 607), (581, 597), (583, 607)]),
        q.poli([(557, 641), (563, 634), (560, 660), (558, 676), (553, 675), (554, 659)]),   # braço que desce
        q.elipse(556, 678, 3.4, 3.8),                                                  # mão que desce
        q.poli([(587, 634), (594, 641), (597, 632), (601, 622), (597, 616), (593, 626)]),   # braço que segura
        q.elipse(599.5, 617, 4.0, 4.4),                                                # mão
    ]
    corpo = np.clip(np.maximum.reduce(corpo_partes), 0, 1)
    # músculos e dobras do manto (riscos escuros finos)
    detalhe = q.linhas([((575, 640), (575, 676), 1.0), ((566, 650), (574, 654), 0.8), ((584, 650), (576, 654), 0.8),
                        ((568, 664), (582, 664), 0.6), ((569, 671), (581, 671), 0.6),
                        ((563, 684), (561, 706), 0.6), ((570, 684), (569, 708), 0.6), ((580, 684), (581, 708), 0.6),
                        ((587, 684), (590, 706), 0.6), ((569, 690), (570, 736), 0.5), ((581, 690), (580, 736), 0.5)], 1.0) * corpo
    alt_corpo = np.maximum.reduce([_volume(m, 3.5 * q.ss) for m in corpo_partes])
    tridente = np.clip(q.caixa(598.6, 552, 601.4, 738)
                       + q.poli([(598.4, 552), (598.4, 538), (600, 530), (601.6, 538), (601.6, 552)])
                       + q.poli([(592, 556), (594, 556), (594.5, 544), (593, 536), (591.5, 544)])
                       + q.poli([(606, 556), (608, 556), (608.5, 544), (607, 536), (605.5, 544)])
                       + q.caixa(591.5, 553, 608.5, 557.5), 0, 1)
    alt_tri = _volume(tridente, 1.4 * q.ss)

    # 4) rochas, corais e algas fechando os cantos
    g = np.random.default_rng(9)
    rochas = []
    for cx, cy, rx, ry in ((326, 784, 16, 10), (342, 789, 12, 7), (556, 792, 14, 8), (606, 788, 12, 9),
                           (329, 728, 15, 52), (338, 770, 10, 18)):
        ang = np.arctan2(Y - cy, X - cx)
        borda = 1 + 0.22 * np.sin(ang * 3 + g.uniform(0, 6)) + 0.12 * np.sin(ang * 7 + g.uniform(0, 6))
        rochas.append(((((X - cx) / rx) ** 2 + ((Y - cy) / ry) ** 2) <= borda ** 2).astype(np.float32))
    rocha = np.clip(np.maximum.reduce(rochas), 0, 1)
    alt_rocha = _volume(rocha, 5 * q.ss) * (1 + 0.25 * tex)
    segs = []
    for bx, by, n, alt in ((332, 776, 5, 22), (548, 784, 4, 18), (612, 782, 4, 20), (326, 682, 4, 18), (340, 748, 3, 16)):
        for k in range(n):
            a0 = -np.pi / 2 + g.uniform(-0.7, 0.7)
            x0, y0 = bx + g.uniform(-4, 4), by
            comp = alt * g.uniform(0.6, 1.0)
            x1, y1 = x0 + np.cos(a0) * comp, y0 + np.sin(a0) * comp
            segs.append(((x0, y0), (x1, y1), 1.0))
            for j in range(2):
                t = g.uniform(0.4, 0.8)
                xm, ym = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
                a1 = a0 + g.choice([-1, 1]) * g.uniform(0.5, 0.9)
                segs.append(((xm, ym), (xm + np.cos(a1) * comp * 0.4, ym + np.sin(a1) * comp * 0.4), 0.7))
    coral = q.linhas(segs, 2.6)
    pontas = np.zeros_like(X)
    for (a, b, w) in segs:
        pontas = np.maximum(pontas, q.elipse(b[0], b[1], 1.8 * w, 1.8 * w))
    coral = np.clip(coral + pontas, 0, 1)
    alg_segs = []
    for bx, by, comp, sobe, w in ((319, 790, 70, True, 1.2), (338, 790, 46, True, 1.0), (562, 772, 40, True, 1.0),
                                  (552, 790, 90, True, 1.1), (612, 700, 60, True, 1.0), (334, 690, 40, True, 0.9),
                                  (346, 642, 20, False, 0.8), (412, 642, 28, False, 0.9), (520, 642, 22, False, 0.8)):
        fase = g.uniform(0, 6)
        for k in range(26):
            t0, t1 = k / 26, (k + 1) / 26
            ya, yb = (by - comp * t0, by - comp * t1) if sobe else (by + comp * t0, by + comp * t1)
            xa = bx + np.sin(t0 * 4.5 + fase) * 4.0 * t0
            xb = bx + np.sin(t1 * 4.5 + fase) * 4.0 * t1
            alg_segs.append(((xa, ya), (xb, yb), w * (1 - 0.75 * t0)))
    alga = q.linhas(alg_segs, 2.8)

    # 5) cor: pedra azulada clara em cima, interior escuro, luz de cristal
    reg = out[q.y0:q.y0 + q.h // q.ss, q.x0:q.x0 + q.w // q.ss]
    media = reg.reshape(-1, 3).mean(0)
    agua = np.ones(X.shape + (3,), np.float32) * media
    vert = np.clip((Y - 540) / 250, 0, 1)[..., None]
    pedra = (agua * 0.70 + np.array([0.06, 0.11, 0.14])) * (1.10 - 0.28 * vert) * (1 + 0.08 * tex[..., None])
    marmore = (agua * 0.62 + np.array([0.16, 0.20, 0.22])) * (1.12 - 0.25 * vert) * (1 + 0.05 * tex[..., None])
    dentro = agua * 0.26 + np.array([0.0, 0.02, 0.04])
    dp = np.hypot(X - TEMPLO_PORTA[0], (Y - TEMPLO_PORTA[1]) / 1.5)
    brilho = np.exp(-(dp / 9.0) ** 2) + 0.4 * np.exp(-(dp / 30.0) ** 2)
    dentro = dentro + np.array([0.30, 0.95, 1.0]) * (brilho * 0.85)[..., None]
    cor = np.zeros(X.shape + (3,), np.float32)
    alfa = np.zeros_like(X)

    def pintar(m, c):
        nonlocal cor, alfa
        cor = cor * (1 - m[..., None]) + c * m[..., None]
        alfa = np.maximum(alfa, m)

    luz_m = _luz(alt_morro * 10.0)[..., None]
    pintar(morro, (agua * 0.48 + np.array([0.02, 0.06, 0.08])) * (0.35 + 1.0 * luz_m) * (1 + 0.12 * tex[..., None])
           * (1 - 0.35 * estratos[..., None]))
    pintar(interior, dentro * (1 - 0.35 * blocos[..., None]))
    pintar(porta, dentro * 1.05)
    luz_ent = _luz(alt_ent * 6.0)[..., None]
    pintar(ent, pedra * (0.55 + 0.75 * luz_ent) * (1 - 0.3 * timpano[..., None]))
    pintar(deg, pedra * (0.55 + 0.75 * _luz(alt_deg * 4.0)[..., None]))
    luz_c = _luz(alt_col * 10.0)[..., None]
    pintar(col, pedra * (0.45 + 0.9 * luz_c))
    pintar(ped, marmore * (0.55 + 0.75 * _luz(_volume(ped, 3.0 * q.ss) * 6.0)[..., None]) * (1 - 0.25 * friso_ped[..., None]))
    luz_corpo = _luz(alt_corpo * 9.0)[..., None]
    pintar(corpo, marmore * (0.40 + 1.0 * luz_corpo) * (1 - 0.22 * detalhe[..., None]))
    pintar(tridente, (marmore * 0.85 + np.array([0.04, 0.06, 0.05])) * (0.5 + 0.9 * _luz(alt_tri * 4.0)[..., None]))
    pintar(rocha, (agua * 0.55 + np.array([0.03, 0.05, 0.07])) * (0.5 + 0.8 * _luz(alt_rocha * 7.0)[..., None]))
    cor_coral = agua * 0.35 + np.array([0.28, 0.12, 0.22])
    pintar(coral, cor_coral * (0.85 + 0.3 * np.clip(-0.002 * (Y - 760), 0, 1))[..., None])
    pintar(alga * 0.9, agua * 0.40 + np.array([0.02, 0.10, 0.07]))
    # juntas e dentículos (escuros, nítidos)
    cor = cor * (1 - 0.35 * (junta * alfa)[..., None])
    # distância: tudo um pouco para a cor da água (sem desfocar)
    cor = cor * 0.74 + agua * 0.26

    # reduz 4x -> 1x e compõe
    cor1 = q.reduzir(cor * alfa[..., None])
    a1 = q.reduzir(alfa)
    cor1 = cor1 / np.maximum(a1[..., None], 1e-4)
    br1 = q.reduzir(brilho)
    reg_novo = reg * (1 - a1[..., None]) + cor1 * a1[..., None]
    # a luz da porta clareia a água bem perto (pouco, só em volta da porta)
    reg_novo = reg_novo + np.array([0.20, 0.7, 0.85]) * (np.clip(br1, 0, 1) * 0.10 * (1 - a1))[..., None]
    out[q.y0:q.y0 + q.h // q.ss, q.x0:q.x0 + q.w // q.ss] = np.clip(reg_novo, 0, 1)

    mud = buraco.astype(np.float32)
    mud[q.y0:q.y0 + q.h // q.ss, q.x0:q.x0 + q.w // q.ss] = np.maximum(mud[q.y0:q.y0 + q.h // q.ss, q.x0:q.x0 + q.w // q.ss], a1)
    return np.clip(out, 0, 1), mud


# ───────────────────────────────────────────── navio recortado
# Só o navio (mastros, velas, cordas e casco): corta na linha do fundo do
# casco (sem a areia de baixo) e não pega as rochas e cascatas em volta.
SO_NAVIO = [(188, 535), (330, 478), (395, 445), (470, 438), (520, 436), (500, 520), (485, 570),
            (476, 690), (536, 770), (546, 800), (525, 850), (500, 885), (470, 905), (400, 912),
            (300, 912), (230, 905), (198, 760), (186, 640)]


def recortar_navio(orig, bg, bg_jogo=None, mudou=None):
    """Dois recortes do navio (orig/bg em float RGB):
    - mar_navio.png: só o navio, com a cor da foto, para cair limpo pela água
      (sem placa de fundo em volta). Alfa = quanto o pixel é mais escuro que a
      água atrás dele (o fundo sem navio, borrado); o que é água entre cordas e
      velas fica transparente.
    - mar_navio_pouso.png: a foto original na caixa do navio (alfa = contorno).
      Quando o navio pousa, a areia sobe e este recorte entra no lugar: o
      cenário volta a ser exatamente a foto (com o templo do fundo do jogo
      atrás do navio, onde ele foi pintado: bg_jogo/mudou)."""
    P = poligono(NAVIO, 4)
    S = ndi.gaussian_filter(poligono(SO_NAVIO, 4), 2.5)
    pe = poligono(PEDRA_ESQ) > 0.5
    L = np.array([0.3, 0.59, 0.11], np.float32)
    lum = orig @ L
    agua = ndi.gaussian_filter(bg @ L, 12)
    claro = ndi.gaussian_filter(ndi.grey_dilation(lum, size=(9, 9)), 6)
    agua = np.maximum(agua, np.minimum(claro, agua + 0.12))
    a = np.clip((agua - lum - 0.05) / 0.18, 0, 1)
    a = ndi.gaussian_filter(a, 0.5) * S
    F = orig.copy()
    # parte escondida atrás da pedra: continua o casco (só aparece caindo)
    atras = ndi.binary_dilation((P > 0.5) & pe, iterations=2)
    m8 = atras.astype(np.uint8) * 255
    F = cv2.inpaint((F * 255).astype(np.uint8), m8, 7, cv2.INPAINT_TELEA).astype(np.float32) / 255
    a = cv2.inpaint((a * 255).astype(np.uint8), m8, 7, cv2.INPAINT_TELEA).astype(np.float32) / 255
    a *= P > 0.02
    ys, xs = np.nonzero(P > 0.01)
    x0, y0, x1, y1 = xs.min() - 4, ys.min() - 4, xs.max() + 5, ys.max() + 5
    sl = (slice(y0, y1), slice(x0, x1))
    gravar_img(np.dstack([F[sl], a[sl]]), "mar_navio.png", "RGBA")
    pouso = np.clip(ndi.gaussian_filter(ndi.binary_dilation(P > 0.5, iterations=4).astype(np.float32), 1.5), 0, 1)
    foto = orig
    if bg_jogo is not None:
        # onde o fundo do jogo mudou (templo), o que não é navio vem dele
        m = mudou[..., None]
        foto = orig * (1 - m) + (orig * a[..., None] + bg_jogo * (1 - a[..., None])) * m
    gravar_img(np.dstack([foto[sl], pouso[sl]]), "mar_navio_pouso.png", "RGBA")
    print("   navio: canto (%d, %d)  tamanho %dx%d" % (x0, y0, x1 - x0, y1 - y0))


def mascara_pedra(orig, contorno, nome):
    memb = poligono(contorno, 4)
    ys, xs = np.nonzero(memb > 0.01)
    x0, y0, x1, y1 = xs.min(), ys.min(), xs.max() + 1, ys.max() + 1
    r, g, b = orig[..., 0], orig[..., 1], orig[..., 2]
    lum = 0.3 * r + 0.59 * g + 0.11 * b
    ciano = np.minimum(g, b) - r
    runa = np.clip((ciano - 0.16) / 0.28, 0, 1) * np.clip((lum - 0.30) / 0.25, 0, 1)
    runa = ndi.gaussian_filter(runa, 0.7) * memb
    halo = ndi.gaussian_filter(runa, 4.0)
    halo = np.clip(halo / max(halo.max(), 1e-3) * 1.6, 0, 1) * memb
    yy = np.mgrid[0:H, 0:W][0].astype(np.float32)
    altura = np.clip((yy - y0) / (y1 - y0), 0, 1)
    sl = (slice(y0, y1), slice(x0, x1))
    gravar_img(np.dstack([runa[sl], altura[sl], memb[sl], halo[sl]]), nome, "RGBA")
    print("   %s: canto (%d, %d)  tamanho %dx%d" % (nome, x0, y0, x1 - x0, y1 - y0))


def peixe():
    """Silhueta de peixinho visto de lado, cabeça à direita, 4x reduzido."""
    S = 4
    w, h = 40 * S, 16 * S
    im = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(im)
    corpo = []
    for i in range(41):
        t = i / 40.0
        x = (0.18 + 0.80 * t) * w
        meia = (0.42 * np.sin(np.pi * (t ** 0.8)) ** 0.9) * h
        corpo.append((x, h / 2 - meia))
    for i in range(40, -1, -1):
        t = i / 40.0
        x = (0.18 + 0.80 * t) * w
        meia = (0.36 * np.sin(np.pi * (t ** 0.8)) ** 0.9) * h
        corpo.append((x, h / 2 + meia))
    d.polygon(corpo, fill=255)
    d.polygon([(0.24 * w, h / 2), (0.0, 0.08 * h), (0.07 * w, h / 2), (0.0, 0.92 * h)], fill=255)
    d.polygon([(0.50 * w, 0.14 * h), (0.62 * w, 0.0), (0.66 * w, 0.18 * h)], fill=200)
    a = np.asarray(im.resize((40, 16), Image.LANCZOS)).astype(np.float32) / 255
    # dorso mais escuro, barriga um pouco mais clara (contra a luz de cima)
    yy = np.linspace(0, 1, 16)[:, None] * np.ones((1, 40))
    cor = np.clip(0.62 + 0.38 * yy, 0, 1)
    gravar_img(np.dstack([cor, cor, cor, a]), "mar_peixe.png", "RGBA")


# ───────────────────────────────────────────── sons (22050 Hz, mono)
TAXA = 22050


def gravar_wav(sinal, nome, pico=0.80):
    s = np.asarray(sinal, np.float64)
    s = s / (np.abs(s).max() + 1e-9) * pico
    dados = (s * 32767).astype(np.int16)
    with wave.open(os.path.join(SONGS, nome), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(TAXA)
        f.writeframes(dados.tobytes())
    print("%-30s %.2f s" % (nome, len(s) / TAXA))


def tempo(seg):
    return np.arange(int(seg * TAXA)) / TAXA


def passa_baixa_rapido(x, fc, ordem=2):
    from scipy.signal import butter, sosfilt
    return sosfilt(butter(ordem, fc, "low", fs=TAXA, output="sos"), x)


def passa_banda(x, f0, f1, ordem=2):
    from scipy.signal import butter, sosfilt
    return sosfilt(butter(ordem, [f0, f1], "band", fs=TAXA, output="sos"), x)


def reverb(x, dur, decai, molhado):
    n = int(dur * TAXA)
    ir = rng.standard_normal(n) * np.exp(-np.arange(n) / (decai * TAXA))
    ir = passa_baixa_rapido(ir, 2500)
    ir /= np.sqrt((ir ** 2).sum())
    y = np.zeros(len(x) + n)
    c = fftconvolve(x, ir)
    y[: len(c)] = c[: len(y)]
    seco = np.concatenate([x, np.zeros(n)])
    return seco * (1 - molhado) + y * molhado * 3.0


def envelope(t, ataque, solta, total):
    e = np.clip(t / ataque, 0, 1) * np.clip((total - t) / solta, 0, 1)
    return e * e * (3 - 2 * e)


def tom(f, t, harm=(1.0, 0.5, 0.25, 0.12)):
    fase = 2 * np.pi * np.cumsum(f) / TAXA
    return sum(a * np.sin((k + 1) * fase) for k, a in enumerate(harm))


def bolhas(dur, n, f0=(320, 700), f1=(800, 1600), pico=0.5):
    out = np.zeros(int(dur * TAXA))
    for _ in range(n):
        ini = rng.integers(0, len(out) - 2000)
        d = rng.uniform(0.018, 0.045)
        tt = tempo(d)
        f = rng.uniform(*f0) * (rng.uniform(*f1) / 600.0) ** (tt / d)
        b = np.sin(2 * np.pi * np.cumsum(f) / TAXA) * np.exp(-tt / (d * 0.35)) * rng.uniform(0.3, 1.0)
        out[ini:ini + len(b)] += b * pico
    return out


def som_baleia():
    total = 5.2
    t = tempo(total)
    s = np.zeros_like(t)
    # gemido longo que sobe e desce
    m1 = (t < 2.4)
    tt = t[m1]
    f = 135 + 95 * np.sin(np.pi * tt / 2.4) ** 1.5 + 3.0 * np.sin(2 * np.pi * 4.6 * tt)
    s[m1] += tom(f, tt) * envelope(tt, 0.45, 0.7, 2.4)
    # "uuoop" que sobe rápido e cai
    m2 = (t >= 2.7) & (t < 4.6)
    tt = t[m2] - 2.7
    f = np.where(tt < 1.2, 250 * (2.1 ** (tt / 1.2)), 525 - 140 * ((tt - 1.2) / 0.7))
    f = f + 4.0 * np.sin(2 * np.pi * 5.2 * tt)
    s[m2] += 0.8 * tom(f, tt, (1.0, 0.35, 0.15)) * envelope(tt, 0.25, 0.45, 1.9)
    # sopro de ar no fundo
    s += 0.05 * passa_baixa_rapido(rng.standard_normal(len(t)), 400) * envelope(t, 0.5, 1.0, total)
    s = passa_baixa_rapido(s, 1600)
    return reverb(s, 2.2, 0.55, 0.5)


def som_navio_desce():
    total = 3.2
    t = tempo(total)
    agua = passa_baixa_rapido(np.cumsum(rng.standard_normal(len(t))) * 0.02, 320)
    agua = agua - passa_baixa_rapido(agua, 25)
    agua *= envelope(t, 0.6, 0.5, total) * (0.7 + 0.3 * np.sin(2 * np.pi * 0.9 * t))
    s = agua * 3.0
    # madeira rangendo (duas vezes)
    for ini, dur, base in [(0.5, 0.55, 95), (1.7, 0.7, 120)]:
        tt = tempo(dur)
        f = base * (1 + 0.25 * np.sin(2 * np.pi * 1.3 * tt)) + rng.normal(0, 6, len(tt))
        serra = 2 * ((np.cumsum(f) / TAXA) % 1.0) - 1
        rangido = passa_banda(serra, 300, 1400) * envelope(tt, 0.08, 0.2, dur) * (0.6 + 0.4 * (rng.random(len(tt)) > 0.6))
        i = int(ini * TAXA)
        s[i:i + len(tt)] += rangido * 0.5
    s += bolhas(total, 70, pico=0.35) * np.clip(t / total * 1.4, 0.2, 1.0)
    s = passa_baixa_rapido(s, 3000)
    return reverb(s, 1.5, 0.4, 0.35)


def som_navio_impacto():
    total = 3.6
    t = tempo(total)
    boom = (np.sin(2 * np.pi * 38 * t) + 0.7 * np.sin(2 * np.pi * 56 * t)) * np.exp(-t / 0.75)
    batida = passa_baixa_rapido(rng.standard_normal(len(t)), 600) * np.exp(-t / 0.22) * 2.0
    madeira = passa_banda(rng.standard_normal(len(t)), 350, 1900) * np.exp(-t / 0.35) * (rng.random(len(t)) > 0.4) * 0.8
    areia = passa_baixa_rapido(rng.standard_normal(len(t)), 900) * np.exp(-t / 1.4) * 0.6 * np.clip(t / 0.15, 0, 1)
    s = boom * 1.2 + batida + madeira + areia
    s += bolhas(total, 90, pico=0.3) * np.exp(-t / 1.6)
    s = passa_baixa_rapido(s, 2800)
    return reverb(s, 2.0, 0.6, 0.4)


def som_pedra():
    total = 0.75
    t = tempo(total)
    estalo = rng.standard_normal(len(t)) * np.exp(-t / 0.004)
    tok = np.sin(2 * np.pi * 1750 * t) * np.exp(-t / 0.014) + 0.8 * np.sin(2 * np.pi * 880 * t) * np.exp(-t / 0.03)
    surdo = np.sin(2 * np.pi * 110 * t) * np.exp(-t / 0.10) * 1.1
    grao = np.zeros_like(t)
    for _ in range(18):
        i = int(rng.uniform(0.01, 0.30) * TAXA)
        d = int(0.004 * TAXA)
        grao[i:i + d] += rng.standard_normal(d) * rng.uniform(0.2, 0.7) * np.exp(-np.arange(d) / (0.0015 * TAXA))
    grao *= np.exp(-t / 0.18)
    s = estalo * 1.2 + tok + surdo + grao
    s += bolhas(total, 10, pico=0.25)
    s = passa_baixa_rapido(s, 3600)
    return reverb(s, 0.6, 0.18, 0.25)


# ───────────────────────────────────────────── água em volta do navio
def bolha():
    """Bolha de verdade: quase transparente, aro claro, reflexo no alto."""
    N = 64
    yy, xx = (np.mgrid[0:N, 0:N] + 0.5 - N / 2) / (N / 2)
    r = np.hypot(xx, yy)
    aro = np.exp(-((r - 0.86) / 0.07) ** 2)
    dentro = np.clip(1 - r, 0, 1) ** 2 * 0.18
    reflexo = np.exp(-(((xx + 0.32) / 0.22) ** 2 + ((yy + 0.38) / 0.13) ** 2))
    fundo_claro = np.exp(-(((xx - 0.2) / 0.35) ** 2 + ((yy - 0.45) / 0.18) ** 2)) * 0.35
    a = np.clip(aro * 0.85 + dentro + reflexo + fundo_claro, 0, 1) * (r < 1.0)
    cor = np.dstack([0.85 + 0.15 * reflexo, 0.95 + 0.05 * reflexo, np.ones_like(a)])
    gravar_img(np.dstack([cor, a]), "mar_bolha.png", "RGBA")


def lodo():
    """Nuvem de lodo/areia: ruído em várias escalas dentro de um borrão redondo."""
    N = 128
    ruido = np.zeros((N, N))
    for esc, peso in [(4, 0.5), (8, 0.3), (16, 0.2)]:
        base = rng_agua.random((esc, esc))
        ruido += peso * np.asarray(Image.fromarray((base * 255).astype(np.uint8)).resize((N, N), Image.BICUBIC)).astype(np.float32) / 255
    yy, xx = (np.mgrid[0:N, 0:N] + 0.5 - N / 2) / (N / 2)
    r = np.hypot(xx, yy)
    borrao = np.clip(1 - r, 0, 1) ** 1.6
    a = np.clip((ruido - 0.25) * 1.6, 0, 1) * borrao
    a = ndi.gaussian_filter(a, 2.0)
    a = a / max(a.max(), 1e-3)
    cor = np.dstack([0.78 + 0.22 * ruido, 0.84 + 0.16 * ruido, 0.86 + 0.14 * ruido])
    gravar_img(np.dstack([np.clip(cor, 0, 1), a]), "mar_lodo.png", "RGBA")


def farpa():
    """Farpa de madeira molhada: tira com veios e pontas lascadas."""
    W_, H_ = 48, 12
    S = 4
    im = Image.new("L", (W_ * S, H_ * S), 0)
    d = ImageDraw.Draw(im)
    d.polygon([(0, H_ * S * 0.55), (W_ * S * 0.12, H_ * S * 0.1), (W_ * S * 0.85, 0), (W_ * S, H_ * S * 0.35),
               (W_ * S * 0.92, H_ * S * 0.9), (W_ * S * 0.2, H_ * S), (W_ * S * 0.05, H_ * S * 0.8)], fill=255)
    a = np.asarray(im.resize((W_, H_), Image.LANCZOS)).astype(np.float32) / 255
    yy = np.linspace(0, 1, H_)[:, None] * np.ones((1, W_))
    xx = np.ones((H_, 1)) * np.linspace(0, 1, W_)[None, :]
    veio = 0.5 + 0.5 * np.sin(yy * 22 + xx * 3)
    # madeira encharcada e desbotada pela água (o azul vem do tom da partícula):
    # clara em cima, onde pega a luz que desce, escura embaixo
    base = np.array([0.62, 0.56, 0.48])
    luz = 1.15 - 0.55 * yy
    cor = base[None, None, :] * ((0.78 + 0.22 * veio) * luz)[..., None]
    # pontas mais finas e meio translúcidas (lascas, não palitos)
    ponta = np.clip(np.minimum(xx, 1 - xx) / 0.18, 0, 1)
    gravar_img(np.dstack([np.clip(cor, 0, 1), a * (0.45 + 0.55 * ponta) * 0.9]), "mar_farpa.png", "RGBA")


def pontos_navio():
    """Pontos no alto do casco, mastros e vergas (px do recorte), de onde sai o
    rastro de bolhas quando o navio afunda."""
    im = np.asarray(Image.open(os.path.join(SP, "mar_navio.png")).convert("RGBA")).astype(np.float32) / 255
    a = im[..., 3]
    borda = (a > 0.55) & (np.roll(a, 4, axis=0) < 0.25)
    ys, xs = np.nonzero(borda)
    ordem = rng_agua.permutation(len(xs))[:48]
    pts = sorted(zip(xs[ordem], ys[ordem]))
    print("   pontos do navio: " + ", ".join("Vector2(%d, %d)" % (x, y) for x, y in pts))


def main():
    orig_bgr = cv2.imread(os.path.join(SP, "atlantis.png"))
    bg_bgr = tirar_peixes(fundo_sem_navio(orig_bgr))
    orig = orig_bgr[..., ::-1].astype(np.float32) / 255
    bg = bg_bgr[..., ::-1].astype(np.float32) / 255
    jogo, mudou = templo_atlantida(bg)
    gravar_img(jogo, "atlantis_jogo.png")
    recortar_navio(orig, bg, jogo, mudou)
    mascara_pedra(orig, PEDRA_ESQ, "mar_pedra_esq_mascara.png")
    mascara_pedra(orig, PEDRA_DIR, "mar_pedra_dir_mascara.png")
    peixe()
    bolha()
    lodo()
    farpa()
    pontos_navio()
    gravar_wav(som_baleia(), "baleia.wav", 0.7)
    gravar_wav(som_navio_desce(), "navio_desce.wav", 0.7)
    gravar_wav(som_navio_impacto(), "navio_impacto.wav", 0.85)
    gravar_wav(som_pedra(), "pedra_lasca.wav", 0.8)


if __name__ == "__main__":
    main()
