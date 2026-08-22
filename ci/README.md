# ci/ — workflow de GitHub Actions

**ACTIVA desde 2026-08-22**: la versión vigente es `.github/workflows/build.yml`.
Históricamente vivía aquí porque el token del PR #2 no tenía el permiso `workflows`
de GitHub y el push a esa ruta era rechazado por el servidor; se activó con un
`cp` a `.github/workflows/` desde una máquina local. `ci/workflows/build.yml` se
conserva como copia de staging — si editas uno, sincroniza el otro.

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
