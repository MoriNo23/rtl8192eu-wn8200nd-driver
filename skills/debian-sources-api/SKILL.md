---
name: debian-sources-api
description: API JSON de sources.debian.org (Debsources) para inspeccionar el código fuente real de cualquier paquete Debian, incluidos los parches de distro. Úsala cuando necesites saber qué código ejecuta de verdad una distro, no el upstream.
---

# sources.debian.org (Debsources) — API JSON

Debsources indexa el **código fuente completo de todos los paquetes de todas las suites de
Debian**, incluidos los parches que Debian aplica sobre el upstream. Expone una interfaz
HTML y una API JSON.

- Servicio: `https://sources.debian.org`
- Docs de la API: `https://sources.debian.org/doc/api/`
- Repo (Debsources): `https://salsa.debian.org/qa/debsources`
- Sub-apps: `/patches/` (parches de paquetes quilt 3.0) y `/copyright/`

## Endpoints

```
GET /api/ping/
GET /api/list/
GET /api/prefix/{prefix}/
GET /api/search/{query}/
GET /api/src/{package}/
GET /api/src/{package}/{version}/
GET /api/src/{package}/{version}/{path}/
GET /api/info/package/{package}/{version}/
GET /api/sha256/?checksum={sha}
GET /api/ctag/?ctag={identificador}
```

Cualquier URL de navegación se convierte en API anteponiendo `/api`.

## Ejemplos

```bash
# ¿qué versiones del paquete hay y en qué suites?
curl -s https://sources.debian.org/api/src/linux/ | jq '.versions[] | {version, suites}'

# listar un directorio del árbol de fuentes
curl -s https://sources.debian.org/api/src/linux/6.12.30-1/net/wireless/ | jq '.content[].name'

# obtener un fichero concreto (JSON con metadatos; para el raw usa /data/)
curl -s 'https://sources.debian.org/api/src/linux/6.12.30-1/net/wireless/nl80211.c/' | jq 'keys'
curl -s 'https://sources.debian.org/data/main/l/linux/6.12.30-1/net/wireless/nl80211.c'

# buscar dónde está definido un identificador (índice ctags)
curl -s 'https://sources.debian.org/api/ctag/?ctag=cfg80211_ops' \
  | jq '.results[] | select(.package=="linux") | "\(.version) \(.path):\(.line)"'

# metadatos: tamaño, sloc por lenguaje, licencias
curl -s https://sources.debian.org/api/info/package/linux/6.12.30-1/ | jq .

# identificar de qué paquete y versión proviene un fichero por su hash
curl -s 'https://sources.debian.org/api/sha256/?checksum=<sha256>' | jq '.results.packages'
```

## Los parches de distro: el caso de uso decisivo

```bash
# lista de parches que Debian aplica sobre el upstream
curl -s https://sources.debian.org/api/patches/summary/linux/6.12.30-1/ | jq '.patches[].name'

# un parche concreto en crudo
curl -s https://sources.debian.org/patches/linux/6.12.30-1/<nombre>.patch/
```

Esto responde la pregunta que ninguna otra fuente responde: **"¿este backport está en la
versión de la distro aunque no esté en el upstream de ese número de versión?"**

## Issues conocidos por la comunidad

| Problema | Detalle |
|---|---|
| La API no está versionada | el esquema puede cambiar; no hay contrato formal |
| El índice se actualiza unas pocas veces al día | paquetes recién subidos pueden faltar |
| `/api/src/.../fichero` devuelve metadatos, no el contenido | para el contenido crudo hay que usar la ruta `/data/...` |
| Rate limiting no documentado | scripting agresivo puede ser bloqueado |
| Paquetes enormes (linux, chromium) tardan en responder | acotar siempre por ruta concreta |
| Solo Debian | Ubuntu no está; para Ubuntu hay que usar Launchpad o `apt-get source` |
| El índice ctags no distingue bien símbolos homónimos entre paquetes | filtrar por `package` en el resultado |

## Tips y buenas prácticas

1. **Es la única forma cómoda de verificar un backport de distro** sin descargar el `.dsc` completo. Si tu código compila contra un kernel de Debian y no contra vanilla, la respuesta está en `/patches/`.
2. `/api/ctag/` como buscador global de símbolos entre paquetes: útil para encontrar quién más implementa una API.
3. Usa `/api/info/package/` para obtener el conteo de líneas por lenguaje: sirve como métrica objetiva del tamaño de un componente.
4. La búsqueda por `sha256` identifica ficheros vendorizados: si un proyecto copió un fichero de otro, este endpoint lo delata.
5. Cachea agresivamente: el contenido de una versión concreta es inmutable por definición.
6. Para trabajo pesado, `apt-get source <pkg>` en un contenedor de la suite correcta es más rápido que cientos de peticiones.
7. Combínala con la API de kernel.org: kernel.org te dice qué hay en vanilla, Debsources te dice qué hay realmente en la distro. La diferencia entre ambas es donde viven los bugs de "en mi máquina compila".
