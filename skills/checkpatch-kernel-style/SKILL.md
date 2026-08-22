---
name: checkpatch-kernel-style
description: Uso de scripts/checkpatch.pl y del resto de scripts de análisis del árbol de Linux (get_maintainer, coccicheck, sparse) como gate de estilo y corrección para cualquier código C de bajo nivel.
---

# checkpatch.pl y los scripts del árbol de Linux

El directorio `scripts/` del kernel contiene herramientas maduras que **funcionan sobre
cualquier código C**, no solo sobre el kernel. checkpatch es la más útil: detecta cientos
de patrones problemáticos en un diff, no solo cuestiones de estilo.

- Fuente: `https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/tree/scripts/checkpatch.pl`
- Licencia: GPLv2
- Dependencias: Perl y, opcionalmente, `spelling.txt` y `const_structs.checkpatch`

## Obtenerlo sin clonar el kernel entero

```bash
BASE=https://raw.githubusercontent.com/torvalds/linux/master/scripts
mkdir -p tools/checkpatch && cd tools/checkpatch
curl -O $BASE/checkpatch.pl
curl -O $BASE/spelling.txt
curl -O $BASE/const_structs.checkpatch
chmod +x checkpatch.pl
```

## Uso

```bash
# sobre un parche
./checkpatch.pl parche.patch

# sobre ficheros sueltos (fuera del kernel hace falta --no-tree)
./checkpatch.pl --no-tree -f src/core.c

# sobre el último commit
git format-patch -1 --stdout | ./checkpatch.pl -

# sobre un rango de commits
git format-patch origin/main..HEAD --stdout | ./checkpatch.pl -

# solo errores, sin avisos de estilo menor
./checkpatch.pl --no-tree --strict --terse -f src/*.c | grep ERROR

# aplicar correcciones automáticas (revisar SIEMPRE el diff después)
./checkpatch.pl --no-tree --fix-inplace -f src/core.c
```

Flags relevantes:

| Flag | Efecto |
|---|---|
| `--no-tree` | no exige estar dentro de un árbol del kernel |
| `-f` / `--file` | analiza ficheros completos, no diffs |
| `--strict` | activa comprobaciones adicionales (CHECK) |
| `--terse` | una línea por hallazgo |
| `--ignore=TIPO,TIPO` | silencia categorías concretas |
| `--max-line-length=N` | ajusta el límite (100 en el kernel moderno) |
| `--fix-inplace` | aplica los arreglos que sabe hacer |
| `--codespell` | activa el diccionario de erratas |
| `--show-types` | muestra el identificador de cada regla (necesario para poder ignorarla) |

## Qué detecta que de verdad importa (más allá del estilo)

| Tipo | Problema real |
|---|---|
| `MEMORY_BARRIER` | barrera sin comentario explicativo |
| `LOCKDEP` | uso incorrecto de primitivas de bloqueo |
| `MULTISTATEMENT_MACRO_USE_DO_WHILE` | macro con varias sentencias sin `do{}while(0)` |
| `MACRO_ARG_REUSE` | argumento de macro evaluado dos veces |
| `SIZEOF_PARENTHESIS` / `ALLOC_SIZEOF_STRUCT` | `sizeof` mal aplicado en asignaciones |
| `OPEN_ENDED_LINE` / `TRAILING_STATEMENTS` | control de flujo ambiguo |
| `UNNECESSARY_ELSE` | `else` tras `return` |
| `PREFER_KERNEL_TYPES` | mezcla de tipos de ancho inconsistentes |
| `SPDX_LICENSE_TAG` | falta la cabecera de licencia |
| `EMBEDDED_FUNCTION_NAME` | `__func__` mejor que el nombre a mano |

## Otros scripts aprovechables fuera del kernel

```bash
scripts/get_maintainer.pl --no-tree -f fichero.c   # a quién avisar (necesita MAINTAINERS)
scripts/coccicheck                                  # ejecuta scripts/coccinelle/*.cocci
scripts/decode_stacktrace.sh                        # simboliza un backtrace
scripts/bloat-o-meter viejo.o nuevo.o               # delta de tamaño por símbolo ← muy útil
scripts/checkstack.pl                               # funciones que consumen más pila
scripts/faddr2line vmlinux funcion+0x1a/0x2b        # dirección → fichero:línea
scripts/extract-vmlinux                             # descomprime un kernel
scripts/spelling.txt                                # diccionario de erratas comunes en C
```

`bloat-o-meter` merece mención aparte: compara dos objetos y te dice **qué símbolos
crecieron o desaparecieron**. Es la forma objetiva de verificar que una poda de código
realmente eliminó código y no solo lo movió.

```bash
scripts/bloat-o-meter antes/core.o despues/core.o
# add/remove: 0/12 grow/shrink: 1/3 up/down: 24/-4096 (-4072)
```

## Issues conocidos por la comunidad

| Problema | Detalle |
|---|---|
| Muy opinado sobre estilo kernel | fuera del kernel muchos avisos son irrelevantes; hay que construir una lista `--ignore` propia |
| `--fix-inplace` puede romper código | especialmente con macros y alineaciones manuales; revisar el diff sin excepción |
| Falsos positivos con tablas alineadas | avisa de espacios "sobrantes" que son deliberados |
| Diseñado para parches, no para ficheros | con `-f` genera mucho más ruido del habitual |
| Cambia entre versiones del kernel | reglas nuevas aparecen y el CI empieza a fallar sin que hayas tocado nada |
| No es un analizador semántico | no sustituye a Sparse, Smatch ni clang-tidy |
| `get_maintainer.pl` inútil sin fichero MAINTAINERS | fuera del kernel no aporta |

## Tips y buenas prácticas

1. **Fija la versión de checkpatch.pl** en tu repo (`tools/checkpatch/`) en vez de descargar la de master: si no, el CI se rompe solo cuando upstream añade una regla.
2. Construye tu lista de exclusiones con `--show-types` y documenta **por qué** ignoras cada tipo.
3. Ejecútalo sobre el **diff**, no sobre ficheros completos: la señal por ruido es infinitamente mejor.
4. Úsalo como gate de commits nuevos, no como deuda a saldar en código heredado.
5. `bloat-o-meter` antes/después es la métrica de éxito de cualquier refactor de poda: si no baja el tamaño, no eliminaste nada real.
6. `checkstack.pl` para código con pila limitada: revela funciones con arrays enormes en stack que nadie había notado.
7. checkpatch cubre el "cómo se escribe"; Sparse/Smatch/clang-tidy cubren el "qué hace". Necesitas ambos y no se solapan.
