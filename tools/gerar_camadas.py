#!/usr/bin/env python3
"""Planos (camadas) do Egito e do Mar tirados das próprias imagens.

O cenário deixa de ser uma foto só que "entorta" quando a câmera anda: cada
coisa em pé vira um plano recortado (com o contorno refinado por GrabCut a
partir do contorno medido em tools/gerar_profundidade.py) e o fundo atrás dela
é reconstruído (inpainting), então, quando a câmera anda e os planos se
deslocam uns dos outros, aparece chão, céu e pedra de verdade atrás deles, e
não pixel esticado.

Egito (dia e noite, mesmo recorte):
  sprites/egito_fundo_sol.png, egito_fundo_lua.png
      o fundo sem as coisas em pé e sem os feixes de energia (que agora são
      peças vivas, scripts/egito_feixes.gd)
  sprites/egito_planos_sol.png, egito_planos_lua.png
      folha com os recortes (colunas, Anúbis, obeliscos, cristal)
  sprites/egito_planos_brilho.png
      na mesma folha: R = onde o cristal e as pontas dos obeliscos brilham,
      G = onde a luz deles bate (some quando o cristal quebra)
  sprites/egito_fundo_luz.png
      a luz do cristal no chão e nos degraus do fundo (idem)
  scripts/egito_planos.gd
      onde cada recorte fica na imagem, onde está na folha e a distância dele

Mar:
  sprites/atlantis_fundo.png
      o fundo do Mar sem as duas pedras com escritas
  sprites/mar_pedra_esq.png, mar_pedra_dir.png
      as pedras recortadas (textura própria, com a máscara de cada uma)

    python3 tools/gerar_camadas.py
"""
import os
import sys
import numpy as np
import cv2
from PIL import Image, ImageDraw

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)
from gerar_profundidade import EG_COISAS, z_chao_egito  # noqa: E402

RAIZ = os.path.dirname(AQUI)
SP = os.path.join(RAIZ, "sprites")
SC = os.path.join(RAIZ, "scripts")

# na tela só aparece x de 79 a 945 da imagem (ela é escalada para cobrir a
# tela em pé); com a câmera andando, um pouco mais
X_VISIVEL = (52, 972)

# as coisas em pé do Egito que viram plano (índice em EG_COISAS)
EG_PLANOS = [
    ("coluna_fundo_esq", 6),
    ("coluna_fundo_dir", 7),
    ("anubis_esq", 8),
    ("anubis_dir", 9),
    ("obelisco_esq", 10),
    ("obelisco_dir", 11),
    ("cristal", 12),
    ("coluna_esq", 13),
    ("coluna_dir", 14),
]


def ler(nome):
    return np.asarray(Image.open(os.path.join(SP, nome)).convert("RGB"))


def gravar(arr, nome):
    modo = "RGBA" if arr.ndim == 3 and arr.shape[2] == 4 else ("RGB" if arr.ndim == 3 else "L")
    Image.fromarray(arr.astype(np.uint8), modo).save(os.path.join(SP, nome), optimize=True)
    print("  %-28s %dx%d" % (nome, arr.shape[1], arr.shape[0]))


def k(r):
    return cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (2 * r + 1, 2 * r + 1))


def mascara_poligono(pol, forma, E=2):
    h, w = forma
    m = Image.new("L", (w * E, h * E), 0)
    ImageDraw.Draw(m).polygon([(x * E, y * E) for x, y in pol], fill=255)
    return (np.asarray(m.resize((w, h), Image.LANCZOS)) > 127).astype(np.uint8)


def refinar(img, pm):
    """Contorno de verdade da coisa: GrabCut começando do polígono (miolo =
    certeza, beirada = provável, anel em volta = provável fundo)."""
    ys, xs = np.where(pm)
    h, w = pm.shape
    x0, x1 = max(xs.min() - 30, 0), min(xs.max() + 31, w)
    y0, y1 = max(ys.min() - 30, 0), min(ys.max() + 31, h)
    crop = np.ascontiguousarray(img[y0:y1, x0:x1])
    p = pm[y0:y1, x0:x1]
    dent = cv2.erode(p, k(7))
    fora = cv2.dilate(p, k(14))
    m = np.full(p.shape, cv2.GC_BGD, np.uint8)
    m[fora > 0] = cv2.GC_PR_BGD
    m[p > 0] = cv2.GC_PR_FGD
    m[dent > 0] = cv2.GC_FGD
    bg = np.zeros((1, 65), np.float64)
    fg = np.zeros((1, 65), np.float64)
    cv2.grabCut(cv2.cvtColor(crop, cv2.COLOR_RGB2BGR), m, None, bg, fg, 6, cv2.GC_INIT_WITH_MASK)
    res = ((m == cv2.GC_FGD) | (m == cv2.GC_PR_FGD)).astype(np.uint8)
    res = cv2.morphologyEx(res, cv2.MORPH_OPEN, k(1))
    res = cv2.morphologyEx(res, cv2.MORPH_CLOSE, k(2))
    # só os pedaços ligados ao miolo (tira faíscas e pedrinhas soltas)
    n, lab = cv2.connectedComponents(res)
    manter = np.zeros_like(res)
    for i in range(1, n):
        comp = lab == i
        if (comp & (dent > 0)).any():
            manter[comp] = 1
    out = np.zeros_like(pm)
    out[y0:y1, x0:x1] = manter
    return out


def transferir_cor(dia, noite, buraco):
    """Pinta os buracos da noite com a estrutura do dia reconstruído: em cada
    região, noite ~ a * dia + b (por canal), com a e b tirados dos pixels
    conhecidos em volta (janelas cada vez maiores onde o buraco é grande)."""
    d = dia.astype(np.float32) / 255.0
    n = noite.astype(np.float32) / 255.0
    conhecido = (1 - buraco).astype(np.float32)
    out = n.copy()
    a_fim = np.zeros_like(d)
    b_fim = np.zeros_like(d)
    feito = np.zeros(buraco.shape, np.float32)
    for r in (20, 45, 100, 220):
        caixa = lambda x: cv2.boxFilter(x, -1, (2 * r + 1, 2 * r + 1), normalize=False, borderType=cv2.BORDER_REFLECT)
        cnt = caixa(conhecido)
        ok = (cnt > (2 * r + 1) ** 2 * 0.12).astype(np.float32) * (1 - feito)
        for ch in range(3):
            md = caixa(d[..., ch] * conhecido) / np.maximum(cnt, 1)
            mn = caixa(n[..., ch] * conhecido) / np.maximum(cnt, 1)
            dd = caixa(d[..., ch] * d[..., ch] * conhecido) / np.maximum(cnt, 1) - md * md
            dn = caixa(d[..., ch] * n[..., ch] * conhecido) / np.maximum(cnt, 1) - md * mn
            a = dn / (dd + 0.002)
            b = mn - a * md
            a_fim[..., ch] += a * ok
            b_fim[..., ch] += b * ok
        feito = np.maximum(feito, ok)
    a_fim = cv2.GaussianBlur(a_fim, (0, 0), 6)
    b_fim = cv2.GaussianBlur(b_fim, (0, 0), 6)
    rec = np.clip(a_fim * d + b_fim, 0, 1)
    m = cv2.GaussianBlur(buraco.astype(np.float32), (0, 0), 1.2)[..., None]
    out = rec * m + n * (1 - m)
    return np.clip(out * 255, 0, 255)


# ───────────────────────────────────────────── Egito
def egito():
    sol = ler("deserto_sol.png")
    lua = ler("deserto_lua.png")
    forma = sol.shape[:2]
    H, W = forma
    print("Egito: recortando %d planos" % len(EG_PLANOS))
    planos = []
    for nome, idx in EG_PLANOS:
        pol, pe = EG_COISAS[idx]
        pm = mascara_poligono(pol, forma)
        m = refinar(sol, pm)
        planos.append({"nome": nome, "m": m, "z": float(z_chao_egito(pe))})
    # feixes e brilhos (máscara R/G do fundo, em meia resolução)
    msk = np.asarray(Image.open(os.path.join(SP, "deserto_sol_mascara.png")).convert("RGB").resize((W, H), Image.BILINEAR))
    feixes = (msk[..., 0] > 20).astype(np.uint8)
    brilho = msk[..., 1].astype(np.float32) / 255.0

    # fundo: tira as coisas em pé (com folga para o halo de luz delas), os
    # feixes e os brilhos; reconstrói por remendos da própria imagem
    # (shift-map: continua colunas, estátuas, pedras e o topo do altar atrás
    # do cristal), por regiões (o centro e cada coluna grande)
    tira = np.zeros(forma, np.uint8)
    for p in planos:
        folga = 9 if p["nome"] in ("cristal", "obelisco_esq", "obelisco_dir") else 4
        tira |= cv2.dilate(p["m"], k(folga))
    tira |= cv2.dilate(feixes, k(5))
    tira |= cv2.dilate((brilho > 0.05).astype(np.uint8), k(6))
    # o centro por remendos; atrás das colunas grandes (quase fora da tela,
    # só uma faixa fina aparece) pelo método simples, que não inventa
    centro = (30, 560, 1000, 1140)
    bgr = cv2.cvtColor(sol, cv2.COLOR_RGB2BGR).copy()
    x0, y0, x1, y1 = centro
    t = np.ascontiguousarray(tira[y0:y1, x0:x1])
    c = np.ascontiguousarray(bgr[y0:y1, x0:x1])
    out = np.zeros_like(c)
    cv2.xphoto.inpaint(c, ((1 - t) * 255).astype(np.uint8), out, cv2.xphoto.INPAINT_SHIFTMAP)
    bgr[y0:y1, x0:x1] = np.where(t[..., None] > 0, out, c)
    resto = tira.copy()
    resto[y0:y1, x0:x1] = 0
    if resto.any():
        bgr = cv2.inpaint(bgr, resto * 255, 9, cv2.INPAINT_TELEA)
    fundo_sol = cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB)
    gravar(fundo_sol, "egito_fundo_sol.png")
    # a noite é a mesma cena: o que foi reconstruído de dia ganha a cor da
    # noite em volta (mapeamento de cor local, dia -> noite)
    gravar(transferir_cor(fundo_sol, lua, tira), "egito_fundo_lua.png")

    # recortes: alfa suave na borda; o que estava escondido atrás de uma
    # coisa mais perto é reconstruído dentro do próprio recorte
    ordem = sorted(range(len(planos)), key=lambda i: -planos[i]["z"])   # longe -> perto
    caixas = []
    for i in ordem:
        p = planos[i]
        m = p["m"].copy()
        m[:, :X_VISIVEL[0]] = 0
        m[:, X_VISIVEL[1]:] = 0
        mais_perto = np.zeros(forma, np.uint8)
        for j in ordem:
            if planos[j]["z"] < p["z"]:
                mais_perto |= planos[j]["m"]
        escondido = (m & mais_perto).astype(np.uint8)
        ys, xs = np.where(m)
        x0, x1 = max(xs.min() - 3, 0), min(xs.max() + 4, W)
        y0, y1 = max(ys.min() - 3, 0), min(ys.max() + 4, H)
        alfa = cv2.GaussianBlur(m.astype(np.float32), (0, 0), 0.7)[y0:y1, x0:x1]
        cores = []
        for img in (sol, lua):
            c = np.ascontiguousarray(img[y0:y1, x0:x1])
            if escondido[y0:y1, x0:x1].any():
                bgr = cv2.inpaint(cv2.cvtColor(c, cv2.COLOR_RGB2BGR), escondido[y0:y1, x0:x1] * 255, 5, cv2.INPAINT_TELEA)
                c = cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB)
            cores.append(c)
        caixas.append({"nome": p["nome"], "z": p["z"], "canto": (x0, y0), "tam": (x1 - x0, y1 - y0),
                       "alfa": alfa, "sol": cores[0], "lua": cores[1],
                       "brilho": brilho[y0:y1, x0:x1] * (alfa > 0.02)})

    # folha (prateleiras, mais alto primeiro)
    LARG = 1024
    pos = {}
    x = y = alt = 0
    for c in sorted(caixas, key=lambda c: -c["tam"][1]):
        w, h = c["tam"]
        if x + w > LARG:
            x = 0
            y += alt + 2
            alt = 0
        pos[c["nome"]] = (x, y)
        x += w + 2
        alt = max(alt, h)
    ALT = int(np.ceil((y + alt) / 4.0) * 4)
    for modo in ("sol", "lua"):
        folha = np.zeros((ALT, LARG, 4), np.float32)
        for c in caixas:
            px, py = pos[c["nome"]]
            w, h = c["tam"]
            folha[py:py + h, px:px + w, :3] = c[modo]
            folha[py:py + h, px:px + w, 3] = c["alfa"] * 255
        gravar(folha, "egito_planos_%s.png" % modo)
    br = np.zeros((ALT, LARG), np.float32)
    for c in caixas:
        px, py = pos[c["nome"]]
        w, h = c["tam"]
        br[py:py + h, px:px + w] = c["brilho"] * 255
    gravar(br, "egito_planos_brilho.png")

    # dados para o jogo
    linhas = []
    for c in caixas:
        px, py = pos[c["nome"]]
        linhas.append('\t{"nome": "%s", "canto": Vector2(%d, %d), "folha": Rect2(%d, %d, %d, %d), "z": %.3f},' % (
            c["nome"], c["canto"][0], c["canto"][1], px, py, c["tam"][0], c["tam"][1], c["z"]))
    gd = '''class_name EgitoPlanos
extends RefCounted

## Gerado por tools/gerar_camadas.py — não editar à mão.
## Planos do Egito (longe -> perto): onde cada recorte fica na imagem do
## fundo (canto, px da imagem 1024x1536), onde está na folha
## (sprites/egito_planos_sol.png / _lua.png / _brilho.png) e a distância Z.

const PLANOS := [
%s
]
''' % "\n".join(linhas)
    with open(os.path.join(SC, "egito_planos.gd"), "w", encoding="utf-8") as f:
        f.write(gd)
    print("  scripts/egito_planos.gd (%d planos, folha %dx%d)" % (len(caixas), LARG, ALT))


# ───────────────────────────────────────────── Mar
MAR_PEDRAS = [("esq", (0, 466), (238, 471)), ("dir", (523, 523), (428, 710))]


def mar():
    img = ler("atlantis_jogo.png")
    H, W = img.shape[:2]
    tira = np.zeros((H, W), np.uint8)
    print("Mar: pedras")
    for nome, canto, tam in MAR_PEDRAS:
        msk = np.asarray(Image.open(os.path.join(SP, "mar_pedra_%s_mascara.png" % nome)).convert("RGBA"))
        b = msk[..., 2].astype(np.float32) / 255.0
        x0, y0 = canto
        w, h = tam
        corte = img[y0:y0 + h, x0:x0 + w].astype(np.float32)
        alfa = np.clip((b - 0.35) / 0.3, 0, 1)
        gravar(np.dstack([corte, alfa * 255]), "mar_pedra_%s.png" % nome)
        t = (b > 0.25).astype(np.uint8)
        tira[y0:y0 + h, x0:x0 + w] |= cv2.dilate(t, k(4))
    bgr = cv2.inpaint(cv2.cvtColor(img, cv2.COLOR_RGB2BGR), tira * 255, 7, cv2.INPAINT_TELEA)
    rec = cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB).astype(np.float32)
    ruido = cv2.GaussianBlur(np.random.default_rng(5).standard_normal((H, W)).astype(np.float32), (0, 0), 0.8) * 5.0
    rec = rec + (ruido * cv2.GaussianBlur(tira.astype(np.float32), (0, 0), 2.0))[..., None]
    gravar(np.clip(rec, 0, 255), "atlantis_fundo.png")


# ───────────────────────────────────────────── luz da energia
def _luz(rgb):
    """Quanto a luz vermelha da energia (cristal, feixes, pontas) pinta cada
    pixel, medido na noite: o resto da cena é azul e cinza, então o que sobra
    de vermelho (em proporção ao claro do pixel: o halo escuro atrás do cristal
    conta também) é a luz do cristal no chão, nos degraus e nos obeliscos."""
    f = cv2.GaussianBlur(rgb.astype(np.float32) / 255.0, (0, 0), 1.5)
    ex = f[..., 0] - np.maximum(f[..., 1], f[..., 2])
    taxa = ex / (f[..., 0] + 0.05)
    luz = np.clip((taxa - 0.12) / 0.30, 0.0, 1.0) * np.clip(f[..., 0] / 0.07, 0.0, 1.0)
    # e o claro quase branco onde o feixe encosta (de noite só a energia é
    # tão clara assim abaixo do céu)
    lum = f @ np.array([0.3, 0.59, 0.11], np.float32)
    luz = np.maximum(luz, np.clip((lum - 0.55) / 0.25, 0.0, 1.0))
    return cv2.GaussianBlur(luz, (0, 0), 2.0)


def luz_egito():
    """sprites/egito_fundo_luz.png (L, meia resolução) e o canal G da folha
    egito_planos_brilho.png: onde a luz do cristal bate. Quando o cristal (ou
    um lado) apaga, o jogo tira essa luz da imagem (shaders/deserto_fundo e
    egito_plano), e o chão, os degraus e os obeliscos ficam no escuro."""
    lua = np.asarray(Image.open(os.path.join(SP, "egito_fundo_lua.png")).convert("RGB"))
    H, W = lua.shape[:2]
    luz = _luz(lua)
    luz[:600] = 0.0          # o céu (lua, estrelas, pontas de ouro) não é luz do cristal
    gravar((cv2.resize(luz, (W // 2, H // 2), interpolation=cv2.INTER_AREA) * 255 + 0.5), "egito_fundo_luz.png")
    folha = np.asarray(Image.open(os.path.join(SP, "egito_planos_lua.png")).convert("RGBA"))
    br = np.asarray(Image.open(os.path.join(SP, "egito_planos_brilho.png")))
    if br.ndim == 3:
        br = br[..., 0]
    luz_f = _luz(folha[..., :3]) * (folha[..., 3] > 5)
    gravar(np.dstack([br, luz_f * 255 + 0.5, np.zeros_like(br)]), "egito_planos_brilho.png")


if __name__ == "__main__":
    qual = sys.argv[1] if len(sys.argv) > 1 else "tudo"
    if qual in ("tudo", "egito"):
        egito()
    if qual in ("tudo", "egito", "luz"):
        luz_egito()
    if qual in ("tudo", "mar"):
        mar()
