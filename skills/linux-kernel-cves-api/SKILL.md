---
name: linux-kernel-cves-api
description: Consulta programática de vulnerabilidades del kernel Linux — linuxkernelcves.com, el feed CVE oficial del kernel (kernel.org CNA) y la API de OSV. Úsala para saber si un cambio de código o una versión concreta arrastra CVEs conocidas.
---

# CVEs del kernel Linux — fuentes consultables

Desde 2024 el proyecto Linux es **CNA** (CVE Numbering Authority) propia y asigna CVEs a
sus propios commits, lo que multiplicó el volumen y cambió las fuentes de referencia.

| Fuente | Qué da | Formato |
|---|---|---|
| `linuxkernelcves.com` | mapeo CVE → commit que introduce y commit que arregla, por rama estable | JSON |
| `git.kernel.org/.../vulns.git` | repo oficial de la CNA del kernel | Git + JSON |
| OSV (`api.osv.dev`) | agregador con esquema estándar | JSON REST |
| NVD (`services.nvd.nist.gov/rest/json/cves/2.0`) | metadatos oficiales, CVSS | JSON REST |

## linuxkernelcves.com

```bash
# volcado completo (varios MB)
curl -s https://www.linuxkernelcves.com/data/stream.json -o kernel-cves.json

# ¿en qué versión se arregló una CVE?
jq '."CVE-2024-XXXXX"' kernel-cves.json

# CVEs que afectan a una rama y aún no están arregladas en ella
jq -r 'to_entries[] | select(.value.fixes == null) | .key' kernel-cves.json | head

# CVEs cuyo commit de arreglo toca un subsistema concreto
jq -r 'to_entries[] | select(.value.affected_versions != null) 
       | "\(.key) \(.value.affected_versions) \(.value.cmt_msg)"' kernel-cves.json \
  | grep -i wireless
```

Estructura típica de una entrada:

```json
"CVE-2024-XXXXX": {
  "cmt_msg": "wifi: subsystem: fix use-after-free in foo()",
  "breaks": "a1b2c3d...",          // commit que introdujo el bug
  "fixes":  "e4f5g6h...",          // commit que lo arregla
  "affected_versions": "v5.10 to v6.6.12",
  "backport_helper": "...",
  "cvss3": { "score": 7.8, "severity": "High" }
}
```

## Repo oficial de la CNA del kernel

```bash
git clone https://git.kernel.org/pub/scm/linux/security/vulns.git
cd vulns
ls cve/published/2025/          # un JSON + .sha1 + .mbox por CVE
jq '.containers.cna.affected' cve/published/2025/CVE-2025-XXXXX.json
```

Este repo es la **fuente de verdad**: contiene qué commit introdujo el fallo, cuál lo
arregla y en qué versiones estables entró el arreglo.

## OSV API (esquema estándar, cómodo para automatizar)

```bash
# por versión
curl -s -X POST https://api.osv.dev/v1/query \
  -d '{"package":{"name":"linux","ecosystem":"Linux"},"version":"6.12.30"}' | jq '.vulns | length'

# por commit
curl -s -X POST https://api.osv.dev/v1/query \
  -d '{"commit":"a1b2c3d4e5f6..."}' | jq '.vulns[].id'

# detalle de una CVE
curl -s https://api.osv.dev/v1/vulns/CVE-2024-XXXXX | jq '.affected[0].ranges'
```

## NVD (metadatos y CVSS oficiales)

```bash
curl -s 'https://services.nvd.nist.gov/rest/json/cves/2.0?cveId=CVE-2024-XXXXX' \
  | jq '.vulnerabilities[0].cve.metrics'
# con API key (recomendado, sube el rate limit):
curl -s -H "apiKey: $NVD_API_KEY" '...'
```

## Issues conocidos por la comunidad

| Problema | Detalle |
|---|---|
| Volumen desmesurado desde que el kernel es CNA propia | miles de CVEs al año, muchas de severidad trivial o teórica |
| Puntuaciones CVSS poco fiables para el kernel | asignadas de forma conservadora; una "High" puede requerir root local |
| Muchas CVEs no tienen "commit que introduce" identificado | el campo `breaks` puede ser null |
| Los datos de NVD llegan con retraso de semanas | el repo `vulns.git` es siempre más rápido |
| `stream.json` es un fichero grande sin paginación | hay que descargarlo entero y filtrar en local |
| Un driver out-of-tree no aparece en ninguna base | solo se cubre lo que está en el árbol oficial |
| Las versiones de distro no mapean directamente | Debian/RHEL retroportan arreglos sin cambiar el número de versión |

## Tips y buenas prácticas

1. **No trates el conteo de CVEs como métrica de seguridad.** Desde el cambio a CNA propia, el número refleja actividad de mantenimiento, no riesgo real.
2. Filtra por **subsistema que realmente usas**: la inmensa mayoría de CVEs del kernel afectan a drivers y filesystems que no tienes cargados.
3. Para saber si tu distro está afectada, consulta el tracker de la distro (`security-tracker.debian.org/tracker/CVE-...`), no NVD: la distro sabe si retroportó el arreglo.
4. El campo `breaks` de linuxkernelcves es oro para arqueología: te dice desde qué versión existe el fallo, y por tanto si tu código heredado lo arrastra.
5. Automatiza con OSV si necesitas un esquema estable; usa `vulns.git` si necesitas exactitud y frescura.
6. Cachea `stream.json` diariamente; no lo descargues en cada consulta.
7. Si mantienes código derivado del kernel, suscríbete a `linux-cve-announce` en lore y filtra por los ficheros que copiaste. Es la única forma de enterarte de arreglos que te aplican.
