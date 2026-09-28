# USB-LINK-HANG — el adaptador desaparece sin que el driver pueda hacer nada

**Estado**: documentado 2026-09-28. **No hay arreglo de software para esto.**

Este documento existe para una cosa concreta: que cuando `wn8200nd` deje de
funcionar, puedas decir en menos de dos minutos si el problema es **el enlace
USB** (hardware/cable/puerto/enchufe) o **el driver** (código). Los dos se
parecen desde fuera —la interfaz desaparece— pero se distinguen sin logs del
driver, que ya no tenemos (ver `AGENTS.md`, sección de silencio).

## Resumen

El core de USB deshabilita el puerto y mata el dispositivo **antes del probe**.
Desde ese punto, el driver no se ha ejecutado nunca: no hay código de
`driver/` que pueda ser alcanzable en ese camino. Por eso ningún parche,
ningún parámetro y ningún ajuste de este repositorio puede prevenirlo.

## Cómo reconocer un fallo de enlace USB

Tres señales, todas en el log del núcleo. **Basta una** para clasificarlo:

```bash
sudo journalctl -k -b | grep -Ei "usb .*disconnect|disabled by hub|error -[0-9]+|new (full|high)-speed USB device"
```

| Señal | Significado |
|---|---|
| `disabled by hub (EMI?)` | El hub decidió apagar el puerto. Firmware del hub o problema eléctrico. |
| `usb 1-2: new device ... error -32` (`EPIPE`) | Fallo de pipe en la enumeración. Típico de puerto/enchufe. |
| `error -71` / `-110` durante la lectura del descriptor | El dispositivo no responde a la enumeración. Cable o dongle. |

Lo que **no** verás: ni un `RTW:` (el driver no corrió), ni un `Oops`, ni un
`general protection fault`, ni un `call trace` que mencione `8192eu`.

### La comprobación de 5 segundos

```bash
# ¿Está el dongle enumerado ahora mismo?
lsusb | grep -i 2357        # TP-Link, debe aparecer 2357:0126
```

Si **no** aparece: es el enlace USB. Reinicia el dongle (ver más abajo) y
comprueba otra vez. Si aparece pero `ip addr` no muestra IP en `wn8200nd`, el
enlace está bien y el problema es del driver → ver más abajo.

## Procedimiento de recuperación

El «flapeo» es un power cycle del VBUS. Re-asentar el conector USB lo
resuelve el 100% de las veces, porque fuerza ese ciclo:

1. **Desconecta el adaptador del puerto.**
2. **Espera 10 segundos** (deja que el VBUS se descargue del todo; menos no basta).
3. **Vuelve a conectarlo directamente en la máquina**, sin hub intermedio.
4. Comprueba:
   ```bash
   lsusb | grep -i 2357
   ip -4 addr show wn8200nd     # debe tener IP
   ```

Si vuelve a aparecer en `lsusb` pero sin IP, el enlace se recuperó y lo que
queda es el driver. Recarga:

```bash
sudo ./install_manual.sh       # incluye la recarga y reinicia NetworkManager
```

Si no lo recuperas en el paso 3, es hardware: puerto, cable, o el conector del
propio dongle. Pasa al experimento de puerto directo.

## Experimento: puerto de root directo

Objetivo: demostrar que el problema es el hub/enchufe y no el dongle ni el
driver.

1. Mueve el dongle a un **puerto USB trasero** (los traseros suelen ir
   conectados al controlador principal; los delanteros, a un hub interno).
2. Si tienes un cable largo o un hub externo en medio, quítalos.
3. Desconecta y reconecta (power cycle de 10 s, paso 2 de arriba).
4. Verifica que ahora cuelga directo:
   ```bash
   lsusb -t | grep -A1 "1-1\|2-1"
   ```

En `lsusb -t`, un dispositivo cuyo número de bus/puerto cuelga de `usb1` o
`usb2` (los controladores raíz) en vez de un `Driver=.../2.0/...` de un hub
intermedio, está en puerto directo.

**Cómo se lee el resultado:**

- Si tras el experimento la enumeración falla **solo** cuando va tras un hub, y
  va estable directo → problema de hub o de energización del hub. No es cosa del
  driver. Solución práctica: puerto directo, cable mejor, o un hub con
  alimentación propia.
- Si falla **también** en puerto directo → problema del dongle o del puerto de
  la placa. Con este adaptador ya se ha desoldado el conector de la antena B
  (`AGENTS.md`, sección MIMO), así que el conector USB tampoco es descartable
  por ser «el mismo dongle».
- Si aguanta estable en directo durante días → confirmado que era el hub.

## Evidencia de los tres boots (2026-09-28)

Medido sobre los tres arranques disponibles en el buffer del núcleo. Sirve
como línea base: si el patrón cambia (muchos más eventos, `error -32` en vez de
desconexiones limpias), el diagnóstico de arriba se aplica igual pero la
frecuencia ya no es la de siempre.

| Boot | Desconexiones | Nota |
|---|---|---|
| -2 | 8 | con un hueco estable de 28 h entre boot y boot |
| -1 | 3 | una precedida de `disabled by hub (EMI?)` a los 5 min de arrancar, **sin intervención física** |
| actual | 5 | con 4× `error -32` en la lectura del descriptor |

Ninguno de esos eventos venía acompañado de líneas `RTW:` anteriores a la
desconexión: el dispositivo muere antes o durante la enumeración, no después de
estar enlazado.

## Por qué esto importa más de lo que parece

El dongle `wn8200nd` es la **WAN del AP `escama`**. En `escama.env`:

```
AP_IFACE=stonepi     # WiFi interno Intel, parentdev 0000:02:00.0
WAN_IFACE=wn8200nd   # este dongle
```

Es decir: un flapeo de este dongle **corta internet a todos los clientes del
AP**, no solo a esta máquina. Cuando se investigue un problema de red en casa,
esta es la primera pregunta, no la última.

## Lo que este repositorio **no** va a hacer

- No va a añadir reintentos de enumeración en el driver: el driver no se
  ejecuta en ese camino, así que no hay nada que reintentar.
- No va a añadir parches USB "por si acaso": el mecanismo de recuperación de
  `-EPIPE` que ya existe (`rtw_usb_ep_reset_work_init/deinit` en
  `driver/os_dep/linux/usb_ops_linux.c`) cubre el endpoint colgado con el
  dispositivo **ya enumerado**, que es un fallo distinto. Ver `AGENTS.md`,
  sección «URB stall recovery».

La parte de software que queda —diagnosticar que el driver no cargó cuando el
enlace sí está bien— la cubren las aserciones de CI: si el módulo no compila o
no enlaza, el CI está en rojo antes de que toque la máquina. Ese es el
diagnóstico disponible sin depuración en runtime.

## Ver también

- `AGENTS.md` → «USB Stability» y «URB stall recovery»: lo que sí está
  cubierto por software.
- `docs/RF-SENSITIVITY.md`: cómo medir la sensibilidad si el problema es de
  señal y no de enlace.
- `openspec/changes/driver-silence-and-throughput/design.md` → «Restricción
  3» y «Restricción 4», de donde sale todo esto.
