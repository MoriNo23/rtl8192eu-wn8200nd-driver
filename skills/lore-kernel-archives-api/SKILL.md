---
name: lore-kernel-archives-api
description: Búsqueda programática en los archivos de listas de correo del kernel (lore.kernel.org / public-inbox) para encontrar el commit, el parche y la discusión detrás de cualquier cambio de API.
---

# lore.kernel.org (public-inbox) — API de búsqueda

`lore.kernel.org` archiva prácticamente todas las listas de correo del kernel con
**public-inbox**, que expone búsqueda con sintaxis Xapian y salidas en mbox, Atom y JSON.
Es la fuente primaria para responder *"¿por qué cambió esta API y quién lo discutió?"*.

- Servicio: `https://lore.kernel.org`
- Software: `https://public-inbox.org` (repo: `https://public-inbox.org/public-inbox.git`)
- Todos los archivos son clonables como repos Git: el archivo es el dato

## Formas de consulta

```bash
# búsqueda HTML
https://lore.kernel.org/all/?q=set_monitor_channel

# resultados como Atom (parseable)
curl -s 'https://lore.kernel.org/all/?q=cfg80211+set_monitor_channel&x=A' | xmllint --format -

# resultados como mbox comprimido (todos los mensajes que casan)
curl -s 'https://lore.kernel.org/all/?q=f:johannes+s:nl80211&x=m' | gunzip > hilo.mbox

# un hilo completo en mbox a partir del Message-ID
curl -s 'https://lore.kernel.org/all/20240101120000.12345-1-dev@example.com/t.mbox.gz' \
  | gunzip > hilo.mbox

# el parche crudo de un mensaje
curl -s 'https://lore.kernel.org/all/<message-id>/raw' > parche.patch
```

Sufijos de URL útiles sobre un Message-ID:

| Sufijo | Devuelve |
|---|---|
| `/raw` | el mensaje tal cual (aplicable con `git am`) |
| `/t/` | el hilo en HTML |
| `/t.mbox.gz` | el hilo completo en mbox |
| `/T/#u` | vista plana del hilo |
| `/#related` | mensajes relacionados |

## Sintaxis de búsqueda (Xapian)

| Prefijo | Busca en | Ejemplo |
|---|---|---|
| `s:` | asunto | `s:"nl80211"` |
| `f:` | remitente | `f:torvalds` |
| `t:` | destinatario | `t:linux-wireless` |
| `b:` | cuerpo | `b:set_monitor_channel` |
| `nq:` | cuerpo sin citas | `nq:regression` |
| `dfn:` | nombre de fichero en el diff | `dfn:net/wireless/nl80211.c` |
| `dfhh:` | cabecera de hunk del diff | `dfhh:cfg80211_ops` |
| `dfb:` | líneas añadidas/quitadas | `dfb:struct net_device` |
| `d:` | rango de fechas | `d:20240101..20241231` |
| `rt:` | fecha de recepción | `rt:20240101..` |

Combinaciones que valen oro:

```bash
# quién tocó una función concreta en un fichero concreto
curl -s 'https://lore.kernel.org/all/?q=dfn:net/wireless/nl80211.c+AND+dfhh:set_monitor_channel&x=A'

# regresiones reportadas sobre un subsistema
curl -s 'https://lore.kernel.org/linux-wireless/?q=nq:regression+AND+b:rtl8&x=A'

# parches de un autor en un rango de fechas
curl -s 'https://lore.kernel.org/all/?q=f:johannes@sipsolutions.net+d:20240101..20240630&x=m'
```

## Clonar el archivo (uso masivo)

```bash
# cada lista es un repo git (a veces particionado en /0, /1, ...)
git clone --mirror https://lore.kernel.org/linux-wireless/0 linux-wireless-0
# consulta local sin tocar el servidor
git -C linux-wireless-0 log --oneline | head
```

`public-inbox` también permite montar tu propio índice Xapian sobre esos repos y consultar
offline con `public-inbox-index` + `lei` (`lei q -f mboxrd 's:nl80211'`).

## Issues conocidos por la comunidad

| Problema | Detalle |
|---|---|
| No hay JSON nativo | las salidas son Atom (`x=A`) y mbox (`x=m`); hay que parsear XML o mbox |
| Rate limiting agresivo ante scraping | descargas masivas deben hacerse clonando el repo, no con curl en bucle |
| `/all/` puede tardar en consultas amplias | acotar por lista concreta (`/linux-wireless/`) es mucho más rápido |
| Message-IDs con caracteres especiales | hay que url-encodear `<`, `>`, `+` y `/` |
| Cobertura desigual antes de ~2017 | listas viejas importadas parcialmente desde otros archivos |
| El mbox devuelve mbox**rd**, no mbox clásico | `git am` lo acepta; otros parsers no |
| Búsquedas con muchos resultados se paginan silenciosamente | usar `&o=200` para el offset y recorrer |

## Tips y buenas prácticas

1. **`dfn:` + `dfhh:` es la consulta más potente que existe** para arqueología de APIs: encuentra el parche exacto que tocó una función en un fichero, aunque el mensaje no la mencione en el asunto.
2. Flujo canónico para entender un cambio de API: Elixir localiza fichero+línea → `git log -L` sobre el árbol da el commit → lore con el asunto del commit da **la discusión y los motivos**.
3. Los mensajes de `/raw` se aplican directamente con `git am`: es la forma de probar un parche antes de que llegue a un release.
4. Cuando busques una regresión, `nq:` (sin citas) evita miles de falsos positivos de gente citando el mensaje original.
5. Para trabajo intensivo usa **`lei`** (parte de public-inbox): sincroniza consultas guardadas a un Maildir local y funciona offline.
6. Los archivos son **repos Git**: `git clone` una vez y consulta localmente cuantas veces quieras. Es la práctica recomendada por los propios mantenedores.
7. Guarda el Message-ID en los comentarios del código cuando implementes algo derivado de una discusión: `/* ver https://lore.kernel.org/all/<msgid>/ */` es la mejor documentación posible.
