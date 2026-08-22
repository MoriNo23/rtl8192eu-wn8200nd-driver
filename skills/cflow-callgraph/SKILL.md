---
name: cflow-callgraph
description: Extracción de grafos de llamadas en C con GNU cflow, gcc -fcallgraph-info y egypt. Úsala para detectar código inalcanzable y entender la topología de un módulo antes de refactorizarlo.
---

# GNU cflow y grafos de llamadas

Un grafo de llamadas responde dos preguntas que ninguna otra herramienta responde bien:
**¿qué código es inalcanzable desde los puntos de entrada?** y **¿cuál es la profundidad
real de este subsistema?**

- GNU cflow: `https://www.gnu.org/software/cflow/` (GPLv3)
- egypt (gcc RTL → dot): `https://www.gson.org/egypt/`
- gcc `-fcallgraph-info`: integrado en GCC ≥ 10
- Alternativa moderna: `clang -S -emit-llvm` + `opt -passes=dot-callgraph`

## Instalación

```bash
sudo apt install cflow graphviz
sudo dnf install cflow graphviz
cpan Egypt        # o descargar el script perl suelto
```

## GNU cflow

```bash
# grafo directo (quién llama a quién) desde main
cflow --main=main src/*.c

# grafo INVERSO: quién llama a esta función  ← el más útil para poda
cflow --reverse src/*.c

# limitar profundidad para que sea legible
cflow --depth=3 --main=main src/*.c

# solo funciones (omitir referencias a variables)
cflow --omit-arguments --omit-symbol-names src/*.c

# salida procesable
cflow --format=posix src/*.c
cflow --output=grafo.txt --all src/*.c

# preprocesar antes (necesario si hay macros que generan llamadas)
cflow --cpp='gcc -E -I include' src/*.c
```

Salida típica:

```
main() <int main (void) at src/main.c:12>:
    init_device() <int init_device (struct dev *d) at src/dev.c:44>:
        alloc_buffers() <int alloc_buffers (struct dev *d) at src/mem.c:20>:
            malloc()
    run_loop() <void run_loop (void) at src/main.c:60>:
        process() <void process (void) at src/proc.c:15>
```

## Detección de código inalcanzable

```bash
# 1. todas las funciones definidas
ctags -x --c-kinds=f --language-force=c src/*.c | awk '{print $1}' | sort -u > todas.txt

# 2. todas las alcanzables desde los puntos de entrada
cflow --main=main src/*.c | grep -oE '^\s*[a-zA-Z_][a-zA-Z0-9_]*' | tr -d ' ' | sort -u > alcanzables.txt

# 3. la diferencia son candidatas a poda
comm -23 todas.txt alcanzables.txt
```

**No borres directamente esa lista**: contiene callbacks, funciones exportadas y entradas
alternativas. Es una lista de *candidatas a investigar*.

## gcc / clang: grafos desde el compilador (más fiables)

```bash
# GCC >= 10: un .ci por unidad de compilación
gcc -fcallgraph-info=su,da -c src/core.c
# produce core.ci con el grafo real que vio el compilador

# vía RTL + egypt
gcc -fdump-rtl-expand -c src/*.c
egypt *.expand | dot -Tpng -o callgraph.png

# LLVM
clang -S -emit-llvm src/core.c -o core.ll
opt -passes=dot-callgraph core.ll -disable-output
dot -Tsvg callgraph.dot -o callgraph.svg
```

La ventaja del compilador frente a cflow: **ve el código después del preprocesador**, así
que no se pierde llamadas ocultas en macros.

## Warnings del compilador como detector de muertos

```bash
gcc -Wall -Wunused-function -Wunused-variable -Wmissing-prototypes \
    -Wunused-but-set-variable -c src/*.c 2>&1 | grep -E 'defined but not used'

# funciones globales sin usuarios (requiere LTO)
gcc -flto -Wl,--gc-sections -ffunction-sections -fdata-sections ...
```

## Issues conocidos por la comunidad

| Problema | Detalle |
|---|---|
| cflow no resuelve punteros a función | `ops->handler()` no se conecta con la implementación real; **subestima la alcanzabilidad** |
| cflow se pierde con macros | sin `--cpp` no ve llamadas generadas por macros; con `--cpp` el grafo se llena de ruido de headers del sistema |
| No entiende código C moderno con extensiones GCC | atributos y `_Generic` pueden causar parse errors |
| El grafo se vuelve ilegible pasando de 50 nodos | usar `--depth` y filtrar por subsistema |
| egypt depende de un formato RTL inestable | cambia entre versiones de GCC; puede dejar de parsear |
| Callbacks registrados en tablas quedan huérfanos | toda función referenciada solo por `.campo = funcion` aparece como inalcanzable |

## Tips y buenas prácticas

1. **Regla absoluta**: una función "inalcanzable" según el grafo debe verificarse con `grep -w nombre` en TODO el árbol antes de tocarla. Los punteros a función son la causa número uno de refactors rotos.
2. Genera el grafo **antes y después** del refactor y compara: nodos que desaparecen sin que los hayas borrado a propósito son una señal de alarma.
3. `cflow --reverse` sobre una función concreta es más útil que el grafo completo: te dice el radio de impacto exacto de cambiar su firma.
4. Usa `--depth=2` o `3` para documentación; el grafo completo solo sirve para procesado automático.
5. Combina la salida con Graphviz y `dot -Tsvg`: el SVG es navegable y buscable en el navegador.
6. En proyectos con plugins o registro dinámico, el grafo estático **siempre** miente por defecto. Complementa con cobertura en tiempo de ejecución (`gcov`).
7. Guarda el grafo del estado inicial como artefacto del refactor: es la mejor documentación de "cómo era esto antes".
