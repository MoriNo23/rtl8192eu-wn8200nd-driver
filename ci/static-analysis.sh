#!/bin/bash
# static-analysis.sh — ejecuta sparse / smatch / checkpatch sobre driver/
# y compara el resultado contra un baseline versionado.
#
# USO
#   ci/static-analysis.sh <herramienta> [--update-baseline]
#
#   sparse      Análisis de tipos (paquete `sparse` de la distro)
#   smatch      Análisis de valores (smatch construido desde fuente)
#   checkpatch  Estilo del kernel (checkpatch.pl del linux-source)
#
#   --update-baseline  Escribe el recuento actual en el baseline en vez de
#                       comparar. Es el ÚNICO modo en que el baseline cambia,
#                       y por tanto la actualización es siempre explícita.
#
# CÓMO FUNCIONA EL BASELINE
# El driver es un árbol de vendor: checkpatch sobre driver/ produce miles de
# avisos heredados de Realtek. Un job en blanco estaría rojo desde el primer día
# y nadie lo miraría. El baseline convierte el job en una alerta de REGRESIÓN:
# falla solo ante hallazgos nuevos.
#
# Las líneas del baseline se normalizan a la forma
#     <ruta relativa al repo> <mensaje>
# sin número de línea ni columna. Motivo: los números de línea cambian con cada
# commit (incluso un comentario nuevo los desplaza) y el objetivo es detectar
# hallazgos NUEVOS, no reubicar los viejos. Un hallazgo que se mueve de línea no
# es una regresión; uno nuevo sí.
#
# El fichero tiene tres secciones, una por herramienta, delimitadas por "## <tool>".
# Cada herramienta solo compara contra la suya, y solo ella modifica la suya.
#
# Si el baseline no existe, o la sección de la herramienta falta o está vacía, el
# script FALLA. Sin esa comprobación, borrar el fichero convertiría el job en un
# no-op silencioso, que es el fallo clásico de este patrón.
set -uo pipefail

TOOL="${1:-}"
UPDATE=0
[ "${2:-}" = "--update-baseline" ] && UPDATE=1

# --all: las tres herramientas en una sola invocacion. Existe por rendimiento,
# no por comodidad: checkpatch sobre driver/ tarda ~13 min (591 ficheros, uno a
# uno), asi que generar y verificar por separado son ~30 min de trabajo que se
# repite. Con --all, cada herramienta se ejecuta UNA vez y de su salida salen
# las tres secciones.
if [ "$TOOL" = "--all" ]; then
    # RAW_DIR se comparte entre las sub-invocaciones para poder inspeccionar la
    # salida cruda de las tres herramientas cuando algo falle.
    export RAW_DIR="${RAW_DIR:-$(mktemp -d)}"
    UPD=""
    [ "$UPDATE" -eq 1 ] && UPD="--update-baseline"
    for t in sparse smatch checkpatch; do
        "$0" "$t" $UPD || { echo "ERROR: fallo la herramienta $t" >&2; exit 1; }
    done
    exit 0
fi

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BASELINE="$REPO_ROOT/ci/static-analysis-baseline.txt"
RAW_DIR="${RAW_DIR:-$(mktemp -d)}"

# Binarios. Los defaults apuntan a donde los deja el job de CI; se pueden
# sobreescribir por entorno para depurar en local.
SMATCH_BIN="${SMATCH_BIN:-/opt/smatch/smatch}"
CHECKPATCH="${CHECKPATCH:-/opt/lksrc/scripts/checkpatch.pl}"
# Para sparse no hay default: se busca en el PATH (run_sparse lo hace).

die() { echo "ERROR: $*" >&2; exit 1; }

case "$TOOL" in
    sparse|smatch|checkpatch) ;;
    *) die "herramienta no valida: '$TOOL' (use sparse|smatch|checkpatch)" ;;
esac

# --- localizacion de KVER/KSRC -------------------------------------------
# Se recorren /lib/modules del mas nuevo al mas viejo buscando un arbol de
# headers con Makefile utilizable. Es la misma deteccion que hace el job `build`.
detect_kver() {
    local d
    for d in $(ls -1 /lib/modules 2>/dev/null | sort -V -r); do
        if [ -f "/lib/modules/$d/build/Makefile" ]; then echo "$d"; return 0; fi
    done
    return 1
}

# --- construccion del driver con la herramienta como compilador ----------
# sparse y smatch se integran en kbuild: sparse vía C=1/CHECK=, smatch vía CC=.
#
# IMPORTANTE: se invoca `make -C driver ... all`, NO `make -C $(KSRC) M=...`.
# El Makefile del repo tiene dos ramas (la de Kbuild y la que envuelve al
# build del kernel) y la rama `all:` es la que exporta CONFIG_RTL8192EU=m. Sin
# esa exportacion, `obj-$(CONFIG_RTL8192EU)` queda vacio y kbuild no compila
# NADA: el build "pasa" sin analizar un solo fichero. Es un falso verde.
build_with() {
    local kver="$1" ksrc="$2"; shift 2
    make -C "$REPO_ROOT/driver" clean >/dev/null 2>&1
    make -C "$REPO_ROOT/driver" -j"$(nproc)" all \
        KVER="$kver" KSRC="$ksrc" "$@" 2>&1
}

# Comprobacion de que el build analizo algo. Sin esto, un fallo que impida
# compilar (flags mal, headers que no cuadran) se traduce en CERO hallazgos, y
# cero hallazgos con el filtro de normalizacion se traduce en un job VERDE que
# no ha mirado un solo fichero. Se mira el numero de .o antes y despues.
assert_compiled() {
    local tool="$1"
    local n
    n=$(find "$REPO_ROOT/driver" -name '*.o' -not -name '*.mod.o' | wc -l)
    if [ "$n" -lt 50 ]; then
        echo "ERROR: $tool solo produjo $n objetos. El build no analizo el arbol." >&2
        echo "       (un fallo de compilacion se confundiria con 'sin hallazgos')" >&2
        exit 1
    fi
    echo "build analizado: $n objetos"
}

run_sparse() {
    # sparse viene del paquete de la distro, NO del arbol de smatch: el
    # `sparsec` de smatch es un wrapper que delega en sparse-llvm, que no se
    # compila sin LLVM, y sin el se limita a imprimir "llvm-config: not found"
    # seguido de errores de enlace. El sparse de la distro es el que usa el
    # propio kernel. Se respeta SPARSE_BIN si viene definido.
    local bin="${SPARSE_BIN:-}"
    if [ -z "$bin" ]; then bin="$(command -v sparse || true)"; fi
    [ -n "$bin" ] && [ -x "$bin" ] || die "sparse no encontrado (instala el paquete 'sparse')"
    echo "sparse: $bin"
    local kver ksrc
    kver="$(detect_kver)" || die "no hay arbol de headers en /lib/modules"
    ksrc="/lib/modules/$kver/build"
    # C=1 CHECK=: kbuild pasa a CHECK la linea de compilacion completa, que es
    # la forma que el propio kernel documenta para el analisis externo. Poner la
    # herramienta como CC= en su lugar NO funciona aqui: el CC no llega al make
    # anidado que invoca el Makefile de este driver.
    build_with "$kver" "$ksrc" C=1 CHECK="$bin"
}

run_smatch() {
    [ -x "$SMATCH_BIN" ] || die "smatch no encontrado en $SMATCH_BIN"
    local kver ksrc
    kver="$(detect_kver)" || die "no hay arbol de headers en /lib/modules"
    ksrc="/lib/modules/$kver/build"
    # Mismo mecanismo que sparse: C=1 CHECK= con la ruta completa de smatch y sus
    # opciones. Sin --project no hay base de datos cruzada, pero smatch sigue
    # dando avisos por fichero, que es lo que el baseline necesita.
    build_with "$kver" "$ksrc" \
        C=1 CHECK="$SMATCH_BIN --full-path --project=kernel --spammy"
}

run_checkpatch() {
    [ -r "$CHECKPATCH" ] || die "checkpatch.pl no encontrado en $CHECKPATCH"
    # -f (--file) es OBLIGATORIO y va POR DELANTE de la lista de ficheros:
    # sin el, checkpatch trata la entrada como un PATCH y no encuentra nada
    # (imprime el ascii-art de "Your patch" y sale sin un solo hallazgo), lo
    # que haria que el filtro de normalizacion no tuviera nada que filtrar.
    # --terse: una linea por hallazgo, que es lo que se normaliza y compara.
    # --no-tree: el arbol no es linux/, checkpatch se quejaria de la estructura.
    # Orden estable (LC_ALL=C sort) para que el baseline sea reproducible.
    ( cd "$REPO_ROOT/driver" && \
      find . \( -name '*.c' -o -name '*.h' \) -type f | LC_ALL=C sort | \
      xargs -r "$CHECKPATCH" --no-tree --terse -f 2>&1 )
}

# --- normalizacion -------------------------------------------------------
# Se conservan SOLO las lineas que son un hallazgo, y de cada una se queda
# "fichero: mensaje", sin numero de linea ni columna.
#
# Los TRES formatos reales, medidos sobre la salida de este repo (no supuestos):
#
#   sparse     driver/core/rtw_debug.c:44:9: warning: msg
#              la columna va tras dos puntos, SIN corchetes
#   smatch     driver/core/rtw_cmd.c:1067 rtw_joinbss_cmd() warn: msg
#              formato propio de smatch: fichero:linea FUNCION() warn:
#   checkpatch driver/core/rtw_ap.c:9: WARNING: msg
#
# Quitar el numero de linea es lo que hace que el baseline sobreviva a los
# commits que desplazan lineas: un hallazgo que se mueve de linea no es una
# regresion, uno nuevo si. Y se descarta todo lo demas que las herramientas
# imprimen alrededor (el eco de make, el contexto de gcc, los rastros de
# include), que no es un hallazgo y ademas cambia con cada fichero del arbol.
# Se hace con awk y no con sed por un motivo concreto: sed necesita un
# delimitador para s///, y el patron necesita alternacion (warning|error) que
# usa el MISMO caracter. Con delimitador "|" el sed falla con "unknown option to
# s" y devuelve cero lineas, que el script interpretaria como "sin hallazgos" en
# lugar de como un fallo. awk no tiene ese problema.
extract_findings() {
    case "$1" in
    checkpatch)
        # driver/core/rtw_ap.c:9: WARNING: msg
        awk '{
            i = index($0, ":")
            if (i == 0) next
            rest = substr($0, i + 1)
            if (rest !~ /^[0-9]+: /) next
            file = substr($0, 1, i - 1)
            if (file !~ /\.[ch]$/) next
            # quita "N: " del principio
            sub(/^[0-9]+: /, "", rest)
            print file ": " rest
        }'
        ;;
    smatch)
        # Formato propio de smatch: driver/core/rtw_cmd.c:1067 rtw_joinbss_cmd() warn: msg
        awk '{
            i = index($0, ":")
            if (i == 0) next
            file = substr($0, 1, i - 1)
            if (file !~ /\.[ch]$/) next
            rest = substr($0, i + 1)
            if (rest !~ /^[0-9]+/) next
            sub(/^[0-9]+/, "", rest)
            gsub(/^[[:space:]]+/, "", rest)
            # quita la firma de la funcion, si aparece
            sub(/^[A-Za-z_][A-Za-z_0-9]*\(\)[[:space:]]+/, "", rest)
            if (rest !~ /^(warn|error|info): /) next
            print file ": " rest
        }'
        # Y el formato de gcc que smatch deja pasar tal cual:
        # driver/core/rtw_debug.c:44:9: warning: msg
        awk '{
            i = index($0, ":")
            if (i == 0) next
            file = substr($0, 1, i - 1)
            if (file !~ /\.[ch]$/) next
            rest = substr($0, i + 1)
            # descarta "N:col: " y "N: "
            if (rest !~ /^[0-9]+(:[0-9]+|\[[0-9, ]*\])?: /) next
            sub(/^[0-9]+(:[0-9]+|\[[0-9, ]*\])?: /, "", rest)
            if (rest !~ /^(warning|error): /) next
            print file ": " rest
        }'
        ;;
    *)
        # sparse: solo el formato de gcc.
        awk '{
            i = index($0, ":")
            if (i == 0) next
            file = substr($0, 1, i - 1)
            if (file !~ /\.[ch]$/) next
            rest = substr($0, i + 1)
            if (rest !~ /^[0-9]+(:[0-9]+|\[[0-9, ]*\])?: /) next
            sub(/^[0-9]+(:[0-9]+|\[[0-9, ]*\])?: /, "", rest)
            if (rest !~ /^(warning|error): /) next
            print file ": " rest
        }'
        ;;
    esac
}

# Descarta los hallazgos cuya ruta NO es de este arbol, y normaliza el resto.
#
# sparse y smatch analizan tambien las CABECERAS DEL KERNEL, y de ahi vienen
# hallazgos como:
#     /usr/src/linux-headers-6.17.0-1022-azure/include/uapi/linux/if_pppox.h:
#     warning: array of flexible structures
# No son codigo nuestro y cambian con la version de headers del runner: el
# primer run del job genero el baseline contra 6.8 y lo ejecuto contra 6.17, y
# por eso salian 324 hallazgos "nuevos" sin relacion con el driver. Un hallazgo
# de una cabecera del kernel no es una regresion de este repositorio.
#
# Solo se descartan rutas absolutas fuera del arbol. Las relativas se conservan,
# porque checkpatch y los demas ya recorren unicamente driver/.
normalize() {
    sed -e "s|^$REPO_ROOT/||" -e 's|^\./||' \
    | awk '
        # cabeceras del kernel y del sistema, en cualquier version
        /^\/usr\/src\//     { next }
        /^\/usr\/include\// { next }
        /^\/lib\/modules\// { next }
        { print }
    ' \
    | grep -v '^[[:space:]]*$' \
    | LC_ALL=C sort -u
}

# --- ejecucion y comparacion ---------------------------------------------
RAW="$RAW_DIR/$TOOL.raw"
NORM="$RAW_DIR/$TOOL.norm"

# Comprobacion TEMPRANA del baseline, antes de ejecutar la herramienta.
#
# No es una optimizacion menor: checkpatch sobre driver/ tarda ~13 min, asi que
# descubrir que el baseline no existe DESPUES de la ejecucion cuesta 13 min por
# herramienta y da la impresion de que el job se ha colgado. Con esta comprobacion
# previa, el fallo es inmediato y con un mensaje claro.
if [ "$UPDATE" -eq 0 ]; then
    if [ ! -f "$BASELINE" ]; then
        die "no existe $BASELINE. Generalo con: ci/static-analysis.sh $TOOL --update-baseline"
    fi
    if ! grep -q "^## $TOOL\$" "$BASELINE"; then
        die "el baseline no tiene seccion '## $TOOL'. Generala con --update-baseline"
    fi
    _bc=$(awk -v t="$TOOL" '/^## /{i=($2==t);next} /^#/{next} i' "$BASELINE" \
          | grep -c . || true)
    [ "$_bc" -gt 0 ] || die "la seccion '## $TOOL' del baseline esta vacia. \
Regenerala con: ci/static-analysis.sh $TOOL --update-baseline"
fi

# Preflight de las herramientas. Sin esto, el error "sparse no encontrado" o
# "checkpatch.pl no encontrado" se escribe DENTRO de $RAW, porque la llamada a
# la herramienta va con `> "$RAW" 2>&1`, y el script sale con 1 sin decir por
# que: el fallo clasico de "el job fallo y no se sabe". Se comprueba antes de
# la redireccion, para que el mensaje llegue al log.
preflight() {
    case "$1" in
        sparse)
            [ -n "${SPARSE_BIN:-}" ] || command -v sparse >/dev/null 2>&1 \
                || die "sparse no encontrado: instala el paquete 'sparse'"
            ;;
        smatch)
            [ -x "$SMATCH_BIN" ] || die "smatch no encontrado en $SMATCH_BIN"
            ;;
        checkpatch)
            [ -r "$CHECKPATCH" ] || die "checkpatch.pl no encontrado en $CHECKPATCH"
            ;;
    esac
}
[ "$UPDATE" -eq 0 ] && preflight "$TOOL"

case "$TOOL" in
    sparse|smatch)
        "run_$TOOL" > "$RAW" 2>&1
        assert_compiled "$TOOL"
        ;;
    checkpatch)
        "run_$TOOL" > "$RAW" 2>&1
        ;;
esac

# Filtro de las lineas de ruido de kbuild antes de normalizar.
sed -i \
    -e '/the compiler differs from the one used to build the kernel/d' \
    -e '/You are using:/d' \
    -e '/The kernel was built by:/d' \
    -e '/Entering directory/d' \
    -e '/Leaving directory/d' \
    "$RAW"

extract_findings "$TOOL" < "$RAW" | normalize > "$NORM"
COUNT=$(wc -l < "$NORM")

if [ "$COUNT" -eq 0 ]; then
    # Dos causas posibles y las dos son un fallo, no un "0 hallazgos":
    #   - el formato de la herramienta cambio y el filtro se queda vacio;
    #   - el build no compilo nada, que es el falso verde mas peligroso
    #     (ver la nota sobre CONFIG_RTL8192EU en build_with).
    echo "ERROR: $TOOL no produjo ningun hallazgo." >&2
    echo "       Si el build no compilo ficheros, el filtro no tiene nada que" >&2
    echo "       filtrar y el job pasaria en verde sin analizar nada." >&2
    echo "       Revisa la salida cruda en $RAW." >&2
    exit 1
fi

# --- extraccion/insercion de la seccion de esta herramienta ---------------
# El baseline es UN fichero con tres secciones, delimitadas por
# "## <herramienta>". Cada herramienta solo toca la suya, asi que actualizar una
# no revierte las otras dos.
extract_section() {   # imprime las entradas de la seccion $1
    awk -v t="$1" '
        /^## /        { in_s = ($2 == t) ; next }
        /^#/          { next }
        in_s          { print }
    ' "$BASELINE"
}

if [ "$UPDATE" -eq 1 ]; then
    touch "$BASELINE"
    # Si la seccion no existe todavia, se crea vacia al final.
    grep -q "^## $TOOL\$" "$BASELINE" || echo "## $TOOL" >> "$BASELINE"
    # Sustituye las entradas de la seccion de $TOOL por las actuales, dejando
    # intactas las secciones de las otras herramientas.
    awk -v t="$TOOL" -v newfile="$NORM" '
        BEGIN { while ((getline l < newfile) > 0) repl[++n] = l }
        /^## / {
            if (cur == t) { for (i = 1; i <= n; i++) print repl[i] }
            cur = $2 ; print
            next
        }
        { print }
        END { if (cur == t) for (i = 1; i <= n; i++) print repl[i] }
    ' "$BASELINE" > "$RAW_DIR/out.base" && mv "$RAW_DIR/out.base" "$BASELINE"
    echo "baseline de $TOOL actualizado: $COUNT hallazgos"
    exit 0
fi

# Modo verificacion: la seccion de esta herramienta debe existir y no estar
# vacia. Ya se comprobo ANTES de ejecutar la herramienta (mas arriba, para no
# gastar los ~13 min de checkpatch en descubrirlo tarde); aqui se revalida sobre
# el baseline ya leido, que es la comprobacion que gobierna el paso a paso.
if [ ! -f "$BASELINE" ]; then
    die "no existe $BASELINE. Generalo con: ci/static-analysis.sh $TOOL --update-baseline"
fi
grep -q "^## $TOOL\$" "$BASELINE" \
    || die "el baseline no tiene seccion '## $TOOL'. Generala con --update-baseline"

extract_section "$TOOL" | LC_ALL=C sort -u > "$RAW_DIR/base.norm"
BASE_COUNT=$(wc -l < "$RAW_DIR/base.norm")
[ "$BASE_COUNT" -gt 0 ] || die "la seccion '## $TOOL' del baseline esta vacia. \
Regenerala con: ci/static-analysis.sh $TOOL --update-baseline"

# Hallazgos nuevos = los de la ejecucion que no estan en el baseline de su
# herramienta. comm exige entrada ordenada, y las dos lo estan.
NEW="$RAW_DIR/$TOOL.new"
comm -13 "$RAW_DIR/base.norm" "$NORM" > "$NEW"
NEW_COUNT=$(wc -l < "$NEW")

echo "::group::$TOOL"
echo "baseline: $BASE_COUNT | actual: $COUNT | nuevos: $NEW_COUNT"
if [ "$NEW_COUNT" -gt 0 ]; then
    echo "--- hallazgos NUEVOS de $TOOL (no estan en el baseline) ---"
    head -50 "$NEW"
    [ "$NEW_COUNT" -gt 50 ] && echo "... y $((NEW_COUNT - 50)) mas"
    echo "::endgroup::"
    echo ""
    echo "::error title=$TOOL regression::$NEW_COUNT hallazgo(s) nuevo(s) de $TOOL"
    echo "Si son legitimos, actualiza el baseline de forma explicita:"
    echo "  ci/static-analysis.sh $TOOL --update-baseline"
    exit 1
fi
# Sin hallazgos nuevos: el job pasa. Se reporta el recuento, no se marca error.
echo "OK: sin hallazgos nuevos de $TOOL ($COUNT hallazgos, todos en el baseline)"
echo "::endgroup::"
exit 0
