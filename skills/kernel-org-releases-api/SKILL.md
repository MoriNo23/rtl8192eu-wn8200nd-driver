---
name: kernel-org-releases-api
description: Consulta programática de versiones del kernel Linux — kernel.org/releases.json, git.kernel.org y la API de tags. Úsala para saber qué versiones están vivas, cuáles son LTS y hasta cuándo tienen soporte.
---

# kernel.org — versiones, releases y tags

## `releases.json`

El endpoint más simple y estable del ecosistema:

```bash
curl -s https://www.kernel.org/releases.json | jq .
```

```json
{
  "latest_stable": { "version": "6.x.y" },
  "releases": [
    {
      "version": "6.x.y",
      "moniker": "stable",          // mainline | stable | longterm | linux-next | eol
      "source": "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.x.y.tar.xz",
      "pgp": "...",
      "released": { "timestamp": 1710000000, "isodate": "2024-03-09" },
      "gitweb": "https://git.kernel.org/...",
      "changelog": "https://cdn.kernel.org/pub/linux/kernel/v6.x/ChangeLog-6.x.y",
      "diffview": "...",
      "iseol": false
    }
  ]
}
```

Consultas típicas:

```bash
# solo las LTS vivas
curl -s https://www.kernel.org/releases.json \
  | jq -r '.releases[] | select(.moniker=="longterm" and .iseol==false) | .version'

# la última stable
curl -s https://www.kernel.org/releases.json | jq -r '.latest_stable.version'

# ¿mi versión está EOL?
V=6.1.50
curl -s https://www.kernel.org/releases.json \
  | jq -r --arg v "${V%.*}" '.releases[] | select(.version|startswith($v)) | "\(.version) eol=\(.iseol)"'

# URL de descarga del tarball de la última longterm
curl -s https://www.kernel.org/releases.json \
  | jq -r '[.releases[] | select(.moniker=="longterm")][0].source'
```

## git.kernel.org (cgit)

```bash
BASE=https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git

curl -s "$BASE/patch/?id=<sha>"                       # el parche de un commit
curl -s "$BASE/plain/include/net/cfg80211.h?h=v6.12"  # un fichero en una etiqueta
curl -s "$BASE/atom/?h=master"                        # feed de commits
curl -s "$BASE/log/?qt=grep&q=set_monitor_channel"    # búsqueda en mensajes de commit
curl -s "$BASE/refs/tags"                             # listado de tags (HTML)
```

Árboles útiles del mismo host:

| Árbol | Para qué |
|---|---|
| `torvalds/linux.git` | mainline |
| `stable/linux-stable.git` | todas las ramas estables y sus tags |
| `next/linux-next.git` | lo que entrará en la próxima ventana de merge |
| `<subsistema>/...` | árboles por mantenedor (ej. `kvalo/wireless-drivers.git`) |

## Clonado eficiente para consultas

```bash
# clon superficial de una sola etiqueta (cientos de MB en vez de GB)
git clone --depth 1 --branch v6.12 \
  https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git

# solo metadatos, sin blobs: perfecto para arqueología de commits
git clone --filter=blob:none --no-checkout \
  https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git
cd linux-stable
git log -L :funcion:ruta/fichero.c        # historia de UNA función
git log --oneline v6.11..v6.12 -- net/wireless/
```

`git log -L :funcion:fichero` es la consulta definitiva para saber cuándo y por qué cambió
una función concreta.

## GitHub API sobre el espejo `torvalds/linux`

```bash
# buscar commits (necesita header de preview en algunas cuentas)
curl -s -H 'Accept: application/vnd.github+json' \
  'https://api.github.com/search/commits?q=repo:torvalds/linux+set_monitor_channel' | jq '.items[0]'

# comparar dos tags
curl -s 'https://api.github.com/repos/torvalds/linux/compare/v6.11...v6.12' \
  | jq '.files | length'
```

## Issues conocidos por la comunidad

| Problema | Detalle |
|---|---|
| `releases.json` no da fecha de fin de soporte | el calendario de EOL de las LTS está solo en la web (`kernel.org/category/releases.html`) |
| cgit tiene rate limiting estricto | descargas masivas deben ir por `cdn.kernel.org` o por clon |
| El espejo GitHub de `torvalds/linux` no tiene todas las ramas stable | para stable hay que ir a `git.kernel.org` o al espejo `gregkh/linux` |
| GitHub search API limita a 1000 resultados y ~30 req/min | inservible para barridos grandes |
| Los tarballs de kernel.org no incluyen la historia git | si necesitas `git log`, clona |
| Las versiones de distro **no** coinciden con las de kernel.org | Debian/Ubuntu retroportan cambios sin cambiar el número mayor.menor |

## Tips y buenas prácticas

1. **Nunca asumas que la versión de una distro se comporta como la vanilla del mismo número.** Un `6.12.101` de Debian puede contener backports de 6.13. Verifica con la API de sources.debian.org, no con kernel.org.
2. `--filter=blob:none --no-checkout` te da toda la historia para arqueología ocupando una fracción del espacio.
3. `git log -L :funcion:fichero.c` antes que cualquier búsqueda web: responde con precisión y offline.
4. Cachea `releases.json`: cambia como mucho unas pocas veces por semana.
5. Para saber si un cambio llegó a una LTS, consulta `linux-stable.git` y busca el `Upstream commit <sha>` en los mensajes: así se referencian los backports estables.
6. `cdn.kernel.org` es el host correcto para descargas automatizadas; `www.kernel.org` es para navegación.
7. Ten en cuenta la cadencia: mainline saca release cada ~9-10 semanas, y cada año la última suele designarse longterm. Planifica el soporte del código en función de eso, no de la última versión existente.
