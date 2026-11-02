#!/bin/bash
# =============================================================================
#  empaquetar_entregables.sh — Arma los archivos para subir a GitHub (consigna 6.2)
# =============================================================================
#  Qué genera:
#    - root.tar.gz, etc.tar.gz, opt.tar.gz, www_dir.tar.gz, backup_dir.tar.gz
#      (cada carpeta comprimida por separado, como pide la consigna)
#    - var.tar.gz.part-00, var.tar.gz.part-01, ...
#      (/var comprimido y cortado en partes chicas para poder subirlo)
#    - SHA256SUMS.txt (huella de cada archivo, para comprobar que no se dañaron)
#
#  Uso (como root, dentro de la VM):
#    bash empaquetar_entregables.sh              → deja todo en /home/entregables
#    bash empaquetar_entregables.sh /otra/ruta   → deja todo en esa carpeta
#
#  Por qué /home/entregables:
#    La carpeta de salida NO puede estar dentro de lo que comprimimos. Si
#    guardáramos root.tar.gz dentro de /root, tar intentaría comprimir el
#    archivo que está escribiendo. /home no está en la lista de la consigna.
# =============================================================================

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# "${1:-/home/entregables}" = usar el primer argumento; si no hay, el valor por defecto.
SALIDA="${1:-/home/entregables}"

# Tamaño de cada parte de /var. GitHub rechaza archivos de más de 100 MB;
# con 45 MB quedamos holgados y se suben sin problema con git.
TAMANO_PARTE="45M"

if [ "$(id -u)" -ne 0 ]; then
    echo "Ejecutar como root (hay archivos de /etc y /root que solo root puede leer)."
    exit 1
fi

mkdir -p "$SALIDA"
echo "Guardando entregables en: $SALIDA"

# -----------------------------------------------------------------------------
# Antes de comprimir /var: vaciar la caché de paquetes .deb que bajó apt.
# Son instaladores ya usados (pueden ocupar cientos de MB) y se pueden volver
# a descargar. No borra nada instalado.
# -----------------------------------------------------------------------------
apt-get clean

# -----------------------------------------------------------------------------
# Comprimir cada directorio por separado.
#   tar -czpf  → c crear · z gzip · p conservar permisos · f nombre del archivo
#   -C /       → entrar a la raíz y empaquetar "root", "etc"... (rutas relativas)
#   --warning=no-file-ignored → no mostrar avisos por sockets (archivos
#     especiales que tar no puede guardar y saltea solo)
#   El código 1 de tar ("un archivo cambió mientras se leía") no es grave.
# -----------------------------------------------------------------------------
for DIR in root etc opt www_dir backup_dir; do
    if [ ! -d "/$DIR" ]; then
        echo "  [AVISO] /$DIR no existe: se saltea (¿falta hacer la consigna 4?)"
        continue
    fi
    echo "  Comprimiendo /$DIR ..."
    tar -czpf "$SALIDA/$DIR.tar.gz" --warning=no-file-ignored -C / "$DIR"
    CODIGO=$?
    if [ "$CODIGO" -gt 1 ]; then
        echo "  [ERROR] Falló la compresión de /$DIR (código $CODIGO)"
    fi
done

# -----------------------------------------------------------------------------
# /var: comprimir y CORTAR en partes (consigna 6.2: "splitear").
#   "tar ... -" escribe el .tar.gz en la salida estándar en vez de un archivo.
#   "|" (pipe) se lo pasa directo a split, sin crear un archivo gigante en el medio.
#   split -b 45M  → cortar cada 45 MB
#         -d      → sufijos numéricos (00, 01, 02...) en vez de letras (aa, ab...)
#         -a 2    → dos dígitos en el sufijo
#         -       → leer lo que llega por el pipe
#   Excluimos /var/tmp (temporales) para no subir basura.
# -----------------------------------------------------------------------------
echo "  Comprimiendo y cortando /var en partes de $TAMANO_PARTE ..."
rm -f "$SALIDA"/var.tar.gz.part-*          # borrar partes viejas si se corre dos veces
tar -czpf - --warning=no-file-ignored --exclude='var/tmp/*' -C / var \
    | split -b "$TAMANO_PARTE" -d -a 2 - "$SALIDA/var.tar.gz.part-"

# -----------------------------------------------------------------------------
# Huellas SHA-256: un "código" único por archivo. Si alguien baja los archivos
# y el código coincide, el archivo llegó entero.
# Verificar después con:  sha256sum -c SHA256SUMS.txt
# -----------------------------------------------------------------------------
cd "$SALIDA" || exit 1
sha256sum ./*.tar.gz var.tar.gz.part-* > SHA256SUMS.txt 2>/dev/null

echo
echo "Listo. Contenido de $SALIDA:"
ls -lh "$SALIDA"
echo
echo "Para volver a unir /var:   cat var.tar.gz.part-* > var.tar.gz"
echo "Para pasarlos a la PC:     scp -i id_rsa_tp root@IP-DE-LA-VM:$SALIDA/* ."
