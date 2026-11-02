# 2) Servicios: Debian 12, SSH, Apache + PHP y MariaDB

> **Consigna 2:** actualizar a Debian 12, configurar SSH para root con clave pública/privada, Apache con PHP sirviendo `index.php` y `logo.png`, y MariaDB con el script `db.sql`.
> **Escenario Palermo Cloud:** dejamos el servidor del cliente actualizado y con todo lo necesario para alojar su web y su base de datos.

> 💡 **Orden recomendado:** hacer la actualización (2.1) **antes** de configurar la IP estática (consigna 3), mientras la VM todavía tiene Internet por DHCP. Si algo de red falla, no nos quedamos sin poder descargar paquetes.

---

## 2.1 Actualizar a Debian 12 (Bookworm)

### Ver qué versión tenemos

```bash
cat /etc/debian_version     # muestra el número: 10.x = Buster, 11.x = Bullseye, 12.x = Bookworm
```

> ⚠️ **Debian no se puede saltear versiones.** Si la VM es Debian 10, hay que hacer el proceso **dos veces**: 10 → 11 (bullseye) y después 11 → 12 (bookworm). Si es Debian 11, una sola vez.

### Paso a paso (se repite por cada salto de versión)

```bash
# 1) Dejar al día la versión ACTUAL antes de saltar
apt update                  # actualiza la LISTA de paquetes (no instala nada)
apt upgrade -y              # instala las versiones nuevas de lo que ya está instalado
apt full-upgrade -y         # igual, pero también puede agregar/quitar paquetes si hace falta

# 2) Copia de seguridad del archivo de repositorios (por si hay que volver atrás)
cp /etc/apt/sources.list /etc/apt/sources.list.bak

# 3) Apuntar los repositorios a la versión nueva
nano /etc/apt/sources.list
```

En el editor, reemplazar el nombre de la versión vieja por la nueva en **todas** las líneas. El archivo final para Debian 12 está en [`config/etc/apt/sources.list`](../config/etc/apt/sources.list), con cada línea explicada.

> ⚠️ Si venimos de **Debian 10**: la línea de seguridad tiene otro formato (`buster/updates`). En Debian 11 pasa a ser `http://security.debian.org/debian-security bullseye-security main`.

```bash
# 4) Hacer el salto
apt update                          # lee los repositorios NUEVOS
apt upgrade --without-new-pkgs -y   # primera pasada: actualiza sin instalar paquetes nuevos (más seguro)
apt full-upgrade -y                 # segunda pasada: completa la actualización del sistema
#   Durante el proceso puede preguntar:
#   - "¿Reiniciar servicios sin preguntar?" → Yes
#   - "¿Conservar tu versión de un archivo de configuración?" → la opción por defecto (conservar la actual)

# 5) Reiniciar y limpiar
reboot
apt autoremove -y                   # borra paquetes viejos que ya no se usan
```

### Verificar

```bash
cat /etc/debian_version     # tiene que empezar con 12
lsb_release -a              # "Debian GNU/Linux 12 (bookworm)"  (si no existe: apt install lsb-release)
```

---

## 2.2 SSH con clave pública/privada para root

**Cómo funciona una clave pública/privada:** son dos archivos que van juntos.
- La **clave pública** se deja en el servidor (en `authorized_keys`). Es como un candado.
- La **clave privada** la tiene solo quien se conecta. Es la única llave que abre ese candado.

Así root entra **sin contraseña** y nadie puede adivinarla probando claves.

### Instalar el servidor

```bash
apt install -y openssh-server   # el servidor SSH (sshd)
systemctl enable --now ssh      # lo deja activo ahora y en cada arranque
systemctl status ssh            # tiene que decir "active (running)"
```

### Autorizar la clave que viene en el home de root

```bash
ls -la /root                    # buscar la clave: un par tipo "id_rsa" (privada) e "id_rsa.pub" (pública)
                                # (el nombre puede variar: la pública es la que termina en .pub)

mkdir -p /root/.ssh             # carpeta donde SSH busca las claves autorizadas (-p: no da error si ya existe)
chmod 700 /root/.ssh            # solo root puede entrar a la carpeta (SSH rechaza permisos más abiertos)

cat /root/id_rsa.pub >> /root/.ssh/authorized_keys   # agrega la clave PÚBLICA a las autorizadas (>> = agrega, no pisa)
chmod 600 /root/.ssh/authorized_keys                 # solo root puede leer y escribir el archivo
```

> 💡 **¿Por qué tan estrictos con los permisos?** Si otro usuario pudiera escribir en `authorized_keys`, podría agregar su propia clave y entrar como root. Por eso `sshd` directamente **ignora** el archivo si los permisos son más abiertos que `700` / `600`.

### Configurar el servidor

Crear el archivo [`/etc/ssh/sshd_config.d/tp.conf`](../config/etc/ssh/sshd_config.d/tp.conf) con este contenido (en el repo está explicado línea por línea):

```
PermitRootLogin prohibit-password
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
```

```bash
sshd -t                     # chequea la sintaxis: si no imprime nada, está bien
systemctl restart ssh       # aplica la configuración
sshd -T | grep -i -E "permitrootlogin|pubkey"   # muestra los valores activos
```

### Probar desde la máquina física

1. Copiar la **clave privada** (`id_rsa`, la que NO termina en `.pub`) a la PC. Por ejemplo, abriéndola con `cat /root/id_rsa` y pegando el contenido en un archivo de texto en la PC llamado `id_rsa_tp`.
2. Desde la PC (en Windows: PowerShell o CMD):
   ```bash
   ssh -i id_rsa_tp root@192.168.0.150   # -i = usar esta clave privada · reemplazar por la IP de SU VM
   ```
3. La primera vez pregunta si confiamos en el servidor (*fingerprint*): escribir `yes`.

> ⚠️ Si dice *"UNPROTECTED PRIVATE KEY FILE"*, la clave tiene permisos muy abiertos en la PC. En Linux/Mac: `chmod 600 id_rsa_tp`. En Windows: Propiedades → Seguridad → dejar solo a tu usuario.

---

## 2.3 Apache con PHP

```bash
apt install -y apache2 php libapache2-mod-php php-mysql
#   apache2            → el servidor web
#   php                → el lenguaje PHP (Debian 12 trae PHP 8.2, cumple el "7.3 o superior")
#   libapache2-mod-php → el módulo que hace que Apache EJECUTE los .php en vez de mostrarlos como texto
#   php-mysql          → para que PHP pueda conectarse a MariaDB (el index.php seguramente lo use)

systemctl enable --now apache2   # activo ahora y en cada arranque
php -v                           # verificar versión de PHP (8.2.x)
```

### Servir `index.php` y `logo.png`

En esta etapa los dejamos en la carpeta por defecto de Apache. En la consigna 4 los pasamos a `/www_dir`.

```bash
cp /root/index.php /root/logo.png /var/www/html/   # copiar los archivos del home de root a la carpeta web
rm /var/www/html/index.html                        # borrar la página de bienvenida de Apache
```

> 💡 **¿Por qué borrar `index.html`?** Apache busca primero `index.html` y después `index.php`. Si no lo borramos, sigue apareciendo la página "Apache2 Debian Default Page" en lugar de nuestro sitio.

### Verificar

Desde la PC física, en el navegador: `http://IP-DE-LA-VM` → tiene que verse la página con el logo.
Si se ve el **código PHP como texto**, falta el módulo: `apt install libapache2-mod-php && systemctl restart apache2`.

---

## 2.4 MariaDB y el script `db.sql`

```bash
apt install -y mariadb-server    # el motor de base de datos (reemplazo libre de MySQL)
systemctl enable --now mariadb
mysql_secure_installation        # opcional pero recomendado: asistente de seguridad
                                 # (borra usuarios anónimos y la base "test")
```

### Cargar el script

```bash
head -30 /root/db.sql            # mirar el principio: ¿crea la base (CREATE DATABASE) o solo tablas?
mysql < /root/db.sql             # ejecuta TODO el script como root de MariaDB
                                 # "<" = redirección de ENTRADA: mysql lee los comandos desde el archivo
```

> ⚠️ Si el script **no** tiene `CREATE DATABASE`, hay que crear la base primero e indicarla:
> ```bash
> mysql -e "CREATE DATABASE nombre_base;"     # -e = ejecutar este comando SQL
> mysql nombre_base < /root/db.sql
> ```
> El nombre de la base está en el `index.php`: `grep -n -i -E "mysqli|pdo|dbname" /root/index.php`

### Verificar

```bash
mysql -e "SHOW DATABASES;"                    # tiene que aparecer la base del script
mysql -e "SHOW TABLES;" nombre_base           # las tablas que creó
```

Y en el navegador: la página de `index.php` tiene que mostrar los datos de la base sin errores de conexión.

---

📸 **Capturas para el informe:** `lsb_release -a` en 12 · `ssh -i` exitoso desde la PC · el sitio en el navegador de la PC · `SHOW DATABASES`.
