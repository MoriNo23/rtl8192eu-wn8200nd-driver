---
name: github-rest-api-code-archaeology
description: Uso de la API REST/GraphQL de GitHub para arqueología de código — buscar commits, comparar tags, leer ficheros en una revisión concreta y medir la salud de un repositorio antes de depender de él.
---

# GitHub API para arqueología de código

- Docs: `https://docs.github.com/rest`, `https://docs.github.com/graphql`
- CLI oficial: `https://github.com/cli/cli` (`gh`) — ya autentica por ti y evita gestionar tokens a mano

## Autenticación

```bash
gh auth login
gh api rate_limit | jq '.resources.core'
# o con token explícito
export GH_TOKEN=...
curl -s -H "Authorization: Bearer $GH_TOKEN" -H 'Accept: application/vnd.github+json' ...
```

Sin autenticar: 60 peticiones/hora. Autenticado: 5000/hora. La API de búsqueda tiene su
propio límite (30/min autenticado) y **tope de 1000 resultados**.

## Consultas de arqueología

```bash
# buscar commits que mencionan un símbolo
gh api -X GET search/commits -f q='repo:torvalds/linux set_monitor_channel' \
  --jq '.items[] | "\(.sha[0:12]) \(.commit.message | split("\n")[0])"'

# buscar código (requiere estar autenticado)
gh api -X GET search/code -f q='cfg80211_ops repo:torvalds/linux extension:h' \
  --jq '.items[].path'

# leer un fichero en una revisión concreta
gh api repos/torvalds/linux/contents/include/net/cfg80211.h?ref=v6.12 \
  --jq '.content' | base64 -d | head -50

# comparar dos tags: qué ficheros cambiaron
gh api repos/torvalds/linux/compare/v6.11...v6.12 --jq '.files[].filename' | grep wireless

# historial de un fichero
gh api -X GET repos/torvalds/linux/commits -f path=net/wireless/nl80211.c -f per_page=20 \
  --jq '.[] | "\(.sha[0:12]) \(.commit.author.date[0:10]) \(.commit.message|split("\n")[0])"'

# un commit completo con su diff
gh api repos/torvalds/linux/commits/<sha> --jq '.files[] | {filename, additions, deletions}'
curl -sL https://github.com/torvalds/linux/commit/<sha>.patch
```

## Medir la salud de un repositorio antes de depender de él

```bash
R=owner/repo
gh api repos/$R --jq '{
  archived, disabled, fork,
  stars: .stargazers_count,
  issues: .open_issues_count,
  pushed: .pushed_at,
  license: .license.spdx_id
}'

# actividad real del último año
gh api repos/$R/stats/commit_activity --jq '[.[].total] | add'

# tiempo desde el último release
gh api repos/$R/releases/latest --jq '{tag_name, published_at}'

# ¿los issues se responden?
gh api -X GET repos/$R/issues -f state=closed -f per_page=20 \
  --jq '[.[] | (( .closed_at|fromdate) - (.created_at|fromdate))/86400] | add/length'

# contribuidores distintos en el último año (proxy de bus factor)
gh api repos/$R/contributors --paginate --jq 'length'
```

## GraphQL: cuando REST obliga a N peticiones

```bash
gh api graphql -f query='
{
  repository(owner: "torvalds", name: "linux") {
    defaultBranchRef {
      target { ... on Commit {
        history(first: 5, path: "net/wireless/nl80211.c") {
          nodes { oid messageHeadline committedDate }
        }
      }}
    }
  }
}'
```

## Issues conocidos por la comunidad

| Problema | Detalle |
|---|---|
| Search API: tope duro de 1000 resultados | inservible para barridos exhaustivos; hay que clonar y usar `git log` |
| `search/code` exige autenticación y solo indexa la rama por defecto | no encuentra nada en ramas ni en historia |
| Rate limits distintos por endpoint | `search` 30/min, core 5000/h, GraphQL por puntos de coste |
| El índice de código está incompleto en repos enormes | `torvalds/linux` no está totalmente indexado para code search |
| `stats/*` devuelve 202 la primera vez | GitHub calcula en diferido; hay que reintentar |
| Espejos incompletos | `torvalds/linux` no tiene las ramas stable; para eso, `git.kernel.org` |
| Paginación silenciosa | sin `--paginate` obtienes solo 30 elementos y parece que no hay más |

## Tips y buenas prácticas

1. **Para cualquier análisis serio de historia, clona y usa `git`.** La API sirve para consultas puntuales y metadatos sociales (issues, releases, actividad), no para arqueología masiva.
2. `git clone --filter=blob:none` te da toda la historia de metadatos por una fracción del ancho de banda, y `git log -S'cadena'` (pickaxe) encuentra cuándo apareció o desapareció una cadena — algo que la API no sabe hacer.
3. `gh api --paginate --jq` evita escribir código: cubre el 90% de los casos desde la terminal.
4. Antes de adoptar una dependencia, mira **`pushed_at`, número de contribuidores y tiempo medio de cierre de issues**, no las estrellas. Las estrellas no predicen mantenimiento.
5. Los issues cerrados sin comentarios y el ratio issues abiertos/cerrados dicen más sobre la salud del proyecto que el README.
6. Guarda las respuestas de arqueología en el repo (un `NOTES.md` con SHAs y enlaces): reconstruir esa investigación cuesta horas y se pierde en cuanto cierras la terminal.
7. Para proyectos que también viven en listas de correo (kernel, glibc, qemu), GitHub es un espejo parcial: la discusión real está en el archivo de la lista.
