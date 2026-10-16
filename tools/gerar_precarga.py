#!/usr/bin/env python3
"""Gera scripts/precarga.gd: para cada tela (scenes/*.tscn), a lista dos
arquivos que os scripts dela carregam com load() durante o _ready e a lista
dos shaders que ela usa.

A TransicaoGlobal pede esses arquivos numa thread junto com a cena; quando a
cena monta, os load() já acham tudo pronto e a tela não congela. Os shaders
são montados na placa um por quadro, ainda com o cartão de carregamento na
tela (scripts/aquecedor.gd).

Rodar de novo sempre que um script passar a carregar arquivos novos:
    python3 tools/gerar_precarga.py
"""
import os
import re
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EXTS = ("png", "jpg", "jpeg", "webp", "svg", "wav", "ogg", "mp3", "ttf", "otf",
        "tres", "res", "tscn", "ogv")
LITERAL = re.compile(r'"(res://[^"%{}*]+\.(?:' + "|".join(EXTS) + r'))"')
SCRIPT = re.compile(r'\[ext_resource type="Script"[^\]]*path="(res://[^"]+\.gd)"')
CLASSE = re.compile(r'^class_name\s+(\w+)', re.M)
SCRIPT_LITERAL = re.compile(r'"(res://scripts/[^"]+\.gd)"')
# preload() já é dependência do script: vem junto com a cena na thread dela.
# Pedir de novo em paralelo fazia duas threads lerem o mesmo arquivo (às vezes
# a leitura falhava e a cena caía no carregamento travado).
PRELOAD = re.compile(r'preload\(\s*"(res://[^"]+)"\s*\)')
# FundoVivo carrega só os fundos pedidos: FundoVivo.new(["init", ...]).
FUNDO_VIVO = "res://scripts/fundo_vivo.gd"
FUNDO_ITEM = re.compile(r'^\t"(\w+)": \["(res://[^"]+)", "(res://[^"]+)"', re.M)
# O anunciador de combos carrega as vozes da tela pedida:
# ComboAnuncio.criar(self, "mar") -> songs/voz/mar_*.ogg
ANUNCIO = re.compile(r'ComboAnuncio\.criar\(\s*\w+\s*,\s*"(\w+)"\s*\)')
SHADER = re.compile(r'"(res://shaders/[^"]+\.gdshader)"')
# O do vídeo pelo hardware (samplerExternalOES) só monta com o vídeo de verdade.
SHADER_FORA = {"res://shaders/video_oes.gdshader"}


def arquivo(res):
    return os.path.join(RAIZ, res[len("res://"):])


def hd(res):
    """Fundo com versão em alta (sprites/hd/<nome>.res, scripts/hd.gd): a
    tela carrega o .res no lugar do png."""
    if res.startswith("res://sprites/") and res.endswith(".png"):
        alta = "res://sprites/hd/" + os.path.basename(res)[:-4] + ".res"
        if os.path.exists(arquivo(alta)):
            return alta
    return res


def classes():
    """class_name -> script (componentes criados por código, ex.: FundoVivo)."""
    mapa = {}
    pasta = os.path.join(RAIZ, "scripts")
    for nome in sorted(os.listdir(pasta)):
        if nome.endswith(".gd"):
            with open(os.path.join(pasta, nome), encoding="utf-8") as f:
                m = CLASSE.search(f.read())
            if m:
                mapa[m.group(1)] = "res://scripts/" + nome
    return mapa


def scripts_usados(iniciais, mapa):
    """Os scripts da tela e os componentes (class_name) que eles usam."""
    vistos = []
    fila = list(iniciais)
    while fila:
        s = fila.pop(0)
        if s in vistos or not os.path.exists(arquivo(s)):
            continue
        vistos.append(s)
        with open(arquivo(s), encoding="utf-8") as f:
            texto = f.read()
        for nome, caminho in mapa.items():
            if caminho not in vistos and re.search(r"\b" + nome + r"\b", texto):
                fila.append(caminho)
        # componentes sem class_name, pegos pelo caminho (ex.: MarVida)
        for caminho in SCRIPT_LITERAL.findall(texto):
            if caminho not in vistos:
                fila.append(caminho)
    return vistos


def fundos_vivos():
    with open(arquivo(FUNDO_VIVO), encoding="utf-8") as f:
        return {m.group(1): [m.group(2), m.group(3)] for m in FUNDO_ITEM.finditer(f.read())}


def literais_fundo_vivo(texto, fundos):
    """Arquivos dos fundos que este script pede ao FundoVivo (chaves entre aspas)."""
    if "FundoVivo.new(" not in texto:
        return []
    saida = []
    for chave, arqs in fundos.items():
        if '"%s"' % chave in texto:
            saida += arqs
    return saida


def shaders_fundo_vivo(texto, fundos):
    """Shaders dos fundos que este script pede ao FundoVivo: o do deserto
    tem o seu, os outros usam o fundo_vivo."""
    if "FundoVivo.new(" not in texto:
        return []
    saida = []
    for chave in fundos:
        if '"%s"' % chave in texto:
            sh = "res://shaders/deserto_fundo.gdshader" if chave == "deserto" else "res://shaders/fundo_vivo.gdshader"
            if sh not in saida:
                saida.append(sh)
    # na qualidade leve todos os fundos usam este (a TransicaoGlobal monta só
    # os shaders da qualidade em uso)
    if saida:
        saida.append("res://shaders/fundo_vivo_leve.gdshader")
    return saida


def vozes_anuncio(texto):
    saida = []
    for tela in ANUNCIO.findall(texto):
        pasta = os.path.join(RAIZ, "songs", "voz")
        if os.path.isdir(pasta):
            saida += ["res://songs/voz/" + n for n in sorted(os.listdir(pasta))
                      if n.startswith(tela + "_") and n.endswith(".ogg")]
    return saida


def main():
    mapa = classes()
    fundos = fundos_vivos()
    pasta = os.path.join(RAIZ, "scenes")
    lista = {}
    shaders = {}
    for nome in sorted(os.listdir(pasta)):
        if not nome.endswith(".tscn"):
            continue
        cena = "res://scenes/" + nome
        with open(os.path.join(pasta, nome), encoding="utf-8") as f:
            texto_cena = f.read()
        scripts = SCRIPT.findall(texto_cena)
        achados = []
        usados = []
        for s in scripts_usados(scripts, mapa):
            caminho = arquivo(s)
            with open(caminho, encoding="utf-8") as f:
                texto = f.read()
            # o FundoVivo só monta os shaders dos fundos pedidos (abaixo);
            # quem só usa FundoVivo.brilho_redondo() não monta nenhum
            if s != FUNDO_VIVO:
                for sh in SHADER.findall(texto) + shaders_fundo_vivo(texto, fundos):
                    if sh not in usados and sh not in SHADER_FORA and os.path.exists(arquivo(sh)):
                        usados.append(sh)
            if s == FUNDO_VIVO:
                continue   # os fundos entram pelas chaves pedidas (abaixo)
            ja_vem = set(PRELOAD.findall(texto))
            for res in LITERAL.findall(texto) + literais_fundo_vivo(texto, fundos) + vozes_anuncio(texto):
                if res in ja_vem and texto.count('"%s"' % res) == 1:
                    continue
                res = hd(res)
                # outras telas não: só o que esta tela usa
                if res.startswith("res://scenes/") or res == cena:
                    continue
                if not os.path.exists(arquivo(res)) or res in achados:
                    continue
                achados.append(res)
        if achados:
            lista[cena] = achados
        # shaders das peças (entities/*.tscn) que a tela monta
        pecas = [r for r in achados if r.endswith(".tscn")]
        for peca in pecas:
            with open(arquivo(peca), encoding="utf-8") as f:
                texto_peca = f.read()
            for s in scripts_usados(SCRIPT.findall(texto_peca), mapa):
                if s == FUNDO_VIVO:
                    continue
                with open(arquivo(s), encoding="utf-8") as f:
                    texto_s = f.read()
                    for sh in SHADER.findall(texto_s) + shaders_fundo_vivo(texto_s, fundos):
                        if sh not in usados and sh not in SHADER_FORA and os.path.exists(arquivo(sh)):
                            usados.append(sh)
            for sh in SHADER.findall(texto_peca):
                if sh not in usados and sh not in SHADER_FORA:
                    usados.append(sh)
        for sh in SHADER.findall(texto_cena):
            if sh not in usados and sh not in SHADER_FORA:
                usados.append(sh)
        if usados:
            shaders[cena] = usados

    linhas = [
        "extends RefCounted",
        "",
        "# GERADO por tools/gerar_precarga.py — não editar à mão.",
        "# Arquivos que cada tela carrega no _ready; a TransicaoGlobal os pede",
        "# numa thread junto com a cena.",
        "",
        "const LISTA := {",
    ]
    for cena, itens in lista.items():
        linhas.append('\t"%s": [' % cena)
        for res in itens:
            linhas.append('\t\t"%s",' % res)
        linhas.append("\t],")
    linhas.append("}")
    linhas += [
        "",
        "# Shaders de cada tela: montados na placa um por quadro, debaixo do",
        "# cartão de carregamento (scripts/aquecedor.gd).",
        "const SHADERS := {",
    ]
    for cena, itens in shaders.items():
        linhas.append('\t"%s": [' % cena)
        for res in itens:
            linhas.append('\t\t"%s",' % res)
        linhas.append("\t],")
    linhas.append("}")
    saida = os.path.join(RAIZ, "scripts", "precarga.gd")
    with open(saida, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(linhas) + "\n")
    total = sum(len(v) for v in lista.values())
    print("precarga.gd: %d telas, %d arquivos" % (len(lista), total))
    for cena, itens in lista.items():
        print("  %-28s %d" % (cena, len(itens)))
    print("shaders:")
    for cena, itens in shaders.items():
        print("  %-28s %s" % (cena, ", ".join(os.path.basename(i) for i in itens)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
