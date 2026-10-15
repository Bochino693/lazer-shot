#!/usr/bin/env python3
"""Egito com o cenário inteiro (Rodada 21).

Na Rodada 18 o fundo do Egito ganhou planos recortados (colunas, Anúbis,
obeliscos, cristal) e, atrás deles, um fundo reconstruído: quando a câmera
andava, cada plano se deslocava do fundo e aparecia o remendo. Agora a cena
anda inteira (scripts/deserto_vivo.gd), e por baixo de cada plano volta a
pintura original (deserto_sol.png / deserto_lua.png): plano e fundo são os
mesmos pixels, sem remendo nenhum. Fora dos planos fica o fundo de antes (sem
os feixes e os brilhos pintados, que agora são vivos e apagam quando o
cristal quebra).

  sprites/egito_fundo_sol.png, egito_fundo_lua.png        (1x)
  tools/hd/egito_fundo_sol@hd.png, egito_fundo_lua@hd.png (1,5x; depois
                                                           tools/gerar_hd.gd)
  sprites/egito_fundo_luz.png  G (onde as nuvens se mexem) sem os planos

    python3 tools/gerar_fundo_inteiro.py
"""
import os
import re
import numpy as np
import cv2
from PIL import Image

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SP = os.path.join(RAIZ, "sprites")
HD = os.path.join(RAIZ, "tools", "hd")


def planos():
    txt = open(os.path.join(RAIZ, "scripts", "egito_planos.gd")).read()
    out = []
    for m in re.finditer(r'"nome": "(\w+)", "canto": Vector2\((\d+), (\d+)\), "folha": Rect2\((\d+), (\d+), (\d+), (\d+)\)', txt):
        out.append((m.group(1), int(m.group(2)), int(m.group(3)), tuple(int(m.group(i)) for i in range(4, 8))))
    return out


def mascara_planos(forma):
    """Onde há plano (alfa da folha posto no lugar dele na imagem)."""
    folha = np.asarray(Image.open(os.path.join(SP, "egito_planos_sol.png")).convert("RGBA"))
    m = np.zeros(forma, np.float32)
    for nome, x, y, (fx, fy, fw, fh) in planos():
        a = folha[fy:fy + fh, fx:fx + fw, 3].astype(np.float32) / 255.0
        h, w = forma
        x1, y1 = min(w, x + fw), min(h, y + fh)
        m[y:y1, x:x1] = np.maximum(m[y:y1, x:x1], a[:y1 - y, :x1 - x])
    return m


def main():
    sol = np.asarray(Image.open(os.path.join(SP, "deserto_sol.png")).convert("RGB")).astype(np.float32)
    forma = sol.shape[:2]
    m = mascara_planos(forma)
    # a pintura original vai por baixo do plano e um pouco além da borda
    # dele (a borda do recorte é suave), sumindo devagar no fundo de antes
    duro = cv2.dilate((m > 0.02).astype(np.uint8), cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (13, 13)))
    peso = cv2.GaussianBlur(duro.astype(np.float32), (0, 0), 2.0)
    peso = np.maximum(peso, m)[..., None]
    for modo, orig in (("sol", "deserto_sol.png"), ("lua", "deserto_lua.png")):
        o = np.asarray(Image.open(os.path.join(SP, orig)).convert("RGB")).astype(np.float32)
        f = np.asarray(Image.open(os.path.join(SP, "egito_fundo_%s.png" % modo)).convert("RGB")).astype(np.float32)
        novo = f * (1 - peso) + o * peso
        Image.fromarray(np.clip(novo + 0.5, 0, 255).astype(np.uint8), "RGB").save(
            os.path.join(SP, "egito_fundo_%s.png" % modo), optimize=True)
        # a versão em alta: a pintura original ampliada (Lanczos) só onde o
        # plano cobre; o resto continua a super-resolução de antes
        caminho = os.path.join(HD, "egito_fundo_%s@hd.png" % modo)
        if os.path.exists(caminho):
            hd = np.asarray(Image.open(caminho).convert("RGB")).astype(np.float32)
            H, W = hd.shape[:2]
            o_hd = np.asarray(Image.fromarray(o.astype(np.uint8)).resize((W, H), Image.LANCZOS)).astype(np.float32)
            p_hd = cv2.resize(peso[..., 0], (W, H), interpolation=cv2.INTER_LINEAR)[..., None]
            hd = hd * (1 - p_hd) + o_hd * p_hd
            Image.fromarray(np.clip(hd + 0.5, 0, 255).astype(np.uint8), "RGB").save(caminho, optimize=True)
        print("egito_fundo_%s: pintura original por baixo dos planos" % modo)
    # as nuvens não se mexem em volta dos planos (o topo das colunas fica firme)
    luz = np.asarray(Image.open(os.path.join(SP, "egito_fundo_luz.png")).convert("RGB")).astype(np.float32)
    lh, lw = luz.shape[:2]
    perto = cv2.dilate((m > 0.02).astype(np.uint8), cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (31, 31))).astype(np.float32)
    perto = cv2.GaussianBlur(perto, (0, 0), 6.0)
    perto = cv2.resize(perto, (lw, lh), interpolation=cv2.INTER_AREA)
    luz[..., 1] *= 1.0 - np.clip(perto, 0, 1)
    Image.fromarray(np.clip(luz + 0.5, 0, 255).astype(np.uint8), "RGB").save(os.path.join(SP, "egito_fundo_luz.png"), optimize=True)
    print("egito_fundo_luz: nuvens paradas em volta dos planos")


if __name__ == "__main__":
    main()
