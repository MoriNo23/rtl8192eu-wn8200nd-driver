---
name: unifdef-coan
description: Eliminación física de ramas muertas del preprocesador C con unifdef y coan. Úsala para "aplanar" código lleno de #ifdef cuando una configuración es fija y quieres borrar todo lo que nunca se compila.
---

# unifdef / coan — poda de `#ifdef`

Herramientas que **evalúan condicionales del preprocesador según una configuración dada y
borran del fichero tanto las directivas como el código inalcanzable**, dejando el resto
intacto (a diferencia de `cpp -E`, que expande includes y macros y destroza la legibilidad).

- unifdef: `https://github.com/fanf2/unifdef` · autor Tony Finch · `https://dotat.at/prog/unifdef/`
- coan: `https://coan2.sourceforge.net/`
- Licencia unifdef: BSD 2 cláusulas
- Dato de contexto: el kernel de Linux usa unifdef para eliminar las secciones `#ifdef __KERNEL__` al exportar headers a userland

## Instalación

```bash
sudo apt install unifdef            # Debian/Ubuntu
sudo dnf install unifdef            # Fedora
brew install unifdef                # macOS
git clone https://github.com/fanf2/unifdef && cd unifdef && make && sudo make install
```

## Uso básico

```bash
# -D símbolo definido  ·  -U símbolo indefinido
unifdef -D__linux__ -UWIN32 -U__APPLE__ entrada.c > salida.c

# in-place sobre un árbol
find src -name '*.c' -o -name '*.h' | xargs unifdef -m -DFEATURE_A -UFEATURE_B

# conservar las líneas #ifdef pero comentar el código muerto (revisión previa)
unifdef -c -DFOO fichero.c

# resolver TODO lo resoluble y dejar lo demás intacto
unifdefall -I include/ fichero.c
```

Flags que importan:

| Flag | Efecto |
|---|---|
| `-D sym` / `-U sym` | define / indefine un símbolo |
| `-m` | modifica los ficheros in-place |
| `-c` | invierte: borra lo que se *habría* mantenido (útil para ver qué se pierde) |
| `-k` | evaluación laxa de `&&` y `\|\|` cuando hay símbolos desconocidos |
| `-B` | comprime líneas en blanco sobrantes tras la poda |
| `-f fichero` | lee las definiciones `#define`/`#undef` de un fichero |
| `-t` | modo texto plano: no interpreta comentarios ni strings de C |
| `-x 2` | código de salida 1 si hubo cambios (útil en scripts) |

**Códigos de salida**: `0` sin cambios · `1` hubo cambios · `2` error.

## coan: cuando hay demasiados símbolos

El punto débil de unifdef es que **hay que enumerar con `-U` todos los símbolos a
desactivar**. Con decenas de plataformas eso es inviable. coan resuelve esto con `-m`
(*implicit undef*): lo no declarado se considera indefinido.

```bash
coan source -DPLATFORM_X86 -m --replace src/*.c
coan spin  -DFEATURE_A src/     # genera un árbol nuevo ya podado
coan symbols --once src/        # inventario de todos los símbolos del preprocesador usados
```

`coan symbols` es la mejor forma de **auditar** qué condicionales existen antes de podar nada.

## Flujo recomendado para aplanar un árbol

```bash
# 1. inventario: qué símbolos existen y cuántas veces
grep -rhoE '#\s*(if|ifdef|ifndef|elif)[^\n]*' src/ | sort | uniq -c | sort -rn | head -50
coan symbols --once src/ > simbolos.txt

# 2. define la configuración objetivo en un fichero
cat > config.def <<'EOF'
#define FEATURE_A 1
#undef  FEATURE_B
#undef  LEGACY_PLATFORM
EOF

# 3. dry-run sobre UN fichero y revisa el diff a mano
unifdef -f config.def src/core.c | diff -u src/core.c - | less

# 4. aplica al árbol, un símbolo por commit
find src -name '*.[ch]' -print0 | xargs -0 unifdef -m -B -f config.def
git add -A && git commit -m "prune: FEATURE_B"

# 5. verifica que el binario resultante es equivalente
```

## Issues conocidos por la comunidad

| Problema | Detalle |
|---|---|
| No evalúa aritmética compleja del preprocesador | `#if (VER >= 30 && VER < 40)` con macros anidadas puede quedar sin resolver; unifdef lo deja intacto (comportamiento seguro) |
| `#if defined(A) \|\| defined(B)` con solo A conocido | sin `-k`, unifdef no toca la línea; con `-k` la resuelve de forma laxa (riesgo de decisión incorrecta) |
| Macros definidas con valor vs. definidas a secas | `-DFOO` no es lo mismo que `-DFOO=1` para un `#if FOO == 2` |
| Borra comentarios pegados a la directiva | los comentarios que explican el `#ifdef` desaparecen con él |
| GitHub releases del repo están incompletas | el autor avisa: descarga los tarballs desde `dotat.at/prog/unifdef` |
| sunifdef está muerto (sin cambios desde 2008) | usar coan, que es su sucesor declarado |
| unifdefall necesita los includes correctos | sin `-I` adecuados resuelve mal y silenciosamente |

## Tips y buenas prácticas

1. **Nunca podes sin haber hecho antes el inventario** (`coan symbols`). Vas a encontrar símbolos que creías muertos y están vivos en una rama anidada.
2. **Un símbolo por commit.** Si el build se rompe, sabes exactamente cuál fue.
3. Verifica **equivalencia binaria** antes/después cuando sea posible: compila las dos versiones con las mismas flags y compara el objeto desensamblado. Si el `.o` cambia, la poda alteró semántica.
4. Cuidado con los `#ifdef` **anidados dentro de otras condiciones**: un símbolo puede estar definido dentro del bloque de otro. Grepea el fichero de build, no solo el código.
5. `-B` después de podar: si no, quedan bloques de 5 líneas en blanco por todas partes.
6. Ejecuta `clang-format` inmediatamente después: la indentación de los bloques desanidados queda desalineada.
7. Para código con muchas plataformas, coan `spin` genera un árbol nuevo sin tocar el original — más seguro que `--replace`.
8. Guarda el fichero `config.def` en el repo: es la definición formal de "qué configuración soporta este árbol".
