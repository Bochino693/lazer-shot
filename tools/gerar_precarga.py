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


def arquivo(res):
    return os.path.join(RAIZ, res[len("res://"):])


def main():
    pasta = os.path.join(RAIZ, "scenes")
    lista = {}
    for nome in sorted(os.listdir(pasta)):
        if not nome.endswith(".tscn"):
            continue
        cena = "res://scenes/" + nome
        with open(os.path.join(pasta, nome), encoding="utf-8") as f:
            scripts = SCRIPT.findall(f.read())
        achados = []
        for s in scripts:
            caminho = arquivo(s)
            if not os.path.exists(caminho):
                continue
            with open(caminho, encoding="utf-8") as f:
                for res in LITERAL.findall(f.read()):
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
