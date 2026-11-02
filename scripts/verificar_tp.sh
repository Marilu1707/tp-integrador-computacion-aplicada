#!/bin/bash
# =============================================================================
#  verificar_tp.sh — Chequea en la VM cada punto de la consigna
# =============================================================================
#  Para qué sirve:
#    Revisa cada punto de la consigna y muestra [ OK ] o [FALTA], para saber
#    qué está funcionando y qué falta antes de entregar.
#
#  Uso (como root, dentro de la VM):
#    bash verificar_tp.sh
#
#  Es de SOLO LECTURA: no cambia nada del sistema, solo mira.
# =============================================================================

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Contadores de puntos OK y totales (para el porcentaje final).
OK=0
TOTAL=0

# -----------------------------------------------------------------------------
# chequear "descripción" comando...
#   Ejecuta el comando; si sale bien (código 0) suma un OK.
#   "shift" saca el primer argumento (la descripción) y deja solo el comando
#   en "$@", que después ejecutamos. La salida del comando se descarta
#   (> /dev/null 2>&1): solo importa si funcionó o no.
# -----------------------------------------------------------------------------
chequear() {
    local descripcion="$1"
    shift
    TOTAL=$((TOTAL + 1))                 # $(( )) = cuenta aritmética
    if "$@" > /dev/null 2>&1; then
        OK=$((OK + 1))
        echo "  [ OK ] $descripcion"
    else
        echo "  [FALTA] $descripcion"
    fi
}

# Título de cada sección.
seccion() {
    echo
    echo "== $1 =="
}

# Si no somos root, varias cosas no se pueden leer (shadow, crontab de root...).
# "id -u" devuelve el número de usuario (UID): root es 0.
if [ "$(id -u)" -ne 0 ]; then
    echo "Ejecutar como root:  su -  y después  bash verificar_tp.sh"
    exit 1
fi

# -----------------------------------------------------------------------------
seccion "1) Entorno"
# -----------------------------------------------------------------------------
# "[ ... = ... ]" compara textos. "hostname" devuelve el nombre de la máquina.
chequear "Hostname es TPServer"                 [ "$(hostname)" = "TPServer" ]
# grep -q = buscar sin mostrar nada (solo el resultado: encontró o no).
chequear "TPServer figura en /etc/hosts"        grep -q "TPServer" /etc/hosts

# -----------------------------------------------------------------------------
seccion "2) Servicios"
# -----------------------------------------------------------------------------
# grep -q "^12" = el texto EMPIEZA con 12 (^ = principio de línea).
chequear "Debian 12 (bookworm)"                 grep -q "^12" /etc/debian_version
# "systemctl is-active" devuelve 0 si el servicio está corriendo.
chequear "Servicio SSH activo"                  systemctl is-active --quiet ssh
# "sshd -T" muestra la configuración EFECTIVA (la que realmente aplica).
chequear "SSH: root solo con clave"             sh -c "sshd -T 2>/dev/null | grep -qi '^permitrootlogin \(prohibit-password\|without-password\)'"
# -s = el archivo existe y NO está vacío.
chequear "Hay clave en /root/.ssh/authorized_keys"  [ -s /root/.ssh/authorized_keys ]
chequear "Apache activo"                        systemctl is-active --quiet apache2
chequear "PHP instalado"                        php -v
# Lista los módulos cargados de Apache y busca el de PHP.
chequear "Apache tiene el módulo PHP"           sh -c "apache2ctl -M 2>/dev/null | grep -qi php"
chequear "MariaDB activo"                       systemctl is-active --quiet mariadb
# Cuenta las bases que NO son las del sistema: si hay al menos una, se cargó db.sql.
chequear "Hay una base cargada (db.sql)"        sh -c "mysql -N -e 'SHOW DATABASES;' | grep -v -E '^(information_schema|mysql|performance_schema|sys)$' | grep -q ."

# -----------------------------------------------------------------------------
seccion "3) Red"
# -----------------------------------------------------------------------------
chequear "Interfaz configurada como static"     grep -Eq "^\s*iface\s+\S+\s+inet\s+static" /etc/network/interfaces
chequear "Campo address"                        grep -Eq "^\s*address\s+" /etc/network/interfaces
chequear "Campo netmask"                        grep -Eq "^\s*netmask\s+" /etc/network/interfaces
chequear "Campo gateway"                        grep -Eq "^\s*gateway\s+" /etc/network/interfaces
# "ip route" muestra la ruta por defecto (el gateway en uso).
chequear "Hay gateway en uso"                   sh -c "ip route | grep -q '^default'"

# -----------------------------------------------------------------------------
seccion "4) Almacenamiento"
# -----------------------------------------------------------------------------
# -b = existe y es un "dispositivo de bloques" (un disco o partición).
chequear "Existe /dev/sdb1"                     [ -b /dev/sdb1 ]
chequear "Existe /dev/sdb2"                     [ -b /dev/sdb2 ]
chequear "/www_dir montado"                     mountpoint -q /www_dir
chequear "/backup_dir montado"                  mountpoint -q /backup_dir
chequear "/www_dir en /etc/fstab"               grep -Eq "^[^#]\S*\s+/www_dir\s" /etc/fstab
chequear "/backup_dir en /etc/fstab"            grep -Eq "^[^#]\S*\s+/backup_dir\s" /etc/fstab
chequear "index.php en /www_dir"                [ -f /www_dir/index.php ]
chequear "logo.png en /www_dir"                 [ -f /www_dir/logo.png ]
chequear "Apache sirve desde /www_dir"          grep -Eq "^\s*DocumentRoot\s+/www_dir" /etc/apache2/sites-available/000-default.conf
chequear "apache2.conf permite /www_dir"        grep -q "<Directory /www_dir" /etc/apache2/apache2.conf
chequear "Existe /opt/particion con sdb"        grep -q "sdb" /opt/particion

# -----------------------------------------------------------------------------
seccion "5) Backup"
# -----------------------------------------------------------------------------
# -x = el archivo existe y tiene permiso de ejecución.
chequear "Script /opt/scripts/backup_full.sh ejecutable"  [ -x /opt/scripts/backup_full.sh ]
chequear "El script responde a -help"           /opt/scripts/backup_full.sh -help
chequear "cron activo"                          systemctl is-active --quiet cron
# "crontab -l" lista las tareas de root. Buscamos las dos programaciones.
chequear "cron: /var/log todos los días 00:00"  sh -c "crontab -l | grep -Eq '^0 0 \* \* \* .*backup_full\.sh /var/log'"
chequear "cron: /www_dir lun-mié-vie 23:00"     sh -c "crontab -l | grep -Eq '^0 23 \* \* 1,3,5 .*backup_full\.sh /www_dir'"
# "ls ... | grep -q ." = hay al menos un archivo que coincide.
chequear "Hay algún backup en /backup_dir"      sh -c "ls /backup_dir/*_bkp_*.tar.gz | grep -q ."

# -----------------------------------------------------------------------------
# Resumen final.
# -----------------------------------------------------------------------------
PORCENTAJE=$((OK * 100 / TOTAL))
echo
echo "Resultado: $OK de $TOTAL puntos OK ($PORCENTAJE%)."
echo "(Es una guía: no reemplaza probar SSH y la web desde la máquina física.)"
