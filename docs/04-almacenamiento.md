# 4) Almacenamiento: disco nuevo, particiones y montaje automático

> **Consigna 4:** agregar un disco de 10 GB, crear dos particiones tipo 83 (`/www_dir` de 3 GB y `/backup_dir` de 6 GB), mover la web a `/www_dir`, montar las dos automáticamente y guardar `/proc/partitions` en `/opt/particion`.
> **Escenario Palermo Cloud:** separamos la web y los backups del disco del sistema: si el disco principal se llena o se rompe, el sitio y las copias quedan a salvo.

---

## 4.1 Agregar el disco de 10 GB (en VirtualBox)

Con la VM **apagada**:

1. **Configuración → Almacenamiento**.
2. Seleccionar **Controlador: SATA** → ícono de **disco con "+"** (*Agregar disco duro*) → **Crear**.
3. Tipo **VDI**, *Reservado dinámicamente*, tamaño **10 GB** → *Terminar* → *Seleccionar*.
4. Prender la VM y comprobar que Linux lo ve:

```bash
lsblk       # lista los discos. El nuevo aparece como "sdb" de 10G, sin particiones
            # (sda es el disco del sistema: NO tocarlo)
```

---

## 4.2 Crear las dos particiones tipo 83

**Tipo 83** = partición **"Linux"** estándar (el código que usa la tabla de particiones MBR/DOS para indicar que es para Linux).

```bash
fdisk /dev/sdb      # programa interactivo para particionar el disco NUEVO (¡sdb, no sda!)
```

Dentro de `fdisk`, escribir estas letras y presionar Enter después de cada una:

| Tecla | Qué hace | Para la 1.ª partición (www) | Para la 2.ª (backup) |
|---|---|---|---|
| `n` | Nueva partición | `n` | `n` |
| `p` | Tipo **primaria** | `p` | `p` |
| número | Número de partición | `1` | `2` |
| primer sector | Dónde empieza | Enter (valor por defecto) | Enter |
| último sector | Tamaño | `+3G` | `+6G` |

Después:

| Tecla | Qué hace |
|---|---|
| `p` | **Mostrar** la tabla: las dos particiones tienen que decir **Id 83, Type Linux** |
| `w` | **Escribir** los cambios en el disco y salir (hasta acá nada se guardó) |

> **Nota:** Las particiones nuevas ya se crean con tipo 83 por defecto. Si alguna dijera otro tipo: `t` → número de partición → `83`.
> **Nota:** Si `fdisk` dice *"Created a new DOS disklabel"*, está bien: el disco estaba vacío y le creó la tabla de particiones MBR.

```bash
lsblk       # ahora: sdb1 (3G) y sdb2 (6G)
```

### Formatear (darles sistema de archivos)

Una partición recién creada es un espacio vacío: hay que darle formato para poder guardar archivos.

```bash
mkfs.ext4 /dev/sdb1     # formatea la partición 1 en ext4 (el formato nativo de Linux)
mkfs.ext4 /dev/sdb2     # ídem la partición 2
lsblk -f                # muestra el FSTYPE (ext4) y el UUID de cada una
```

---

## 4.3 Montar `/www_dir` y mover la web

**Montar** = conectar una partición a una carpeta. Todo lo que se guarde en esa carpeta va a parar a la partición.

```bash
mkdir /www_dir /backup_dir       # crear los "puntos de montaje" (carpetas vacías)
mount /dev/sdb1 /www_dir         # montar a mano (para probar; lo automático es en 4.4)
mount /dev/sdb2 /backup_dir
df -h                            # tienen que aparecer /dev/sdb1 en /www_dir y /dev/sdb2 en /backup_dir

cp /root/index.php /root/logo.png /www_dir/   # copiar la web a la partición nueva
chmod 755 /www_dir                            # Apache (usuario www-data) tiene que poder ENTRAR a la carpeta
chmod 644 /www_dir/index.php /www_dir/logo.png  # y LEER los archivos
```

> **Nota:** En `/www_dir` también aparece `lost+found`: lo crea `mkfs.ext4` para recuperar archivos si el disco se daña. Es normal, no se borra.

### Apuntar Apache a la nueva carpeta (dos archivos)

**1. `/etc/apache2/sites-available/000-default.conf`** → cambiar el `DocumentRoot`:

```
DocumentRoot /www_dir        # antes: /var/www/html
```

Archivo completo y explicado: [`config/etc/apache2/sites-available/000-default.conf`](../config/etc/apache2/sites-available/000-default.conf).

**2. `/etc/apache2/apache2.conf`** → darle permiso a Apache para servir esa carpeta. Agregar debajo del bloque `<Directory /var/www/>`:

```
<Directory /www_dir/>
    Options Indexes FollowSymLinks
    AllowOverride None
    Require all granted
</Directory>
```

Explicado en [`config/etc/apache2/apache2.conf.fragmento`](../config/etc/apache2/apache2.conf.fragmento).

```bash
apache2ctl configtest        # tiene que decir "Syntax OK"
systemctl reload apache2     # aplica sin cortar el servicio
```

Probar desde la PC: `http://IP-DE-LA-VM` → la página se sigue viendo igual, pero ahora sale de `/www_dir`.

> **403 Forbidden** → falta el bloque `<Directory /www_dir/>` en `apache2.conf`, o los permisos de 4.3.
> **Página por defecto de Apache** → el `DocumentRoot` sigue apuntando a `/var/www/html`.

---

## 4.4 y 4.5 Montaje automático con `/etc/fstab`

Lo montado con `mount` se pierde al reiniciar. Para que se monte **siempre**, se declara en `/etc/fstab`.

```bash
blkid /dev/sdb1 /dev/sdb2              # copiar el UUID="..." de cada partición
cp /etc/fstab /etc/fstab.bak           # copia de seguridad (un error en fstab puede impedir el arranque)
nano /etc/fstab
```

Agregar al final (con **sus** UUID):

```
UUID=<uuid-de-sdb1>  /www_dir     ext4  defaults  0  2
UUID=<uuid-de-sdb2>  /backup_dir  ext4  defaults  0  2
```

Cada columna está explicada en [`config/etc/fstab.fragmento`](../config/etc/fstab.fragmento).

### Probar SIN reiniciar (importante)

```bash
umount /www_dir /backup_dir     # desmontar lo que montamos a mano
systemctl daemon-reload         # Debian 12 avisa que hay que recargar systemd después de editar fstab
mount -a                        # monta todo lo que dice fstab: si hay un error, lo muestra ACÁ
df -h                           # deben estar los dos montados
```

Si `mount -a` no da error y `df -h` los muestra, recién ahí reiniciar (`reboot`) y volver a verificar con `df -h`.

---

## Nota: guardar `/proc/partitions` en `/opt/particion`

`/proc` no es una carpeta real del disco: es un sistema de archivos **virtual** que el kernel genera en memoria. Por eso `/proc/partitions` desaparece al apagar. La consigna pide guardar una copia:

```bash
cat /proc/partitions > /opt/particion    # ">" redirige la salida de cat a un archivo (lo crea o lo pisa)
cat /opt/particion                       # tiene que listar sda, sda1..., sdb, sdb1 y sdb2
```

> Hacerlo **después** de crear las particiones, para que aparezcan sdb1 y sdb2.

---

**Capturas para el informe:** el disco en VirtualBox · `fdisk` con `p` (Id 83) · `lsblk -f` · las líneas de fstab · `df -h` después de reiniciar · `cat /opt/particion`.
