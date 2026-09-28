#!/usr/bin/env python3
"""Selecciona el .deb de linux-image correcto en el indice de Debian trixie.

Se hace en python y no en awk/grep por dos trampas concretas que ya costaron
tiempo:

  1. En un registro multilinea (awk RS=""), el `$` ancla al FINAL DEL REGISTRO,
     no al final de linea, asi que `/^Package: foo$/` no casa nunca.
  2. La version de Debian lleva un `+` (6.12.107+deb13), que en ERE es un
     cuantificador: hay que escaparlo, y segun como se escape cambia el
     significado. Y el `+` en BRE es literal, asi que el mismo patron funciona
     con grep y no con awk.

Ademas, filtrar el parrafo entero con `!/-dbg/` no vale: la DESCRIPCION de cada
paquete de kernel menciona su paquete -dbg, con lo que se excluirian todos. Hay
que mirar SOLO el campo Package.
"""
import re
import sys

# El nombre es "linux-image-6.12.<upstream>+deb13<->amd64": OJO, que despues de
# "deb13" NO hay numero de revision (a diferencia de "6.12.107-1"). Por eso el
# grupo de captura es el numero upstream, no el de debian.
CANDIDATE = re.compile(r"^linux-image-6\.12\.(\d+)\+deb13-amd64$")


def parse_index(path: str) -> dict:
    """Devuelve {nombre_de_paquete: {campo: valor}} del indice."""
    pkgs, cur = {}, {}
    with open(path, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            line = line.rstrip("\n")
            if not line:
                if cur.get("Package"):
                    pkgs[cur["Package"]] = cur
                cur = {}
                continue
            if line.startswith(" ") or line.startswith("\t"):
                continue  # continuacion de un campo multilinea
            if ":" in line:
                k, _, v = line.partition(":")
                cur[k.strip()] = v.strip()
    if cur.get("Package"):
        pkgs[cur["Package"]] = cur
    return pkgs


def main() -> int:
    index = sys.argv[1] if len(sys.argv) > 1 else "P"
    pkgs = parse_index(index)

    # Solo el paquete del kernel, no el -dbg (simbolos) ni el -unsigned, ni las
    # variantes cloud/rt. El regex ya excluye cloud y rt por el sufijo.
    best = None
    for name, meta in pkgs.items():
        m = CANDIDATE.match(name)
        if not m:
            continue
        key = (int(m.group(1)), meta.get("Version", ""))
        if best is None or key > best[0]:
            best = (key, name, meta)

    if not best:
        print("ERROR: no hay linux-image-6.12 en el indice", file=sys.stderr)
        return 1

    _, name, meta = best
    fn = meta.get("Filename")
    if not fn:
        print(f"ERROR: {name} no tiene campo Filename", file=sys.stderr)
        return 1
    print(name)
    print(fn)
    return 0


if __name__ == "__main__":
    sys.exit(main())
