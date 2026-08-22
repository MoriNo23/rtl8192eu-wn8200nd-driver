---
name: sparse-typechecker
description: Verificación semántica de C con Sparse (make C=1) — address spaces, endianness, bitwise types y anotaciones de contexto. Úsala para validar código C de bajo nivel donde el compilador no tiene información suficiente.
---

# Sparse

Frontend de C ligero creado por Linus Torvalds para hacer **verificaciones que gcc no puede
hacer**: distinguir punteros de espacios de direcciones distintos, detectar mezclas de
endianness y comprobar el balance de locks mediante anotaciones.

- Repo: `git://git.kernel.org/pub/scm/devel/sparse/sparse.git`
- Espejo: `https://github.com/lucvoo/sparse` (histórico)
- Licencia: MIT
- Ejecutables que instala: `sparse`, `cgcc`, `sparse-llvm`

## Instalación

```bash
sudo apt install sparse            # Debian/Ubuntu
sudo dnf install sparse            # Fedora
git clone git://git.kernel.org/pub/scm/devel/sparse/sparse.git
cd sparse && make -j"$(nproc)" && sudo make install
sparse --version
```

## Uso

```bash
# fichero suelto
sparse -Wall fichero.c

# como wrapper del compilador (recomendado)
make CC=cgcc

# en un proyecto tipo kernel
make C=1            # analiza los ficheros que se recompilan
make C=2            # analiza todos
make C=1 CF="-D__CHECK_ENDIAN__ -Wsparse-all"
```

## Las anotaciones: el corazón de Sparse

Sparse solo es útil si **anotas el código**. Las anotaciones son atributos GCC que
desaparecen en compilación normal:

```c
/* típicamente definidas así en un header del proyecto */
#ifdef __CHECKER__
# define __user        __attribute__((noderef, address_space(__user)))
# define __kernel      __attribute__((address_space(0)))
# define __iomem       __attribute__((noderef, address_space(__iomem)))
# define __percpu      __attribute__((noderef, address_space(__percpu)))
# define __rcu         __attribute__((noderef, address_space(__rcu)))
# define __force       __attribute__((force))
# define __bitwise     __attribute__((bitwise))
# define __acquires(x) __attribute__((context(x,0,1)))
# define __releases(x) __attribute__((context(x,1,0)))
# define __must_hold(x) __attribute__((context(x,1,1)))
#else
# define __user
# define __iomem
/* ... todo a vacío ... */
#endif
```

### Espacios de direcciones

```c
int copy_from_user(void *dst, const void __user *src, unsigned long n);

void ejemplo(char __user *buf)
{
    char c = *buf;            // ← Sparse: dereference of noderef expression
    char d = *(char *)buf;    // ← Sparse: cast removes address space of expression
    char e = *(char __force *)buf;  // OK: cast explícitamente forzado
}
```

### Tipos bitwise (endianness)

```c
typedef unsigned int __bitwise __le32;
typedef unsigned int __bitwise __be32;

__le32 x;
u32 y = x;             // ← Sparse: incorrect type in assignment
u32 y = le32_to_cpu(x);// OK
```

`__bitwise` crea un tipo **incompatible con su base** aunque tenga el mismo tamaño. Sirve
para cualquier "unidad" que no deba mezclarse (endianness, handles opacos, flags tipados).

### Balance de contexto (locks)

```c
static void toma(struct lock *l) __acquires(l);
static void suelta(struct lock *l) __releases(l);

void f(struct lock *l)
{
    toma(l);
    if (error)
        return;    // ← Sparse: context imbalance in 'f' - wrong count at exit
    suelta(l);
}
```

## Issues conocidos por la comunidad

| Problema | Detalle |
|---|---|
| Sin anotaciones, Sparse casi no aporta | el valor está en `__user`/`__iomem`/`__bitwise`; en código sin anotar apenas encuentra nada |
| No entiende algunas extensiones GCC recientes | atributos nuevos generan "unknown attribute" ruidoso |
| Falsos positivos de context imbalance | con locks condicionales (`if (x) lock()`) es inevitable; se marcan con `__cond_lock()` o se ignoran |
| `__force` se abusa | es la vía de escape; si aparece por todas partes, las anotaciones dejaron de tener valor |
| Salida muy verbosa la primera vez | miles de warnings en un árbol nunca analizado; hay que fijar baseline |
| Distinto comportamiento entre versiones | los checks nuevos aparecen sin aviso al actualizar el paquete |

## Tips y buenas prácticas

1. **Empieza por `__bitwise` para endianness** si el código habla con hardware o formatos de fichero: es donde se esconden los bugs más caros y silenciosos.
2. **Anota progresivamente**: un subsistema por commit. Anotar todo de golpe genera un muro de warnings que nadie revisa.
3. `__force` debe justificarse con un comentario **siempre**. Sin excepción.
4. Corre Sparse **antes** que Smatch: Smatch usa el parser de Sparse y los errores de parseo enmascaran checks.
5. `make C=2 CF="-Wsparse-all"` una vez para tener el mapa completo; luego `C=1` en el día a día.
6. Combínalo con `-Wsparse-error` en CI para que los warnings nuevos rompan el build una vez que hayas limpiado el baseline.
7. Sparse **no sustituye** a clang-tidy ni a gcc `-fanalyzer`: son ortogonales. Sparse ve tipos y contexto, los otros ven flujo de datos.
