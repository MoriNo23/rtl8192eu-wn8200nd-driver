---
name: smatch-static-analysis
description: Análisis estático de C con Smatch, incluyendo análisis cross-function. Úsala para detectar locks sin liberar, fugas en rutas de error, desreferencias de NULL y desbordamientos antes/después de un refactor.
---

# Smatch

Analizador estático para C construido sobre el parser de Sparse. Su diferencial es el
**análisis cross-function con base de datos**: recorre todo el árbol, guarda qué devuelve y
qué hace cada función, y en una segunda pasada razona sobre las llamadas.

- Repo: `https://github.com/error27/smatch`
- Autor: Dan Carpenter
- Licencia: GPLv2
- Capacidad clave desde 2010: cross function analysis; su check de locking es de los más completos que existen para C

## Instalación

```bash
sudo apt install gcc make sqlite3 libsqlite3-dev libssl-dev libxml2-dev llvm-dev
git clone https://github.com/error27/smatch
cd smatch && make -j"$(nproc)"
# no hace falta 'make install': se usa desde el directorio del repo
```

## Uso

### Sobre un proyecto con Makefile

```bash
# análisis de una sola pasada
make CHECK="/ruta/a/smatch/smatch --full-path" CC=/ruta/a/smatch/cgcc

# proyecto pequeño, fichero a fichero
/ruta/a/smatch/smatch fichero.c
```

### Análisis cross-function (2 pasadas + base de datos)

Este es el modo que aporta valor real:

```bash
cd /ruta/al/proyecto
/ruta/a/smatch/smatch_scripts/build_kernel_data.sh     # variante para el kernel
# genérico:
/ruta/a/smatch/smatch_scripts/test_kernel.sh
# la BD queda en smatch_db.sqlite
sqlite3 smatch_db.sqlite "select * from return_states limit 20;"
```

### Scripts útiles del repo

```
smatch_scripts/
├── test_kernel.sh          # corrida completa
├── kchecker                # analizar un solo fichero/directorio
├── build_kernel_data.sh    # construye la BD cross-function
├── whitespace_only.sh
└── new_bugs.sh             # diff de warnings entre dos corridas ← el más útil en CI
```

## Checks que más valen la pena

| Check | Detecta |
|---|---|
| `check_locking` | lock adquirido y no liberado en una ruta de error |
| `check_leaks` / `check_frees` | memoria perdida o doble free |
| `check_deref` / `check_null_deref` | desreferencia de puntero que puede ser NULL |
| `check_err_ptr_deref` | uso de `ERR_PTR` sin comprobar |
| `check_overflow` | escritura fuera de buffer |
| `check_unwind` | rutas de limpieza incompletas |
| `check_uninitialized` | variable usada sin inicializar en algún camino |
| `check_signed` / `check_type` | comparaciones con signo mal planteadas |

## Interpretar la salida

```
core.c:412 do_thing() warn: inconsistent returns 'mutex:&dev->lock'.
  Locked on  : 398
  Unlocked on: 412
```

Lee siempre **las dos líneas de contexto**: `Locked on` / `Unlocked on` te dan las rutas
concretas. Si una de ellas es una ruta de error rara, suele ser bug real.

## Issues conocidos por la comunidad

| Problema | Detalle |
|---|---|
| Tasa de falsos positivos apreciable | especialmente en `check_uninitialized` y en macros complejas; se filtran con `--no-check=<nombre>` |
| Funciones inline confunden a la BD | hay que listarlas en `smatch_data/kernel.no_inline_functions` para que use el dato de disco en vez del inline |
| Necesita compilar el proyecto | si el build falla, el análisis queda parcial y silencioso |
| La BD tarda mucho en árboles grandes | primera corrida puede ser de horas; se cachea en `smatch_db.sqlite` |
| Muy orientado a estilo kernel | idioms como `ERR_PTR`, `-EINVAL` están cableados; en userland algunos checks pierden sentido |
| No es hermético entre versiones | actualizar smatch cambia el conjunto de warnings; hay que rebasar el baseline |

## Tips y buenas prácticas

1. **Genera un baseline antes de refactorizar** y compara después con `new_bugs.sh`. El número absoluto de warnings importa poco; lo que importa son los **nuevos**.
2. Combínalo con Sparse: Smatch usa su parser, así que los errores de Sparse enmascaran checks de Smatch. Limpia Sparse primero.
3. `check_locking` es el check estrella: úsalo sobre cualquier código con concurrencia antes de dar por bueno un refactor.
4. Ejecuta el análisis **por subdirectorio** en árboles grandes para acotar tiempos y poder paralelizar.
5. Guarda `smatch_db.sqlite` como artefacto: permite consultas ad-hoc (`select` sobre `return_states`) que responden "¿qué puede devolver esta función?" mejor que leer el código.
6. Trata los warnings de rutas de error como prioritarios: son bugs que el testing normal no encuentra porque esas rutas casi nunca se ejecutan.
7. No intentes llegar a cero warnings. Fija un umbral y prohíbe subirlo.
