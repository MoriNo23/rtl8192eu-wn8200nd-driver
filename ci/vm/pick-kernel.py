#!/usr/bin/env python3
"""Selecciona paquetes del kernel de Debian en el indice de trixie.

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

Uso:
    pick-kernel.py <Packages> image      -> ruta del .deb de linux-image
    pick-kernel.py <Packages> headers    -> ruta del .deb de linux-headers

IMPORTANTE: el paquete de headers NO se llama `linux-headers-6.12-amd64`. En
Debian lleva la version completa: `linux-headers-6.12.107+deb13-amd64`. Ese
nombre inventado hizo fallar el job de build contra Debian y el de la VM.
"""
import re
import sys

# "6.12.<upstream>+deb<rel>-amd64", y opcionalmente el sufijo de flavour
# (cloud, rt) que NO queremos: son kernels recortados.
KERNEL_RE = re.compile(r"^linux-image-6\.12\.(\d+)\+deb13(?:-amd64|-amd64)$")
HEADERS_RE = re.compile(r"^linux-headers-6\.12\.(\d+)\+deb13-amd64$")


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


def pick(pkgs: dict, pattern: re.Pattern):
    """Devuelve (nombre, metadata) de la version mas nueva que case."""
    best = None
    for name, meta in pkgs.items():
        m = pattern.match(name)
        if not m:
            continue
        key = (int(m.group(1)), meta.get("Version", ""))
        if best is None or key > best[0]:
            best = (key, name, meta)
    return best


def main() -> int:
    if len(sys.argv) < 3:
        print(__doc__, file=sys.stderr)
        return 2
    index, what = sys.argv[1], sys.argv[2]
    pkgs = parse_index(index)

    pattern = {"image": KERNEL_RE, "headers": HEADERS_RE}.get(what)
    if pattern is None:
        print(f"ERROR: modo '{what}' desconocido (use image|headers)",
              file=sys.stderr)
        return 2

    best = pick(pkgs, pattern)
    if not best:
        print(f"ERROR: no hay linux-{what} 6.12 en el indice",
              file=sys.stderr)
        return 1

    _, name, meta = best
    fn = meta.get("Filename")
    if not fn:
        print(f"ERROR: {name} no tiene campo Filename", file=sys.stderr)
        return 1
    # Nombre y ruta, en ese orden, para que el script los lea linea a linea.
    print(name)
    print(fn)
    return 0


if __name__ == "__main__":
    sys.exit(main())
