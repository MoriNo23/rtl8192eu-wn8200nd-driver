# skills/

Colección de skills independientes, una por carpeta, cada una con su `SKILL.md`.
Son **genéricas**: describen la herramienta o la API, no un proyecto concreto.

Cada `SKILL.md` contiene:
- frontmatter con `name` y `description`
- repo oficial, licencia e instalación
- el **código/uso importante** (snippets reales, endpoints, formatos de salida)
- **issues conocidos por la comunidad** en tabla
- **tips y buenas prácticas**

---

## Herramientas de transformación y poda de código

| Skill | Herramienta | Para qué |
|---|---|---|
| `coccinelle-spatch/` | Coccinelle (`spatch`) | parches semánticos SmPL, refactor masivo de C |
| `unifdef-coan/` | unifdef, coan | eliminar ramas muertas del preprocesador |
| `iwyu-deheader/` | include-what-you-use, deheader | poda de `#include` |
| `git-filter-repo/` | git-filter-repo | reescritura de historia, extracción de subárboles |

## Análisis estático y calidad

| Skill | Herramienta | Para qué |
|---|---|---|
| `sparse-typechecker/` | Sparse | address spaces, endianness, balance de locks |
| `smatch-static-analysis/` | Smatch | análisis cross-function, locks, fugas, rutas de error |
| `clang-tooling-c/` | clang-format, clang-tidy, clangd | estilo, fix-its, navegación semántica |
| `checkpatch-kernel-style/` | `scripts/checkpatch.pl` y scripts del árbol Linux | gate de estilo, `bloat-o-meter`, `checkstack` |

## Comprensión y navegación de código

| Skill | Herramienta | Para qué |
|---|---|---|
| `bear-compilation-database/` | Bear, compiledb | `compile_commands.json`, prerequisito de todo lo Clang |
| `code-navigation-cscope-global/` | cscope, GNU GLOBAL, universal-ctags | "quién llama a esto" en árboles enormes |
| `cflow-callgraph/` | GNU cflow, `-fcallgraph-info`, egypt | grafos de llamadas, código inalcanzable |

## APIs de documentación consultables programáticamente

| Skill | Servicio | Para qué |
|---|---|---|
| `bootlin-elixir-api/` | elixir.bootlin.com | definiciones y referencias de símbolos por versión |
| `lore-kernel-archives-api/` | lore.kernel.org (public-inbox) | el parche y la discusión detrás de un cambio de API |
| `kernel-org-releases-api/` | kernel.org, git.kernel.org | versiones vivas, LTS, EOL, tags, diffs |
| `debian-sources-api/` | sources.debian.org (Debsources) | código real de una distro, incluidos parches propios |
| `repology-api/` | repology.org | versión de un paquete en 300+ distros |
| `linux-kernel-cves-api/` | linuxkernelcves, vulns.git, OSV, NVD | CVEs, commit que introduce y commit que arregla |
| `github-rest-api-code-archaeology/` | api.github.com, `gh` | búsqueda de commits, comparación de tags, salud de un repo |
| `kernel-doc-and-api-references/` | docs.kernel.org, `scripts/kernel-doc` | formato kernel-doc y verificación de firmas por versión |

---

## Orden de uso sugerido en un refactor de C

1. **Entender** → `bear-compilation-database`, `code-navigation-cscope-global`, `cflow-callgraph`
2. **Medir el estado inicial** → `sparse-typechecker`, `smatch-static-analysis`, `checkpatch-kernel-style`
3. **Podar** → `unifdef-coan`, `iwyu-deheader`
4. **Transformar** → `coccinelle-spatch`, `clang-tooling-c`
5. **Verificar contra APIs externas** → `bootlin-elixir-api`, `lore-kernel-archives-api`, `debian-sources-api`, `kernel-doc-and-api-references`
6. **Limpiar el repositorio** → `git-filter-repo`
