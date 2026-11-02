# TP Integrador — Computación Aplicada

![Debian 12](https://img.shields.io/badge/Debian-12%20Bookworm-e75480)
![Apache + PHP](https://img.shields.io/badge/Apache-PHP%208.2-ff69b4)
![MariaDB](https://img.shields.io/badge/MariaDB-db.sql-f4a6c1)
![Backup](https://img.shields.io/badge/backup-cron-c71585)

**Universidad de Palermo · Facultad de Ingeniería · Computación Aplicada**
Profesor: Matías Chiesa

## Palermo Cloud 🌸

Somos **Palermo Cloud**, una empresa (ficticia) de hosting. Un cliente nos entrega su servidor Debian **sin la clave de administrador** y nos pide dejarlo listo para producción:

- recuperar el acceso y dejarlo identificado como **TPServer**;
- actualizarlo a **Debian 12**;
- acceso remoto seguro por **SSH con clave**;
- su sitio web en **Apache + PHP** con la base de datos en **MariaDB**;
- una **IP fija** para que siempre se lo encuentre;
- un **disco aparte** para la web y para los backups;
- **backups automáticos** todos los días.

Ese es exactamente el TP integrador: este repositorio documenta cómo lo resolvimos, paso a paso y con cada comando comentado.

## Integrantes

| # | Nombre y apellido | Usuario de GitHub |
|---|---|---|
| 1 | María Luján Massironi | [@Marilu1707](https://github.com/Marilu1707) |
| 2 | _(completar)_ | _(completar)_ |
| 3 | _(completar)_ | _(completar)_ |
| 4 | _(completar)_ | _(completar)_ |
| 5 | _(completar)_ | _(completar)_ |

## Guía paso a paso

Seguir en este orden. Cada guía arranca con lo que pide la consigna y termina con cómo verificarlo.

| # | Guía | Consigna |
|---|---|---|
| 1 | [Configuración del entorno](docs/01-configuracion-entorno.md) | Importar la VM, blanquear root (`palermo`), hostname `TPServer` |
| 2 | [Servicios](docs/02-servicios.md) | Debian 12, SSH con clave, Apache + PHP, MariaDB + `db.sql` |
| 3 | [Red](docs/03-red.md) | IP estática con address, netmask y gateway |
| 4 | [Almacenamiento](docs/04-almacenamiento.md) | Disco de 10 GB, particiones tipo 83, fstab, Apache en `/www_dir` |
| 5 | [Backup](docs/05-backup.md) | `backup_full.sh` + cron |
| 6 | [Entregables](docs/06-entregables.md) | Comprimir directorios, cortar `/var`, subir a GitHub |

> 💡 Orden recomendado en la práctica: 1 → 2.1 (actualizar mientras hay Internet por DHCP) → 3 → resto de 2 → 4 → 5 → 6.

## Qué hay en el repositorio

```
├── README.md                         ← este archivo
├── docs/                             ← la guía paso a paso (todos los comandos comentados)
├── config/                           ← cómo quedan los archivos de configuración, explicados línea por línea
│   ├── etc/network/interfaces             IP estática (consigna 3)
│   ├── etc/apt/sources.list               repositorios de Debian 12 (2.1)
│   ├── etc/ssh/sshd_config.d/tp.conf      SSH para root solo con clave (2.2)
│   ├── etc/apache2/sites-available/000-default.conf   Apache sirviendo /www_dir (4.3)
│   ├── etc/apache2/apache2.conf.fragmento permiso de Apache para /www_dir (4.3)
│   ├── etc/fstab.fragmento                montaje automático (4.4 y 4.5)
│   └── crontab-root.txt                   programación de los backups (5.7)
├── scripts/
│   ├── backup_full.sh                ← el script de backup que pide la consigna (va en /opt/scripts)
│   ├── verificar_tp.sh               ← chequea en la VM cada punto de la consigna: [ OK ] / [FALTA]
│   └── empaquetar_entregables.sh     ← genera los .tar.gz y las partes de /var para subir
├── informe/                          ← informe del TP (abrir informe.html y exportar a PDF)
│   └── capturas/                     ← acá van las capturas de pantalla de la VM
└── entregables/                      ← acá van los .tar.gz de la VM (consigna 6.2)
```

## Convención de comentarios

Como buena práctica, todo el código y la configuración del repositorio está comentado:

- **Encabezado** en cada script y archivo de configuración: **qué es**, **para qué sirve** y **cómo se usa** (y dónde va dentro de la VM).
- **Un comentario arriba de cada bloque** que explica qué hace esa parte y **por qué** se hizo así (por ejemplo, por qué se valida con `mountpoint` o por qué se usa el UUID en fstab).
- En la guía de `docs/`, **cada comando lleva su comentario** al costado (`# ...`) con lo que hace cada opción.

## Scripts

Todos se ejecutan **como root dentro de la VM**. Para pasarlos a la VM: copiarlos por `scp` una vez que SSH funciona, o abrir el archivo en GitHub, copiar el contenido y pegarlo en `nano`.

```bash
# Backup (consigna 5)
/opt/scripts/backup_full.sh -help                  # ayuda
/opt/scripts/backup_full.sh /www_dir /backup_dir   # → /backup_dir/www_dir_bkp_AAAAMMDD.tar.gz

# Chequeo de la consigna completa (no modifica nada)
bash verificar_tp.sh

# Generar los entregables (al final de todo)
bash empaquetar_entregables.sh                     # → /home/entregables
```

## Entregables (consigna 6.2)

Los archivos de la VM van en [`entregables/`](entregables/):

- `root.tar.gz`, `etc.tar.gz`, `opt.tar.gz`, `www_dir.tar.gz`, `backup_dir.tar.gz`
- `var.tar.gz.part-00`, `var.tar.gz.part-01`, ... (unir con `cat var.tar.gz.part-* > var.tar.gz`)
- `SHA256SUMS.txt` (verificar con `sha256sum -c SHA256SUMS.txt`)

## Bibliografía

- Apuntes de la cátedra de Computación Aplicada (UP): comandos, FHS, redirecciones y pipes, gestor de paquetes, administración de usuarios, permisos, editores de texto.
- Niklas, P. (2020). *GNU/Linux, con sabor a Debian*. 1.ª edición.
- Debian. *Upgrades from Debian 11 (bullseye)* — [debian.org/releases/bookworm/releasenotes](https://www.debian.org/releases/bookworm/amd64/release-notes/ch-upgrading.html)
- Debian Wiki. *SSH* — [wiki.debian.org/SSH](https://wiki.debian.org/SSH) · *fstab* — [wiki.debian.org/fstab](https://wiki.debian.org/fstab)
- Apache HTTP Server. *Core features: DocumentRoot, Directory* — [httpd.apache.org/docs/2.4](https://httpd.apache.org/docs/2.4/mod/core.html)
- `man` de cada comando usado: `fdisk`, `mkfs.ext4`, `mount`, `tar`, `split`, `crontab`, `sshd_config`.
