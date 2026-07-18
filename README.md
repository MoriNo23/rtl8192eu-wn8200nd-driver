# rtl8192eu-linux — TL-WN8200ND Driver (optimization-wn8200nd)

> ⚠️ **ADVERTENCIA — CÓDIGO DE NIVEL KERNEL (RING 0)**
> Este paquete contiene un módulo del kernel de Linux. Errores en la compilación, instalación o ejecución pueden causar inestabilidad del sistema, kernel panics, pérdida de datos o caídas de red. Utilícelo bajo su propia responsabilidad.

Driver optimizado para el adaptador WiFi **TP-Link TL-WN8200ND(UN) V3.0** basado en el chipset **Realtek RTL8192EU** (USB 2.0, 802.11n 2T2R). Repo fork de `rtl8192eu-linux` rama `5.11.2.3`.

## Chipsets y revisiones HW soportadas

| Revisión | Chipset | USB ID | Estado |
|----------|---------|--------|--------|
| TL-WN8200ND(UN) V2 | RTL8192EU | 2357:0126 | Soportado |
| **TL-WN8200ND(UN) V3** | **RTL8192EU** | **2357:0126** | **Soportado (este fork)** |

## Funcionalidades

| Funcionalidad | Estado |
|---------------|--------|
| STA (cliente WiFi) | ✅ Funcional |
| WPA2/WPA3 | ✅ Funcional |
| 2.4 GHz HT20/HT40 | ✅ Funcional |
| 2×2 MIMO | ✅ Forzado (rtw_trx_path_bmp=0x33) |
| AP / Monitor / Packet injection | ❌ Deshabilitado en este fork |

---

## 🔑 Flujo de trabajo (LEER PRIMERO — no confundir)

### CI = solo TEST de compilación
`.github/workflows/build.yml` compila en Ubuntu latest y sube `8192eu.ko.gz` a GitHub Release
para confirmar que el código compila limpio. **El `.ko` del release es para kernel azure de Ubuntu,
NO es drop-in para el host Debian** — no lo uses para instalar. Corré el CI cuando hagas cambios
de código para verificar que no hay *failed*.

### Shell = instalación real en el host (wifi_manager.sh)
Único script: `wifi_manager.sh` (TUI interactivo). Soluciona la confusión de DKMS: **SIEMPRE
borra el source viejo de `/usr/src/rtl8192eu-1.0/` y copia tu build reciente del repo ANTES de
compilar**. Así el DKMS nunca usa una copia olvidada; cuando el kernel cambie, el auto-rebuild
usa tus features nuevas.

**Flujo al tocar código:**
1. Editás código en `driver/` (NO hace falta compilar a mano — el script compila solo)
2. `sudo ./wifi_manager.sh` → elegís `2) Actualizar` (borra lo viejo + compila tu build reciente + reinstala)
3. Pusheás → CI confirma verde

> El modo Instalar/Actualizar compila automáticamente `driver/8192eu.ko` (make clean + make all).
> No compilés manualmente antes.

---

## Instalación / Gestión (wifi_manager.sh)

### Requisitos
```bash
sudo apt update
sudo apt install -y linux-headers-$(uname -r) build-essential bc dkms
```

### Usar el TUI
```bash
cd /home/fullmetal/InstalarDriver/rtl8192eu-linux
sudo ./wifi_manager.sh
```
Menú:
```
1) Instalar     (primera vez / forzar desde cero)
2) Actualizar   (borra lo viejo + reinstala tu build reciente)  ← usá esto al editar código
3) Desinstalar  (limpia TODO: módulo, /lib/modules, /usr/src, /var/lib/dkms)
4) Salir
```

El modo Instalar/Actualizar hace: descarga módulo → borra `/usr/src/rtl8192eu-1.0` y
`/var/lib/dkms/rtl8192eu` → **compila `driver/8192eu.ko` (automático)** → copia tu repo a `/usr/src`
(source fresco) → `dkms add` + `dkms install` → `depmod -a` → `modprobe 8192eu`.

> No hace falta correr `make` a mano: el script compila solo. Solo editá el código y elegí
> `2) Actualizar`.

**Auto-rebuild en update de kernel:** DKMS recompila solo cuando hay nuevo kernel, usando el
source que copiaste en `/usr/src` (que ya tiene tus features). No recompila en cada boot.

### Verificar
```bash
lsmod | grep 8192eu
cat /sys/module/8192eu/parameters/rtw_enusbss   # debe mostrar: 0
```

---

## Parámetros hardcodeados (source)

| Flag | Valor | Razón |
|------|-------|-------|
| `rtw_en_napi` | 0 | NAPI off (estabilidad USB) |
| `rtw_usb_rxagg_mode` | 0 | agregación USB off (baja latencia) |
| `rtw_dynamic_agg_enable` | 0 | agregación dinámica off |
| `rtw_enusbss` | 0 | USB autosuspend off |
| `MAX_CONTINUAL_IO_ERR` | 80 | tolerancia errores USB (era 10→30→80) |
| `CONFIG_IPS_MODE` / `CONFIG_LPS_MODE` | 0 | sin ahorro energía |
| `-O3` | on | optimización agresiva para gaming |
| `rtw_trx_path_bmp` | 0x33 | 2×2 MIMO forzado |
| `rtw_antdiv_cfg` | 1 | antenna diversity forzada |
| `rtw_TxBBSwing_2G` | 255 | potencia máxima 2.4GHz |

### Parámetros runtime (modprobe)
| Parámetro | Default | Descripción |
|-----------|---------|-------------|
| `rtw_enusbss` | 0 | USB autosuspend |
| `rtw_en_napi` | 0 | NAPI |
| `rtw_usb_rxagg_mode` | 0 | Agregación USB RX |
| `rtw_dynamic_agg_enable` | 0 | Agregación dinámica |
| `rtw_trx_path_bmp` | 0x33 | Máscara 2×2 MIMO |
| `rtw_antdiv_cfg` | 1 | Diversidad de antena |

---

## Parches anti-freeze (channel switch del router)

- **#1 Kill-switch** (`driver/os_dep/linux/usb_ops_linux.c`, `usb_write_port_complete`):
  TX URB con `-EPIPE`/`-EPROTO` (silencio de radio transitorio durante channel switch) resetean el
  contador de errores en lugar de declarar `surprise_removed`. Solo un status desconocido tras
  alcanzar `MAX_CONTINUAL_IO_ERR` (80) mata la interfaz. Evita `modprobe cycle`.
- **#3 MLME stuck** (`driver/core/rtw_mlme_ext.c`, `linked_status_chk`): además de `scan_abort`,
  re-armar `scan_to_timer` a 50ms como guardián final para limpiar `WIFI_UNDER_SURVEY` aunque
  `survey_timer_hdl` no dispare.

Detalle en brain-vault: `dev/01-rtl8192eu-freeze-fix.md`.

---

## Estructura del repositorio

```
rtl8192eu-linux/
├── driver/               # Código fuente del módulo del kernel
│   ├── core/  hal/  include/  os_dep/  platform/
│   ├── Makefile  Kconfig
│   └── 8192eu.ko         # Módulo compilado (generado por make)
├── docs/                 # BACKPORT_REPORT, DRIVER_BIBLE, BUGS.md, notes/
├── research/             # Ingeniería inversa y análisis
├── dkms.conf             # PACKAGE_NAME=rtl8192eu (matchea con wifi_manager.sh)
├── wifi_manager.sh       # ÚNICO script: TUI instalar/actualizar/desinstalar
├── AGENTS.md             # Config del driver para agentes
└── README.md
```

## Bugs conocidos
Ver [docs/BUGS.md](docs/BUGS.md). BUG-CRSH-002 = crash que requería modprobe cycle (mitigado por
parche #1).

## Créditos
- [clnhub/rtl8192eu-linux](https://github.com/clnhub/rtl8192eu-linux) (rama `5.11.2.3`, upstream)
- [Mange/rtl8192eu-linux-driver](https://github.com/Mange/rtl8192eu-linux-driver) (base original)
- Realtek Semiconductor Corp. (GPLv2) — TP-Link Technologies (hardware)

**No afiliación:** proyecto no afiliado a TP-Link ni Realtek.
**Licencia:** GPLv2 — ver [LICENSE](LICENSE).

https://github.com/MoriNo23/TL-WN8200ND-driver
