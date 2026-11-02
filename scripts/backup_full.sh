#!/bin/bash
# =============================================================================
#  backup_full.sh — Script de backup del TP integrador (Computación Aplicada)
# =============================================================================
#  Va en: /opt/scripts/backup_full.sh   (lo pide la consigna 5.1)
#
#  Qué hace, en una línea:
#    Comprime un directorio de ORIGEN en un .tar.gz con la fecha de hoy en el
#    nombre y lo guarda en un DESTINO (normalmente /backup_dir).
#
#  Ejemplo:
#    ./backup_full.sh /var/log /backup_dir
#    → crea /backup_dir/log_bkp_20241102.tar.gz
#       (nombre del directorio + "_bkp_" + fecha AAAAMMDD, consigna 5.2)
#
#  Para ver la ayuda:  ./backup_full.sh -help
#
#  Cada bloque tiene un comentario arriba que explica QUÉ hace y POR QUÉ.
# =============================================================================


# -----------------------------------------------------------------------------
# PATH fijo.
# Cuando el script lo ejecuta cron, cron NO carga el mismo entorno que nuestra
# terminal: el PATH viene casi vacío y comandos como "mountpoint" (que está en
# /usr/bin o /bin) o "tar" podrían "no encontrarse". Definiendo el PATH acá nos
# aseguramos de que funcione igual a mano que desde cron.
# -----------------------------------------------------------------------------
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin


# -----------------------------------------------------------------------------
# Fecha en formato ANSI (AAAAMMDD), consigna 5.2.
# "date +%Y%m%d" → %Y = año con 4 cifras, %m = mes, %d = día. Ej.: 20241102.
# La guardamos UNA vez al principio para que todo el script use la misma fecha
# (si el backup arranca 23:59 y termina 00:01, el nombre no cambia a mitad).
# -----------------------------------------------------------------------------
FECHA=$(date +%Y%m%d)


# -----------------------------------------------------------------------------
# Función ayuda: es lo que se muestra con -help (consigna 5.5).
# "cat <<EOF ... EOF" (un "here document") imprime todo el bloque de texto
# tal cual, sin tener que poner un echo por línea.
# "$(basename "$0")" muestra el nombre del script (backup_full.sh).
# -----------------------------------------------------------------------------
ayuda() {
    cat <<EOF
Uso:
  $(basename "$0") ORIGEN DESTINO
  $(basename "$0") -help

Descripción:
  Genera un backup comprimido (.tar.gz) del directorio ORIGEN y lo guarda
  en el directorio DESTINO. El archivo se llama:

      <nombre_del_origen>_bkp_<AAAAMMDD>.tar.gz

Argumentos:
  ORIGEN    Directorio a respaldar.           Ej.: /var/log   o   /www_dir
  DESTINO   Directorio donde dejar el backup. Ej.: /backup_dir
  -help     Muestra esta ayuda (también -h o --help).

Ejemplos:
  $(basename "$0") /var/log /backup_dir   →  /backup_dir/log_bkp_${FECHA}.tar.gz
  $(basename "$0") /www_dir /backup_dir   →  /backup_dir/www_dir_bkp_${FECHA}.tar.gz

Validaciones antes de copiar:
  - que ORIGEN y DESTINO existan y sean directorios;
  - que su sistema de archivos esté disponible (montado), sobre todo si
    figuran en /etc/fstab como punto de montaje propio;
  - que se pueda escribir en DESTINO.

Códigos de salida:
  0 = backup OK · 1 = error de uso · 2 = origen no disponible
  3 = destino no disponible · 4 = falló tar
EOF
}


# -----------------------------------------------------------------------------
# Función log: imprime un mensaje con fecha y hora delante.
# Sirve para que, cuando lo corre cron y la salida va a un archivo de log,
# se sepa CUÁNDO pasó cada cosa.
#   "$*" = todos los argumentos que le pasamos a la función, como un texto.
# -----------------------------------------------------------------------------
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# Igual que log, pero manda el mensaje a la salida de ERROR (stderr = 2).
# ">&2" redirige el echo al canal 2. Así los errores se pueden separar de los
# mensajes normales, por ejemplo con "2> errores.log".
error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $*" >&2
}


# -----------------------------------------------------------------------------
# Función fs_disponible: valida que el sistema de archivos de un directorio
# esté disponible (consigna 5.6). Devuelve 0 (OK) o 1 (no disponible).
#
# Por qué no alcanza con ver si la carpeta existe:
#   Si la partición de /backup_dir NO está montada, la carpeta /backup_dir
#   igual existe (es el "punto de montaje" vacío sobre el disco principal).
#   Si copiáramos ahí, el backup quedaría en el disco del sistema y no en la
#   partición de 6 GB → justo lo que la consigna quiere evitar.
#
# Qué chequeamos:
#   1) que el directorio exista            → [ -d "$dir" ]
#   2) que el sistema pueda leer su FS     → df "$dir"
#   3) si el directorio figura en /etc/fstab como punto de montaje, que esté
#      REALMENTE montado                   → mountpoint -q "$dir"
# -----------------------------------------------------------------------------
fs_disponible() {
    local dir="$1"     # "local" = la variable solo existe dentro de la función

    # 1) ¿Existe y es un directorio? (-d = "is directory")
    if [ ! -d "$dir" ]; then
        error "'$dir' no existe o no es un directorio."
        return 1
    fi

    # 2) ¿El sistema puede consultar su sistema de archivos?
    #    "df -P" muestra el filesystem que contiene a ese directorio.
    #    "> /dev/null 2>&1" descarta la salida normal y los errores: solo nos
    #    importa si el comando salió bien (código 0) o mal.
    if ! df -P "$dir" > /dev/null 2>&1; then
        error "No se puede acceder al sistema de archivos de '$dir'."
        return 1
    fi

    # 3) Si el directorio está declarado en /etc/fstab (ej.: /www_dir y
    #    /backup_dir), tiene que estar montado.
    #    - awk recorre /etc/fstab, ignora comentarios (líneas que empiezan
    #      con #) y compara la 2.ª columna (el punto de montaje) con $dir.
    #    - "mountpoint -q" devuelve 0 si el directorio es un punto de montaje
    #      activo, y 1 si no lo es. -q = "quiet", no imprime nada.
    if [ -f /etc/fstab ] && \
       awk -v d="$dir" '$1 !~ /^#/ && $2 == d {found=1} END {exit !found}' /etc/fstab; then
        if ! mountpoint -q "$dir"; then
            error "'$dir' figura en /etc/fstab pero NO está montado. Probar: mount -a"
            return 1
        fi
    fi

    return 0
}


# =============================================================================
#  PROGRAMA PRINCIPAL
# =============================================================================

# -----------------------------------------------------------------------------
# Opción de ayuda (consigna 5.5).
# "$1" es el primer argumento. Aceptamos -help (lo que pide la consigna) y
# también -h / --help, que es lo habitual en Linux.
# "exit 0" termina el script indicando que salió bien.
# -----------------------------------------------------------------------------
case "$1" in
    -help|-h|--help)
        ayuda
        exit 0
        ;;
esac

# -----------------------------------------------------------------------------
# Cantidad de argumentos (consigna 5.4: origen y destino).
# "$#" = cuántos argumentos recibió el script. Tienen que ser exactamente 2.
# "-ne" = "not equal" (distinto). Si no son 2, mostramos la ayuda y salimos
# con código 1 (error de uso).
# -----------------------------------------------------------------------------
if [ "$#" -ne 2 ]; then
    error "Faltan argumentos (o sobran). Se esperan ORIGEN y DESTINO."
    echo "Usá: $(basename "$0") -help" >&2
    exit 1
fi

# -----------------------------------------------------------------------------
# Guardamos los argumentos en variables con nombre (más fácil de leer).
# "${1%/}" saca la "/" final si la escribieron (ej.: /www_dir/ → /www_dir),
# así el nombre del backup sale prolijo y la comparación con fstab funciona.
# -----------------------------------------------------------------------------
ORIGEN="${1%/}"
DESTINO="${2%/}"

# Si alguien pasa "/" como origen, "${1%/}" lo deja vacío: lo corregimos.
[ -z "$ORIGEN" ] && ORIGEN="/"
[ -z "$DESTINO" ] && DESTINO="/"

# -----------------------------------------------------------------------------
# Validaciones del sistema de archivos (consigna 5.6).
# Usamos códigos de salida distintos (2 y 3) para saber cuál de los dos falló
# sin tener que leer el mensaje.
# -----------------------------------------------------------------------------
if ! fs_disponible "$ORIGEN"; then
    error "Origen no disponible. No se hace el backup."
    exit 2
fi

if ! fs_disponible "$DESTINO"; then
    error "Destino no disponible. No se hace el backup."
    exit 3
fi

# ¿Se puede escribir en el destino? (-w = "writable")
if [ ! -w "$DESTINO" ]; then
    error "No hay permiso de escritura en '$DESTINO'."
    exit 3
fi

# -----------------------------------------------------------------------------
# Armamos el nombre del archivo (consigna 5.2).
# "basename /var/log" devuelve "log"; "basename /www_dir" devuelve "www_dir".
# Si el origen es "/", basename devuelve "/", que no sirve como nombre de
# archivo: en ese caso lo llamamos "raiz".
# -----------------------------------------------------------------------------
NOMBRE=$(basename "$ORIGEN")
[ "$NOMBRE" = "/" ] && NOMBRE="raiz"

ARCHIVO="${DESTINO}/${NOMBRE}_bkp_${FECHA}.tar.gz"

# -----------------------------------------------------------------------------
# Hacemos el backup con tar.
#   -c  crear un archivo nuevo
#   -z  comprimirlo con gzip (por eso termina en .tar.gz)
#   -p  conservar los permisos de los archivos
#   -f  el nombre del archivo a crear viene a continuación ($ARCHIVO)
#   -C  "cambiate a este directorio antes de empaquetar"
#
# Por qué el -C: si hiciéramos "tar -czpf x.tar.gz /var/log", tar guarda las
# rutas absolutas y avisa "Removing leading '/'". Con
# "-C /var log" entra a /var y empaqueta "log": el backup queda con rutas
# relativas y se restaura sin pisar nada por accidente.
#   dirname /var/log  → /var      (la carpeta "padre")
#   basename /var/log → log       (la carpeta a empaquetar)
# -----------------------------------------------------------------------------
PADRE=$(dirname "$ORIGEN")
CARPETA=$(basename "$ORIGEN")
[ "$ORIGEN" = "/" ] && CARPETA="."

log "Iniciando backup de '$ORIGEN' en '$ARCHIVO'..."

tar -czpf "$ARCHIVO" -C "$PADRE" "$CARPETA"
RESULTADO=$?    # "$?" = código de salida del último comando (el tar)

# -----------------------------------------------------------------------------
# Interpretamos el resultado de tar:
#   0 = todo bien.
#   1 = "algunos archivos cambiaron mientras se leían". Pasa seguido con
#       /var/log, porque el sistema sigue escribiendo logs durante el backup.
#       El backup se generó igual, así que lo tomamos como advertencia.
#   2 o más = error grave (sin espacio, sin permisos, etc.).
# "-eq" = igual, "-ge" = mayor o igual.
# -----------------------------------------------------------------------------
if [ "$RESULTADO" -eq 0 ] || [ "$RESULTADO" -eq 1 ]; then
    [ "$RESULTADO" -eq 1 ] && log "Aviso: algunos archivos cambiaron durante la copia (normal en /var/log)."
    # "du -h" muestra el tamaño del archivo en formato legible (K, M, G);
    # "cut -f1" se queda solo con la primera columna (el tamaño).
    log "Backup OK: $ARCHIVO ($(du -h "$ARCHIVO" | cut -f1))"
    exit 0
else
    error "tar terminó con código $RESULTADO. El backup NO se completó."
    rm -f "$ARCHIVO"   # borramos el archivo a medio hacer para no confundir
    exit 4
fi
