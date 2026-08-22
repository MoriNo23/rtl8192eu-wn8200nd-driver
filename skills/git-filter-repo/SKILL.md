---
name: git-filter-repo
description: Reescritura de historia Git con git-filter-repo — extraer subdirectorios, borrar ficheros pesados o secretos, renombrar rutas masivamente. Sustituto oficial de git filter-branch.
---

# git-filter-repo

Herramienta recomendada oficialmente por el proyecto Git como sustituto de
`git filter-branch` (que está deprecado por lento y por generar historias corruptas de
forma sutil).

- Repo: `https://github.com/newren/git-filter-repo`
- Autor: Elijah Newren (mantenedor de Git)
- Licencia: MIT
- Un solo fichero Python, sin dependencias más allá de Python 3.6+ y Git 2.24+

## Instalación

```bash
sudo apt install git-filter-repo
sudo dnf install git-filter-repo
pip install git-filter-repo
# o simplemente:
curl -o ~/bin/git-filter-repo \
  https://raw.githubusercontent.com/newren/git-filter-repo/main/git-filter-repo
chmod +x ~/bin/git-filter-repo
```

## Regla de seguridad número uno

`git-filter-repo` **reescribe todos los SHA** y por diseño exige un clon fresco.
Trabaja siempre sobre una copia:

```bash
git clone --no-local /ruta/original /tmp/trabajo
cd /tmp/trabajo
# ... filtros ...
# solo cuando estés seguro:
git remote add origin <url>
git push --force --all && git push --force --tags
```

Si insistes en operar sobre un repo con remotos, necesitas `--force`. La herramienta te lo
impide a propósito.

## Operaciones más usadas

```bash
# extraer un subdirectorio como si siempre hubiera sido la raíz
git filter-repo --subdirectory-filter src/libfoo

# lo contrario: sacar un subdirectorio de la historia
git filter-repo --path vendor/ --invert-paths

# conservar solo ciertas rutas
git filter-repo --path src/ --path include/ --path LICENSE

# renombrar rutas en toda la historia
git filter-repo --path-rename old/dir:new/dir
git filter-repo --path-rename-glob '*.txt:docs/*.txt'

# borrar ficheros por tamaño (limpiar blobs pesados)
git filter-repo --strip-blobs-bigger-than 10M

# borrar un fichero concreto de toda la historia (secretos)
git filter-repo --invert-paths --path config/credenciales.env

# reemplazar texto en TODO el contenido histórico
cat > reemplazos.txt <<'EOF'
literal:AKIAIOSFODNN7EXAMPLE==>***REMOVED***
regex:password\s*=\s*"[^"]*"==>password = "***"
EOF
git filter-repo --replace-text reemplazos.txt

# corregir autores/emails
cat > mailmap.txt <<'EOF'
Nombre Correcto <bueno@ejemplo.com> <viejo@ejemplo.com>
EOF
git filter-repo --mailmap mailmap.txt

# reescribir mensajes de commit
git filter-repo --message-callback '
  return message.replace(b"TICKET-", b"PROJ-")
'
```

## Callbacks en Python (el modo potente)

```bash
git filter-repo --commit-callback '
  # borra commits vacíos generados por el filtrado
  if not commit.file_changes:
      commit.skip()
'

git filter-repo --filename-callback '
  if filename.endswith(b".bak"):
      return None          # elimina el fichero
  return filename.replace(b"src/", b"lib/")
'

git filter-repo --blob-callback '
  if len(blob.data) > 5_000_000:
      blob.data = b"[fichero eliminado por tamano]\n"
'
```

## Analizar antes de filtrar

```bash
git filter-repo --analyze
# genera .git/filter-repo/analysis/ con:
#   path-all-sizes.txt        tamaño por ruta a lo largo de la historia
#   blob-shas-and-paths.txt   los blobs más pesados y dónde vivieron
#   directories-all-sizes.txt qué directorio infla el repo
#   extensions-all-sizes.txt  por extensión
```

Esto es lo primero que hay que ejecutar: casi siempre revela que el 80% del peso del repo
son tres directorios de artefactos que alguien commiteó una vez.

## Issues conocidos por la comunidad

| Problema | Detalle |
|---|---|
| "Refusing to destructively overwrite repo history" | falta clon fresco; usar `--force` solo si sabes lo que haces |
| Elimina los remotos tras filtrar | es intencional, para que no hagas push accidental; hay que re-añadirlos |
| Todos los SHA cambian | cualquier referencia externa (issues, CI, tags de despliegue, submódulos) queda rota |
| Los objetos viejos siguen en el repo local | `git reflog expire --expire=now --all && git gc --prune=now --aggressive` |
| En GitHub los blobs siguen accesibles por SHA | tras purgar un secreto hay que **rotar la credencial igualmente** y pedir a soporte que limpie |
| Commits vacíos tras filtrar rutas | usar `--prune-empty=always` o el `commit-callback` con `skip()` |
| Rompe firmas GPG de los commits | las firmas dejan de validar; hay que refirmar o asumirlo |
| Submódulos | no los reescribe; hay que tratarlos aparte |

## Tips y buenas prácticas

1. **`--analyze` siempre primero.** Sin datos estás adivinando qué inflar el repo.
2. Trabaja en `/tmp` sobre un `git clone --no-local`, nunca en tu repo de trabajo.
3. **Avisa al equipo antes de forzar el push**: todo el mundo tendrá que reclonar. Un `git pull` tras una reescritura produce un merge monstruoso.
4. Si el objetivo es purgar un secreto: filtrar la historia **no sustituye** a rotar la credencial. Asume que está comprometida.
5. Combina filtros en una sola pasada (`--path` + `--path-rename` juntos): cada pasada adicional multiplica el tiempo y el riesgo.
6. Guarda el comando exacto usado en un fichero `HISTORY-REWRITE.md` del repo. Dentro de un año nadie recordará por qué los SHA no cuadran con los tickets viejos.
7. Verifica después: `git log --stat`, `git count-objects -vH` y compila el proyecto desde el clon reescrito.
8. Para extraer un subdirectorio conservando historia, `--subdirectory-filter` es mucho mejor que `git subtree split`: preserva merges y renombrados correctamente.
