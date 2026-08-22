---
name: coccinelle-spatch
description: Transformaciones semánticas masivas de código C con Coccinelle (spatch) y el lenguaje SmPL. Úsala para refactorizar cientos de ficheros C respetando la estructura del código en lugar de usar sed/regex.
---

# Coccinelle (spatch)

Motor de *semantic patching* para C. En vez de casar texto, casa **estructura sintáctica y
flujo de control**, con metavariables. Es la herramienta estándar para refactors masivos en
bases de código C grandes.

- Repo: `https://github.com/coccinelle/coccinelle`
- Docs: `https://coccinelle.gitlabpages.inria.fr/website/`
- Licencia: GPLv2 · escrito en OCaml · autora principal del ecosistema: Julia Lawall (Inria)

## Instalación

```bash
# Debian/Ubuntu
sudo apt install coccinelle
# Fedora
sudo dnf install coccinelle
# Desde fuente (necesitas OCaml + opam)
git clone https://github.com/coccinelle/coccinelle
cd coccinelle && ./autogen && ./configure && make && sudo make install
spatch --version
```

## Anatomía de un semantic patch (.cocci)

```cocci
// regla con nombre, metavariables declaradas entre @@
@replace_alloc@
expression ptr, size;
@@
- ptr = malloc(size);
- memset(ptr, 0, size);
+ ptr = calloc(1, size);
```

Elementos que hay que dominar:

```cocci
@@
expression E;      // cualquier expresión
identifier f;      // nombre de función/variable
type T;            // un tipo
statement S;       // una sentencia
constant C;        // literal
local idexpression x;   // variable local
position p;        // posición (para reporting)
@@
```

### Los 4 patrones que resuelven el 90% de los casos

**1. Cambiar la firma de una función en todas las llamadas**
```cocci
@@
expression a, b;
@@
- old_api(a, b)
+ new_api(a, b, NULL)
```

**2. Eliminar un argumento inútil**
```cocci
@@
identifier f;
expression a, b;
@@
- f(a, b, 0)
+ f(a, b)
```

**3. Borrar código muerto: una función que ya no se llama**
```cocci
@nocall@
identifier f;
@@
f(...) { ... }

@depends on nocall@
identifier nocall.f;
@@
- f(...) { ... }
```

**4. Modo *report* — auditar sin modificar** (ideal como primer paso de un refactor)
```cocci
@r depends on report@
expression e;
position p;
@@
kmalloc@p(e, ...)

@script:python depends on report@
p << r.p;
@@
coccilib.report.print_report(p[0], "kmalloc encontrado aquí")
```

## Uso en línea de comandos

```bash
# dry-run: ver el diff sin tocar nada
spatch --sp-file fix.cocci --dir src/ 

# aplicar in-place
spatch --sp-file fix.cocci --dir src/ --in-place

# paralelizar (imprescindible en árboles grandes)
spatch --sp-file fix.cocci --dir . --in-place -j "$(nproc)"

# incluir headers para resolver tipos
spatch --sp-file fix.cocci --dir . --include-headers \
       -I include/ -I /usr/include

# generar parche unificado en vez de modificar
spatch --sp-file fix.cocci --dir . > cambios.patch
```

Modo *isomorphisms* (por defecto): trata `!x`, `x == NULL` y `NULL == x` como equivalentes.
Desactívalo con `--no-loops` / `--iso-file /dev/null` si genera falsos positivos.

## Issues conocidos por la comunidad

| Problema | Causa | Mitigación |
|---|---|---|
| `spatch` se cuelga o tarda minutos en un fichero | ficheros enormes con macros anidadas; el parser hace backtracking | `--timeout 120`, trocear el directorio, `-j` |
| "parse error" en ficheros que compilan bien | macros no expandidas que rompen la gramática C | declararlas en un fichero `--macro-file-builtins` |
| No casa nada y no dice por qué | metavariable con tipo demasiado estricto (`identifier` donde hace falta `expression`) | ejecutar con `--debug` o relajar a `expression` |
| Rompe la indentación / borra comentarios adyacentes | el pretty-printer reescribe la región tocada | ejecutar `clang-format` sobre los ficheros modificados después |
| Resultado distinto entre versiones de spatch | cambios en isomorfismos por defecto | fijar la versión en el proyecto y anotarla en el repo |
| Consume varios GB de RAM | `--include-headers` sobre árboles grandes | limitar con `--dir` por subdirectorio |

## Tips y buenas prácticas

1. **Siempre en dos fases**: primero una regla en modo `report` para contar ocurrencias, luego la regla que transforma. Nunca transformes a ciegas.
2. **Un `.cocci` por transformación**, versionado en el repo junto al commit que lo aplicó. El semantic patch es la documentación del refactor.
3. **Commit separado por regla**: si algo se rompe, el `git bisect` te lleva a la regla exacta.
4. `...` significa "cualquier cosa en medio, incluido nada"; `<... ...>` significa "cero o más apariciones dentro". Confundirlos es el error de novato más común.
5. Usa `depends on` para encadenar reglas y evitar recorrer el árbol dos veces.
6. Tras aplicar, **compila y pasa un linter**: Coccinelle garantiza sintaxis válida, no semántica correcta.
7. Para cambios que dependen de la versión de una librería/kernel, genera **una regla por versión** en vez de meter condicionales dentro de una sola.
8. `spatch --parse-c fichero.c` valida si el parser entiende el fichero antes de escribir la regla.

## Recursos

- Colección de semantic patches reales por subsistema: `https://github.com/groeck/coccinelle-patches`
- El árbol de Linux incluye >80 reglas en `scripts/coccinelle/`, invocables con `make coccicheck`
- Imagen Docker lista: `docker pull philmd/coccinelle`
