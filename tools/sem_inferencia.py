#!/usr/bin/env python3
"""GDScript 1 (Godot 3) não infere o tipo de `var x := valor` quando o valor
vem de Array, Dictionary ou função sem tipo: troca `:=` por `=` em todos os
scripts (tipagem explícita `var x: tipo = ...` continua)."""
import glob
import re
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
n = 0
for p in glob.glob(str(RAIZ / "scripts" / "*.gd")):
    t = open(p, encoding="utf-8").read()
    t2 = re.sub(r"\b(var|const)(\s+[A-Za-z_][A-Za-z_0-9]*)\s*:=\s*", r"\1\2 = ", t)
    if t2 != t:
        n += 1
        open(p, "w", encoding="utf-8").write(t2)
print("arquivos ajustados:", n)
