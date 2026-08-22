# ci/ — workflow de GitHub Actions

`ci/workflows/build.yml` es la versión nueva del CI. **Todavía no está activa**: vive aquí
en vez de en `.github/workflows/` porque el token con el que se abrió el PR no tiene el
permiso `workflows` de GitHub y el push a esa ruta es rechazado por el servidor.

## Activarlo (una sola vez, desde tu máquina)

```bash
git checkout main && git pull
cp ci/workflows/build.yml .github/workflows/build.yml
git add .github/workflows/build.yml
git commit -m "ci: activar build-check en pull_request + chequeos de regresión"
git push
```

A partir de ahí el CI corre también en los PR, no solo tras el merge.

## Qué hace

| Job | Contenido |
|---|---|
| `sanity` | No compila, falla rápido: el Makefile parsea en sus dos ramas · no hay ficheros duplicados ignorando mayúsculas/minúsculas · no hay `.orig`/`.rej`/`.mine`/`.backup` versionados · la versión está sincronizada entre `dkms.conf`, `install_manual.sh` y `AGENTS.md` |
| `build` | Detecta el `KVER` realmente instalado en el runner y compila pasando `KVER`/`KSRC` explícitos. Verifica: el `.ko` existe, alias USB `2357:0126`, símbolos de AP mode, el fix A1 (`rtw_usb_ep_reset_work_deinit` compilado **y** llamado en disconnect), que los objetos de features apagadas **no** se compilen, y que `make clean` deje el árbol limpio |
| `bt-toggle` | `continue-on-error`. Compila con `CONFIG_BT_COEXIST = y` para garantizar que el interruptor de Bluetooth sigue siendo usable en el futuro |

Triggers: `push` a `main`, **`pull_request` a `main`**, y `workflow_dispatch`.

## Por qué cambió respecto al anterior

El workflow viejo usaba una matriz de paquetes de headers (`linux-headers-6.8-generic`,
`6.11`, `6.14`) que ya no existen tal cual en el runner de Ubuntu: los jobs morían en el
`apt-get install` y el driver nunca llegaba a compilarse. Ahora se instala
`linux-headers-generic` (y HWE como opcional) y el `KVER` se detecta recorriendo
`/lib/modules/*/build`.

Además solo corría en `push` a `main`, es decir **después** del merge. Con el trigger de
`pull_request` la validación pasa a ocurrir antes.
