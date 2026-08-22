---
name: iwyu-deheader
description: Poda de #include innecesarios con include-what-you-use y deheader. Úsala para reducir tiempos de compilación y acoplamiento en proyectos C con headers gigantes.
---

# include-what-you-use / deheader

Dos enfoques complementarios para el mismo problema: **headers que se incluyen y no se
usan**, y **símbolos que se usan sin incluir su header** (funcionan por inclusión transitiva
y se rompen en cuanto alguien reordena algo).

| Herramienta | Enfoque | Requiere |
|---|---|---|
| **IWYU** | análisis semántico con el AST de Clang | `compile_commands.json` |
| **deheader** | fuerza bruta: quita un include, recompila, ve si sigue funcionando | solo que el proyecto compile |

- IWYU: `https://github.com/include-what-you-use/include-what-you-use` (licencia NCSA)
- deheader: `https://gitlab.com/esr/deheader` (autor Eric S. Raymond, licencia BSD)

## include-what-you-use

### Instalación

```bash
sudo apt install iwyu
sudo dnf install iwyu
# desde fuente: la versión de IWYU debe coincidir con la mayor de Clang instalada
git clone https://github.com/include-what-you-use/include-what-you-use
cd include-what-you-use && git checkout clang_18
cmake -B build -DCMAKE_PREFIX_PATH=/usr/lib/llvm-18 && cmake --build build -j
```

### Uso

```bash
# un fichero
include-what-you-use -Xiwyu --no_comments src/core.c -- -I include

# todo el proyecto vía compilation database
iwyu_tool.py -p . -j "$(nproc)" > iwyu.out

# aplicar las sugerencias
fix_includes.py --nosafe_headers < iwyu.out

# solo reportar, ordenado por impacto
grep -c "should remove" iwyu.out
```

### Mapping files: la parte que todo el mundo ignora

IWYU sugiere el header "canónico" de cada símbolo y a menudo se equivoca con headers que
son fachadas. Se corrige con mappings:

```json
// proyecto.imp
[
  { "include": ["\"internal/detalles.h\"", "private", "\"api/publico.h\"", "public"] },
  { "symbol":  ["uint32_t", "private", "<stdint.h>", "public"] },
  { "include": ["<bits/types.h>", "private", "<sys/types.h>", "public"] }
]
```

```bash
include-what-you-use -Xiwyu --mapping_file=proyecto.imp src/core.c -- -I include
```

## deheader

```bash
git clone https://gitlab.com/esr/deheader && cd deheader && sudo make install

deheader -v                     # análisis del árbol actual
deheader -r src/                # recursivo
deheader -m "make -j8" src/     # usa tu comando de build real para verificar
deheader -x fichero_a_ignorar.c
deheader -i                     # aplica los cambios (¡tras revisar!)
```

Funciona quitando cada `#include` y recompilando. Lento pero **empíricamente correcto**: si
compila sin él, no hacía falta (con la configuración actual).

## Issues conocidos por la comunidad

| Problema | Detalle |
|---|---|
| IWYU sugiere headers internos/privados | necesita mapping files; sin ellos rompe encapsulación |
| IWYU falla con la versión de Clang equivocada | debe compilarse contra la misma mayor de Clang que hay instalada |
| `fix_includes.py` reordena includes | en C de bajo nivel el orden puede importar; usar `--reorder`/`--noreorder` conscientemente |
| IWYU no entiende `#include` dentro de `#ifdef` | puede sugerir quitar algo necesario en otra configuración |
| deheader es lentísimo | O(includes × tiempo de build); solo viable por subdirectorio |
| deheader solo valida la config actual | un include innecesario en x86 puede ser necesario en ARM o con otra flag |
| Ambos rompen builds condicionales | un header usado solo bajo `#ifdef DEBUG` desaparece |

## Tips y buenas prácticas

1. **Nunca apliques en bloque.** Genera el reporte, ordénalo por fichero y aplica por subdirectorio con un commit por lote.
2. **Compila todas las configuraciones** después de podar, no solo la tuya. Es donde se rompe.
3. deheader como **verificación** de lo que sugirió IWYU: si ambos coinciden, el include sobra de verdad.
4. Mide el beneficio antes y después: `time make -j1` en frío, y el tamaño del grafo de dependencias (`gcc -H` o `make -Bnd`).
5. Los *forward declarations* que sugiere IWYU son el mayor ahorro real de tiempo de compilación en C++, y ayudan menos en C puro: no persigas ese caso.
6. Ojo con los headers que existen **para ser fachada** (un `all.h` que reexporta): márcalos como públicos en el mapping o IWYU los desmontará.
7. Un `#include` de más cuesta tiempo de build; uno de menos cuesta una rotura en cuanto cambie otro fichero. El objetivo no es "menos includes" sino **includes explícitos y correctos**.
