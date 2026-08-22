---
name: bear-compilation-database
description: Generación de compile_commands.json con Bear (o compiledb/intercept-build) para proyectos con Make. Es el prerequisito de clang-tidy, clangd, IWYU y casi cualquier herramienta basada en Clang.
---

# Bear — compilation database

Bear (*Build EAR*) intercepta las llamadas al compilador durante un build normal y produce
`compile_commands.json`, el formato estándar que consumen las herramientas de Clang.

- Repo: `https://github.com/rizsotto/Bear`
- Licencia: GPLv3
- Alternativas: `compiledb` (`https://github.com/nickdiego/compiledb`, parsea la salida de make sin ejecutar), `intercept-build` (viene con clang-analyzer), `-MJ` de clang, `CMAKE_EXPORT_COMPILE_COMMANDS=ON`

## Instalación

```bash
sudo apt install bear
sudo dnf install bear
brew install bear
pip install compiledb          # alternativa pura Python
```

## Uso

```bash
# lo normal: prefijar el build completo
make clean
bear -- make -j"$(nproc)"
ls -la compile_commands.json

# Bear 2.x (sintaxis vieja, sin el --)
bear make -j4

# sin ejecutar el build, parseando la salida de make
make -Bnwk | compiledb -o compile_commands.json

# CMake lo genera nativamente
cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=ON -B build
ln -s build/compile_commands.json .
```

## Formato del fichero

```json
[
  {
    "directory": "/home/user/proyecto",
    "arguments": ["cc", "-c", "-I", "include", "-O2", "-o", "src/core.o", "src/core.c"],
    "file": "src/core.c",
    "output": "src/core.o"
  }
]
```

Alternativamente con `"command"` (string único) en vez de `"arguments"` (array). Ambos son
válidos; el array es más robusto porque no hay que reparsear el quoting.

## Post-procesado habitual

```bash
# ver qué ficheros quedaron cubiertos
jq -r '.[].file' compile_commands.json | sort | uniq | wc -l

# filtrar entradas de un subdirectorio
jq '[.[] | select(.file | contains("/src/"))]' compile_commands.json > cc-src.json

# quitar flags que clangd no entiende (cross-compile)
jq '[.[] | .arguments |= map(select(startswith("-mabi") | not))]' \
   compile_commands.json > tmp && mv tmp compile_commands.json

# rutas relativas -> absolutas (algunas herramientas lo exigen)
jq --arg d "$PWD" '[.[] | .directory = $d]' compile_commands.json
```

## Issues conocidos por la comunidad

| Problema | Detalle |
|---|---|
| Bear no ve nada y el JSON sale vacío | el build estaba cacheado: hay que hacer `make clean` antes, **siempre** |
| No funciona con ccache/distcc/sccache | el wrapper oculta la invocación real; desactivar el cache durante la corrida |
| Falla en macOS con SIP | System Integrity Protection bloquea la interposición de librerías; usar `intercept-build` o `-MJ` |
| Builds con sandbox (Bazel, Nix) | no hay interposición posible; esas herramientas tienen su propio generador |
| Rutas absolutas de la máquina que lo generó | `compile_commands.json` **no es portable**; no lo commitees, genéralo en cada máquina |
| Bear 2.x vs 3.x tienen CLI incompatible | 3.x exige `bear -- make`; los scripts viejos fallan en silencio |
| Entradas duplicadas por fichero | si un `.c` se compila con varias configuraciones; las herramientas usan la primera |
| Flags específicas de GCC rompen clang | `-fno-tree-loop-im`, `-mabi=...`: filtrarlas con jq o con `CompileFlags.Remove` en `.clangd` |

## Tips y buenas prácticas

1. **`make clean` antes de `bear`. Siempre.** El 90% de los "Bear no funciona" es un build incremental que no recompiló nada.
2. Añade `compile_commands.json` al `.gitignore`: contiene rutas absolutas y flags de la máquina local.
3. Automatiza su generación en un target del Makefile o un script `gen-compiledb.sh`, para que nadie tenga que recordar la sintaxis.
4. Si el proyecto compila para varias plataformas, genera **una base por configuración** (`cc-x86.json`, `cc-arm.json`) y apunta las herramientas a la que toque con `-p`.
5. `compiledb` es preferible cuando el build es muy lento: parsea `make -Bnwk` sin ejecutar nada realmente.
6. Verifica cobertura con `jq -r '.[].file' | wc -l` contra el número de `.c` del árbol: si falta la mitad, el build estaba parcialmente cacheado.
7. Con esta base ya funcionan: clangd, clang-tidy, include-what-you-use, clang-check, sourcetrail y cualquier LSP moderno. Es la inversión con mejor ratio de todo el tooling C.
