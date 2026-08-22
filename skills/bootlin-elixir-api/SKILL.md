---
name: bootlin-elixir-api
description: Consulta programática del cross-referencer Elixir de Bootlin para localizar definiciones y referencias de identificadores en cualquier versión del kernel Linux (y otros proyectos como U-Boot, Busybox, Zephyr).
---

# Bootlin Elixir — API REST

Elixir es un cross-referencer que indexa **cada versión etiquetada** de varios proyectos C
grandes. Su valor único: responder *"¿en qué versión cambió este símbolo?"* sin clonar el
repo entero.

- Servicio: `https://elixir.bootlin.com`
- Repo: `https://github.com/bootlin/elixir` (AGPLv3)
- Proyectos indexados: linux, u-boot, busybox, barebox, coreboot, musl, glibc, zephyr, uclibc, dpdk, qemu, toybox, grub, llvm, mesa, ofono, op-tee, xen…

## Endpoints

```
GET /api/ident/{project}/{ident}?version={version}&family={C|K|D|B}
GET /api/ident/{project}/{version}/{ident}
```

`family`: `C` = símbolos C · `K` = Kconfig · `D` = defconfig · `B` = DT bindings.

Respuesta:

```json
{
  "definitions": [
    { "path": "commands/loadb.c", "line": 71, "type": "variable" }
  ],
  "references": [
    { "path": "arch/arm/boards/cm-fx6/board.c", "line": "64,64,71,72,75", "type": null }
  ]
}
```

## Ejemplos

```bash
# dónde se define y desde dónde se usa un símbolo en una versión concreta
curl -s 'https://elixir.bootlin.com/api/ident/linux/cfg80211_ops?version=v6.12&family=C' | jq .

# número de referencias (indicador de cuán invasivo es cambiar algo)
curl -s 'https://elixir.bootlin.com/api/ident/linux/usb_submit_urb?version=v6.12&family=C' \
  | jq '.references | length'

# opción de Kconfig
curl -s 'https://elixir.bootlin.com/api/ident/linux/CFG80211?version=v6.12&family=K' | jq .
```

### Bisección de una API por versiones (el caso de uso estrella)

```bash
sym=set_monitor_channel
for v in v6.6 v6.8 v6.10 v6.11 v6.12 v6.13 v6.14; do
  n=$(curl -s "https://elixir.bootlin.com/api/ident/linux/$sym?version=$v&family=C" \
      | jq '.definitions | length')
  echo "$v: $n definiciones"
done
```

Combinado con la URL de fuente para leer el contexto exacto:

```
https://elixir.bootlin.com/linux/v6.12/source/include/net/cfg80211.h#L4500
https://elixir.bootlin.com/linux/v6.12/ident/set_monitor_channel
https://elixir.bootlin.com/linux/latest/A/ident/nl80211_commands   # A = todas las versiones
```

La vista `/A/ident/<símbolo>` muestra **en qué versiones existe** el identificador: es la
forma más rápida de fechar una API.

## Issues conocidos por la comunidad

| Problema | Detalle |
|---|---|
| La API no está versionada ni tiene contrato formal | la documentación vive en el README del repo; el formato puede cambiar |
| Sin autenticación pero con rate limiting implícito | scripts agresivos reciben 429 o bloqueo temporal por IP |
| El campo `line` de `references` es un string con comas | `"64,64,71"` — hay que parsearlo, no es un array |
| Símbolos definidos por macro no aparecen | lo que genera el preprocesador no está indexado |
| Solo indexa tags publicados | no hay `-rc` recientes ni ramas de mantenimiento de distros |
| Nombres de versión estrictos | `v6.12` sí, `6.12` no; `latest` funciona en la web pero no siempre en la API |
| No cubre parches de distros | el código de Debian/Ubuntu con backports **no** está aquí (para eso, la API de sources.debian.org) |

## Tips y buenas prácticas

1. **Cachea localmente** las respuestas: son inmutables por versión, así que un cache en disco elimina el 100% de las peticiones repetidas y el riesgo de rate limit.
2. Añade siempre `sleep 0.3` entre peticiones en bucles: es un servicio comunitario gratuito.
3. Para determinar cuándo cambió una firma, combina Elixir (localizar el fichero y la línea) con `lore.kernel.org` (encontrar el commit y la discusión).
4. `family=K` es la forma más rápida de saber si una opción de Kconfig existe en una versión dada.
5. El contador de `references` es un buen proxy de "coste de cambiar esto": >500 referencias significa que ninguna distro aceptará el cambio.
6. Si vas a hacer cientos de consultas, **levanta tu propia instancia** (el repo trae instrucciones con lighttpd/apache + mod_wsgi) en vez de martillear el servicio público.
7. Para proyectos que no están indexados, la misma herramienta se autoaloja: es utilizable como cross-referencer propio de cualquier árbol C.
