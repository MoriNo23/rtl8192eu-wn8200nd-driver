---
name: code-navigation-cscope-global
description: Navegación e indexado de bases de código C grandes con cscope, GNU GLOBAL (gtags), universal-ctags y ripgrep. Úsala para responder "quién llama a esto" y "dónde se define" en árboles de millones de líneas.
---

# Navegación de código C: cscope / GNU GLOBAL / ctags

Antes de refactorizar hay que **entender el grafo de llamadas**. Estas herramientas
construyen índices consultables desde la terminal o el editor.

| Herramienta | Fuerte | Repo |
|---|---|---|
| **cscope** | consultas de "quién llama a X", "qué llama X" | `https://sourceforge.net/projects/cscope/` |
| **GNU GLOBAL (gtags)** | índice incremental, salida en varios formatos, HTML navegable | `https://www.gnu.org/software/global/` |
| **universal-ctags** | tags para editores, muchos lenguajes | `https://github.com/universal-ctags/ctags` |
| **ripgrep** | búsqueda textual instantánea | `https://github.com/BurntSushi/ripgrep` |

## Instalación

```bash
sudo apt install cscope global universal-ctags ripgrep
sudo dnf install cscope global ctags ripgrep
```

## cscope

```bash
# 1. lista de ficheros a indexar
find . -name '*.[chsS]' -not -path './build/*' > cscope.files

# 2. construir el índice (-b build, -q inverted index, -k sin headers del sistema)
cscope -b -q -k

# 3. interfaz interactiva
cscope -d

# 4. consultas no interactivas (para scripts)
cscope -dL -0 nombre_simbolo     # símbolo en cualquier contexto
cscope -dL -1 nombre_funcion     # definición global
cscope -dL -3 nombre_funcion     # funciones que LLAMAN a esta   ← la consulta clave
cscope -dL -2 nombre_funcion     # funciones llamadas POR esta
cscope -dL -6 "patron"           # egrep sobre el índice
cscope -dL -7 fichero.c          # ficheros que incluyen este fichero
```

Los números de `-L -N` son los mismos que los campos del menú interactivo. `-3` (callers)
es la consulta que decide si puedes borrar una función.

### Encontrar funciones sin llamadores (candidatas a poda)

```bash
# extrae todas las definiciones y comprueba si alguien las llama
ctags -x --c-kinds=f --language-force=c $(cat cscope.files) | awk '{print $1}' | sort -u |
while read -r fn; do
  n=$(cscope -dL -3 "$fn" | wc -l)
  [ "$n" -eq 0 ] && echo "SIN LLAMADORES: $fn"
done
```

## GNU GLOBAL

```bash
gtags                        # construye GTAGS, GRTAGS, GPATH
global -x main               # dónde se define
global -xr funcion           # referencias
global -xs simbolo           # símbolos no definidos aquí
global -f src/core.c         # todos los tags de un fichero
global -g "patron"           # grep indexado
global -u                    # actualización incremental tras editar

# genera un árbol HTML navegable de todo el código
htags -sanohIT --tree-view
```

`htags` es infravalorado: produce un sitio estático con hipervínculos entre definiciones y
usos, perfecto para auditar código ajeno sin editor.

## universal-ctags

```bash
ctags -R --languages=C --kinds-C=+p+x --fields=+niazS --extras=+q .
ctags -R --exclude=build --exclude='*.o' .
ctags -x --c-kinds=f src/core.c            # listado legible de funciones
ctags --list-kinds=C                       # qué se puede indexar
```

`.ctags` en la raíz para opciones persistentes:
```
--recurse=yes
--exclude=build
--exclude=.git
--languages=C
--kinds-C=+px
--fields=+niazS
```

## Issues conocidos por la comunidad

| Problema | Detalle |
|---|---|
| cscope no ve símbolos dentro de macros | el código generado por macros es invisible al índice; hay que grepear a mano |
| Llamadas indirectas por puntero a función no aparecen | `ops->send(x)` no se registra como llamada a la implementación concreta — **la trampa más peligrosa al borrar código** |
| Índice desactualizado tras editar | cscope no es incremental por defecto; GLOBAL sí (`global -u`) |
| `exuberant-ctags` está muerto | usar `universal-ctags`; muchas distros aún enlazan el viejo |
| cscope trunca líneas muy largas | el índice tiene límites de longitud heredados |
| GLOBAL requiere reindexado completo al cambiar de rama | usar un índice por worktree |
| Los tres se confunden con código bajo `#ifdef` | indexan todas las ramas, incluidas las que nunca se compilan |

## Tips y buenas prácticas

1. **Antes de borrar una función, comprueba tres cosas**: `cscope -dL -3` (llamadores directos), `rg '\bnombre\b'` (referencias textuales, incluidas asignaciones a punteros de función) y el fichero de build (puede referenciarse el `.o`).
2. Las **tablas de operaciones** (`struct xxx_ops = { .foo = mi_funcion }`) son el punto ciego de todos los indexadores. Grepea siempre el nombre desnudo además de la consulta de callers.
3. Regenera el índice en un hook de git (`post-checkout`, `post-merge`) o quedará mintiendo.
4. Combina: **ripgrep para la respuesta rápida, cscope para la respuesta correcta**.
5. `htags` para auditorías compartidas: mandas una URL en vez de instrucciones de instalación.
6. Excluye directorios de build del índice o los resultados se duplicarán con copias generadas.
7. Guarda `cscope.files` en el repo si el criterio de qué indexar no es trivial; los índices binarios (`cscope.out`, `GTAGS`) al `.gitignore`.
