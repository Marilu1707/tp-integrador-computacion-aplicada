# Entregables

Acá van los archivos que pide la consigna 6.2, generados en la VM con
[`scripts/empaquetar_entregables.sh`](../scripts/empaquetar_entregables.sh)
y copiados con `scp` (ver [docs/06-entregables.md](../docs/06-entregables.md)):

| Archivo | Contenido |
|---|---|
| `root.tar.gz` | `/root` (home de root: index.php, logo.png, db.sql, claves SSH) |
| `etc.tar.gz` | `/etc` (toda la configuración: red, SSH, Apache, fstab...) |
| `opt.tar.gz` | `/opt` (`/opt/scripts/backup_full.sh` y `/opt/particion`) |
| `www_dir.tar.gz` | `/www_dir` (el sitio web en la partición de 3 GB) |
| `backup_dir.tar.gz` | `/backup_dir` (los backups en la partición de 6 GB) |
| `var.tar.gz.part-NN` | `/var` cortado en partes de 45 MB |
| `SHA256SUMS.txt` | Huellas para verificar que los archivos llegaron enteros |

Para volver a armar `/var`:

```bash
cat var.tar.gz.part-* > var.tar.gz   # une las partes en orden (00, 01, 02...)
tar -tzf var.tar.gz | head           # lista el contenido para comprobar que está entero
```
