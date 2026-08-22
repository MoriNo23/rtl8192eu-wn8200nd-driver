---
name: kernel-doc-and-api-references
description: Fuentes de referencia de APIs de kernel Linux consultables y su formato kernel-doc — docs.kernel.org, generación de documentación desde comentarios, y cómo verificar la firma exacta de una API en una versión concreta.
---

# Documentación de APIs de kernel: kernel-doc y docs.kernel.org

## El formato kernel-doc

Comentarios estructurados que se extraen automáticamente a documentación. Es el estándar
de facto para documentar APIs en C de bajo nivel, y funciona en cualquier proyecto que
copie `scripts/kernel-doc`.

```c
/**
 * funcion_ejemplo - resumen en una línea, sin punto final
 * @dev: dispositivo sobre el que se opera
 * @flags: máscara de banderas, ver &enum ejemplo_flags
 * @buf: buffer de salida, debe tener al menos %MAX_LEN bytes
 *
 * Descripción larga en párrafos. Se pueden referenciar otros símbolos:
 * &struct otra_estructura, funcion_relacionada(), %CONSTANTE, $ENV_VAR.
 *
 * Context: puede dormir. Debe llamarse con @dev->lock tomado.
 * Return: 0 en éxito, -EINVAL si @flags es inválido, -ENOMEM si no hay memoria.
 */
int funcion_ejemplo(struct device *dev, u32 flags, char *buf);

/**
 * struct ejemplo - descripción de la estructura
 * @campo1: para qué sirve
 * @campo2: para qué sirve
 *
 * Notas sobre el ciclo de vida y el bloqueo.
 */
struct ejemplo {
    int campo1;
    int campo2;
};
```

Marcadores reconocidos: `@param`, `Context:`, `Return:`, `Note:`, `Example:`, y referencias
`&struct x`, `&enum y`, `funcion()`, `%CONSTANTE`.

### Generar la documentación

```bash
# extraer a rst/man desde cualquier proyecto
curl -O https://raw.githubusercontent.com/torvalds/linux/master/scripts/kernel-doc
chmod +x kernel-doc
./kernel-doc -rst src/api.c > api.rst
./kernel-doc -man src/api.c | split -p '^\.TH' - man/
./kernel-doc -none src/api.c      # solo validar: reporta comentarios mal formados

# en el kernel
make htmldocs      # salida en Documentation/output/
make pdfdocs
make refcheckdocs  # detecta referencias rotas
```

`./kernel-doc -none` como gate de CI es barato y evita que la documentación se pudra.

## docs.kernel.org — referencias que hay que conocer

| URL | Contenido |
|---|---|
| `docs.kernel.org/driver-api/index.html` | índice de APIs de drivers |
| `docs.kernel.org/driver-api/80211/cfg80211.html` | cfg80211/nl80211 |
| `docs.kernel.org/driver-api/usb/usb.html` | USB core, URBs |
| `docs.kernel.org/networking/kapi.html` | net core, `net_device`, `sk_buff` |
| `docs.kernel.org/core-api/index.html` | memoria, locking, RCU, workqueues |
| `docs.kernel.org/process/coding-style.html` | estilo obligatorio |
| `docs.kernel.org/process/deprecated.html` | **patrones prohibidos hoy** |
| `docs.kernel.org/process/submitting-patches.html` | formato de commits y parches |
| `docs.kernel.org/doc-guide/kernel-doc.html` | especificación completa del formato |
| `docs.kernel.org/dev-tools/index.html` | sparse, coccinelle, kasan, kcsan, kmemleak |

Añadiendo `/v6.12/` al path se obtiene la documentación de una versión concreta:
`https://docs.kernel.org/v6.12/driver-api/...`

## Verificar la firma exacta de una API en una versión

El problema real no es "qué hace esta función" sino **"qué firma tiene en la versión contra
la que compilo"**. Flujo fiable:

```bash
# 1. localizar el prototipo
curl -s 'https://elixir.bootlin.com/api/ident/linux/set_monitor_channel?version=v6.12&family=C' | jq .

# 2. leer el fichero en esa versión
curl -s 'https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/plain/include/net/cfg80211.h?h=v6.12' \
  | grep -A5 set_monitor_channel

# 3. si es una distro, comprobar si retroportó el cambio
curl -s 'https://sources.debian.org/api/patches/summary/linux/<version>/' | jq '.patches[].name'

# 4. entender por qué cambió
curl -s 'https://lore.kernel.org/all/?q=dfhh:set_monitor_channel&x=A'
```

## Patrón de compatibilidad multiversión

```c
#include <linux/version.h>

#if (LINUX_VERSION_CODE >= KERNEL_VERSION(6, 13, 0))
    /* firma nueva */
#elif (LINUX_VERSION_CODE >= KERNEL_VERSION(5, 10, 0))
    /* firma intermedia */
#else
    /* firma antigua */
#endif
```

Alternativa mejor cuando hay muchos casos: el proyecto **backports**
(`git.kernel.org/pub/scm/linux/kernel/git/backports/backports.git`), que implementa las
compatibilidades en una capa aparte en vez de contaminar el código con condicionales.

## Issues conocidos por la comunidad

| Problema | Detalle |
|---|---|
| La documentación va por detrás del código | el código es la fuente de verdad; la doc es orientativa |
| `LINUX_VERSION_CODE` miente en distros | Debian/RHEL retroportan cambios de API manteniendo el número de versión — el bug clásico de los módulos out-of-tree |
| kernel-doc mal formado se ignora en silencio | sin `-none` en CI, la doc se degrada sin que nadie lo note |
| Referencias `&struct x` a símbolos inexistentes no fallan | usar `make refcheckdocs` |
| Las APIs internas no tienen garantía de estabilidad | solo el ABI de userspace es estable; todo lo demás puede cambiar en cualquier release |
| `docs.kernel.org` no tiene API JSON | hay que scrapear HTML o ir al fuente rst en el árbol |

## Tips y buenas prácticas

1. **Nunca confíes en `LINUX_VERSION_CODE` como único discriminante** si soportas distros. Añade comprobaciones de configuración en tiempo de build (probar a compilar un snippet) o consulta los parches de la distro.
2. Documenta con kernel-doc **el contrato de bloqueo y el valor de retorno** (`Context:` y `Return:`). Es lo que nadie deduce leyendo el código.
3. `kernel-doc -none` en CI: coste cero, evita que la documentación se pudra.
4. `docs.kernel.org/process/deprecated.html` debería leerse antes de cualquier refactor: lista los patrones que ya no se aceptan (`strcpy`, VLAs, `kmalloc` con multiplicación, etc.).
5. Para una API que vas a usar mucho, guarda en el repo un fichero con la firma exacta por versión soportada. Reconstruir esa tabla cada vez cuesta horas.
6. La documentación versionada (`/v6.12/`) evita el error de leer la doc de master y programar contra una API que aún no existe en tu target.
7. Si vas a mantener código out-of-tree contra muchos kernels, estudia cómo lo resuelve el proyecto backports antes de escribir tu enésimo `#if`.
