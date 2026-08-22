---
name: clang-tooling-c
description: clang-format, clang-tidy y clangd sobre proyectos C. Úsala para normalizar estilo, aplicar fix-its automáticos y tener navegación semántica en cualquier base de código C.
---

# Clang tooling para C (format / tidy / clangd)

Tres herramientas del mismo repo que comparten el frontend de Clang y el
`compile_commands.json`.

- Repo: `https://github.com/llvm/llvm-project`
- Docs: `https://clang.llvm.org/docs/ClangFormat.html`, `https://clang.llvm.org/extra/clang-tidy/`
- Licencia: Apache 2.0 con excepción LLVM

## Instalación

```bash
sudo apt install clang-format clang-tidy clangd bear
sudo dnf install clang-tools-extra clangd
# versionado explícito, recomendable para reproducibilidad
sudo apt install clang-format-18 clang-tidy-18
```

## clang-format

`.clang-format` en la raíz del proyecto. Ejemplo para C de bajo nivel estilo kernel:

```yaml
---
Language: Cpp
BasedOnStyle: LLVM
IndentWidth: 8
UseTab: Always
TabWidth: 8
ColumnLimit: 100
BreakBeforeBraces: Linux
AllowShortFunctionsOnASingleLine: None
AllowShortIfStatementsOnASingleLine: false
AlignEscapedNewlines: Left
PointerAlignment: Right
SpaceBeforeParens: ControlStatements
SortIncludes: false          # crítico en C de bajo nivel: el orden de includes importa
IndentPreprocessorDirectives: None
ForEachMacros: ['list_for_each_entry', 'hlist_for_each']
```

```bash
clang-format -i src/*.c                       # in-place
clang-format --dry-run --Werror src/*.c       # gate en CI
git diff -U0 --no-color HEAD^ | clang-format-diff -p1 -i   # solo lo tocado ← lo importante
```

**Regla de oro**: no reformatees ficheros enteros en un repo con historia. Usa
`clang-format-diff` sobre el diff y añade el commit de reformateo masivo (si lo haces) a
`.git-blame-ignore-revs`:

```bash
echo "<sha del reformateo>" >> .git-blame-ignore-revs
git config blame.ignoreRevsFile .git-blame-ignore-revs
```

## clang-tidy

Necesita `compile_commands.json` (ver skill `bear-compilation-database`).

```yaml
# .clang-tidy
Checks: >
  -*,
  bugprone-*,
  cert-*,
  clang-analyzer-*,
  misc-*,
  performance-*,
  readability-*,
  -readability-magic-numbers,
  -readability-identifier-length
WarningsAsErrors: 'bugprone-*'
HeaderFilterRegex: '^src/.*'
FormatStyle: file
```

```bash
clang-tidy src/core.c -p build/
clang-tidy -p build/ --fix --fix-errors src/*.c     # aplica fix-its
run-clang-tidy -p build/ -j "$(nproc)"              # paralelo sobre todo el proyecto
run-clang-tidy -p build/ -export-fixes fixes.yaml   # revisar antes de aplicar
clang-apply-replacements .                          # aplicar el yaml revisado
```

Checks especialmente valiosos en C:

| Check | Detecta |
|---|---|
| `bugprone-sizeof-expression` | `sizeof(ptr)` donde se quería `sizeof(*ptr)` |
| `bugprone-macro-parentheses` | macros sin paréntesis defensivos |
| `bugprone-signed-char-misuse` | `char` con signo usado como índice |
| `clang-analyzer-unix.Malloc` | fugas y doble free |
| `cert-err33-c` | valor de retorno ignorado en funciones que fallan |
| `misc-unused-parameters` | parámetros muertos (candidatos a poda) |
| `readability-non-const-parameter` | parámetros que deberían ser `const` |

## clangd

```yaml
# .clangd en la raíz
CompileFlags:
  Add: [-Wall, -I include]
  Remove: [-mabi=*, -fno-tree-loop-im]    # flags de cross-compile que clangd no entiende
Diagnostics:
  UnusedIncludes: Strict
  ClangTidy:
    Add: [bugprone-*]
```

Da "go to definition", "find references" y renombrado semántico en cualquier editor con LSP.
En un árbol de millones de líneas es la diferencia entre navegar y adivinar.

## Issues conocidos por la comunidad

| Problema | Detalle |
|---|---|
| clang-tidy no encuentra headers | falta `compile_commands.json` o tiene rutas absolutas de otra máquina |
| Flags de compiladores cruzados rompen clangd/clang-tidy | `-mabi`, flags específicas de gcc; se filtran con `CompileFlags.Remove` |
| `--fix` aplica cambios incorrectos en macros | los fix-its dentro de macros pueden corromper código; revisar siempre con `-export-fixes` primero |
| clang-format destroza tablas alineadas a mano | usar `// clang-format off` / `// clang-format on` alrededor |
| `SortIncludes: true` rompe código de bajo nivel | el orden de includes puede ser semánticamente significativo |
| Versiones distintas formatean distinto | fijar la versión exacta en CI y en el equipo, o el diff nunca converge |
| clang-tidy es lento | minutos por fichero con muchos checks; usar `run-clang-tidy -j` y `HeaderFilterRegex` estrecho |

## Tips y buenas prácticas

1. **Fija la versión mayor** de clang-format en el proyecto (`clang-format-18`) y documéntala: sin eso, cada desarrollador genera un diff distinto.
2. Formatea **solo lo que tocas** (`clang-format-diff`), salvo un único commit de reformateo global bien señalizado.
3. Empieza clang-tidy con `Checks: -*,bugprone-*` y ve añadiendo familias. Activar todo de golpe produce miles de warnings inútiles.
4. `WarningsAsErrors` solo para las familias que ya tienes limpias.
5. `HeaderFilterRegex` es obligatorio: sin él, clang-tidy analiza `/usr/include` y tarda eternidades.
6. Los fix-its automáticos son seguros para `readability-*` y peligrosos para `bugprone-*`: los segundos requieren juicio humano.
7. clangd + `compile_commands.json` es la forma más barata de auditar código ajeno: "find all references" responde en segundos preguntas que un grep no responde bien.
