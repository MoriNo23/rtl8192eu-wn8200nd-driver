---
name: repology-api
description: API de Repology para consultar en qué versión está un paquete en cientos de distribuciones a la vez. Úsala para decidir a qué versión mínima soportar y para detectar que una herramienta está obsoleta o abandonada.
---

# Repology — API de versiones entre distribuciones

Repology agrega los metadatos de paquetes de **más de 300 repositorios** (Debian, Ubuntu,
Fedora, Arch, Alpine, Homebrew, nixpkgs, FreeBSD ports, AUR, etc.) y los normaliza en
"proyectos" comparables.

- Servicio: `https://repology.org`
- Repo: `https://github.com/repology/repology-updater` (GPLv3)
- Docs API: `https://repology.org/api`

## Endpoints

```
GET /api/v1/project/{nombre}
GET /api/v1/projects/
GET /api/v1/projects/{nombre_desde}/
GET /api/v1/projects/?search=&inrepo=&outdated=1&families_newest=
GET /api/v1/repository/{repo}/problems
GET /api/v1/maintainer/{email}/problems-for-repo/{repo}
```

## Ejemplos

```bash
# ¿qué versión de una herramienta trae cada distro?
curl -s https://repology.org/api/v1/project/coccinelle \
  | jq -r '.[] | "\(.repo)\t\(.version)\t\(.status)"' | sort

# solo las versiones consideradas actuales
curl -s https://repology.org/api/v1/project/sparse \
  | jq -r '.[] | select(.status=="newest") | "\(.repo) \(.version)"'

# la versión en una distro concreta
curl -s https://repology.org/api/v1/project/clang \
  | jq -r '.[] | select(.repo|startswith("debian_")) | "\(.repo) \(.version)"'

# proyectos desactualizados de un mantenedor
curl -s 'https://repology.org/api/v1/projects/?maintainer=foo@example.com&outdated=1' | jq 'keys'

# paginación: los proyectos van en lotes; se itera con el último nombre
curl -s 'https://repology.org/api/v1/projects/coccinelle/' | jq 'keys | length'
```

Campos de cada entrada:

```json
{
  "repo": "debian_13",
  "srcname": "coccinelle",
  "binname": "coccinelle",
  "visiblename": "coccinelle",
  "version": "1.3",
  "origversion": "1.3-4",
  "status": "newest",        // newest | outdated | devel | legacy | unique | rolling | noscheme | incorrect | untrusted | ignored
  "summary": "semantic patching tool for C",
  "categories": ["devel"],
  "licenses": ["GPL-2.0-only"],
  "maintainers": ["..."]
}
```

## Casos de uso reales

```bash
# 1. Decidir la versión mínima soportable de una dependencia:
#    mira la versión de las LTS más usadas, no la última existente
for p in debian_12 debian_13 ubuntu_22_04 ubuntu_24_04 almalinux_9 alpine_3_20; do
  v=$(curl -s https://repology.org/api/v1/project/jq | jq -r --arg r "$p" \
      '.[] | select(.repo==$r) | .version' | head -1)
  echo "$p: ${v:-no empaquetado}"
done

# 2. Detectar herramientas abandonadas: si TODAS las distros tienen la misma
#    versión desde hace años y ninguna marca "outdated", el upstream está muerto
curl -s https://repology.org/api/v1/project/exuberant-ctags | jq -r '.[].version' | sort -u

# 3. Comprobar si algo está empaquetado antes de depender de ello
curl -s https://repology.org/api/v1/project/include-what-you-use | jq 'length'
```

## Issues conocidos por la comunidad

| Problema | Detalle |
|---|---|
| Los nombres de proyecto son normalizados y no siempre obvios | `include-what-you-use` vs `iwyu`; buscar primero en la web |
| Rate limit: ~1 petición por segundo | la documentación pide explícitamente no abusar; bloqueo por IP si se ignora |
| `status` es heurístico | un "outdated" puede ser una decisión deliberada de la distro (versión LTS estable) |
| Fusiona proyectos homónimos distintos | herramientas con nombres genéricos pueden mezclarse |
| Los datos tienen retraso de horas o días | no sirve para saber si algo se publicó hace una hora |
| No distingue variantes de empaquetado | `-git`, `-bin`, `-dev` pueden aparecer separados o fusionados según el caso |
| La API v1 no está garantizada estable | aunque en la práctica lleva años sin romperse |

## Tips y buenas prácticas

1. **Úsala para fijar el suelo de compatibilidad**: la pregunta correcta no es "¿cuál es la última versión?" sino "¿qué versión tiene la LTS más vieja que quiero soportar?".
2. Un `User-Agent` identificable es de buena educación y evita bloqueos: `curl -A 'mi-script/1.0 (contacto@ejemplo.com)'`.
3. Cachea al menos 24 h. Los datos no cambian más rápido que eso.
4. Antes de adoptar una herramienta nueva, mira su distribución en Repology: si solo está en AUR y nixpkgs, tus usuarios tendrán que compilarla.
5. Combínala con la API de GitHub (fecha del último commit/release) para distinguir "estable y maduro" de "abandonado".
6. Para comparar muchas herramientas, haz una sola pasada secuencial con `sleep 1` y guarda todo en un JSON local; no paralelices.
7. El endpoint `/projects/?outdated=1&maintainer=` es la mejor forma de auditar el estado de mantenimiento de un conjunto de paquetes propios.
