#!/usr/bin/env python3
"""Gera scripts/precarga.gd: para cada tela (scenes/*.tscn), a lista dos
arquivos que os scripts dela carregam com load() durante o _ready.

A TransicaoGlobal pede esses arquivos numa thread junto com a cena; quando a
cena monta, os load() já acham tudo pronto e a tela não congela.

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
# FundoVivo carrega só os fundos pedidos: FundoVivo.new(["init", ...]).
FUNDO_VIVO = "res://scripts/fundo_vivo.gd"
FUNDO_ITEM = re.compile(r'^\t"(\w+)": \["(res://[^"]+)", "(res://[^"]+)"', re.M)


def arquivo(res):
    return os.path.join(RAIZ, res[len("res://"):])


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


def main():
    mapa = classes()
    fundos = fundos_vivos()
    pasta = os.path.join(RAIZ, "scenes")
    lista = {}
    for nome in sorted(os.listdir(pasta)):
        if not nome.endswith(".tscn"):
            continue
        cena = "res://scenes/" + nome
        with open(os.path.join(pasta, nome), encoding="utf-8") as f:
            scripts = SCRIPT.findall(f.read())
        achados = []
        for s in scripts_usados(scripts, mapa):
            caminho = arquivo(s)
            with open(caminho, encoding="utf-8") as f:
                texto = f.read()
            if s == FUNDO_VIVO:
                continue   # os fundos entram pelas chaves pedidas (abaixo)
            for res in LITERAL.findall(texto) + literais_fundo_vivo(texto, fundos):
                # outras telas não: só o que esta tela usa
                if res.startswith("res://scenes/") or res == cena:
                    continue
                if not os.path.exists(arquivo(res)) or res in achados:
                    continue
                achados.append(res)
        if achados:
            lista[cena] = achados

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
    saida = os.path.join(RAIZ, "scripts", "precarga.gd")
    with open(saida, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(linhas) + "\n")
    total = sum(len(v) for v in lista.values())
    print("precarga.gd: %d telas, %d arquivos" % (len(lista), total))
    for cena, itens in lista.items():
        print("  %-28s %d" % (cena, len(itens)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
