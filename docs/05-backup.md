# 5) Backup automático: `backup_full.sh` + cron

> **Consigna 5:** script `backup_full.sh` en `/opt/scripts`, con fecha AAAAMMDD en el nombre, que guarde en `/backup_dir`, acepte origen y destino, tenga `-help`, valide los sistemas de archivos y corra solo con cron.
> **Escenario Palermo Cloud:** si el cliente borra algo o se cae la web, podemos restaurar la copia del día.

---

## 5.1 Instalar el script

El script completo, comentado línea por línea, está en [`scripts/backup_full.sh`](../scripts/backup_full.sh).

```bash
mkdir -p /opt/scripts                          # carpeta pedida por la consigna
nano /opt/scripts/backup_full.sh               # pegar el contenido del script del repo
chmod 750 /opt/scripts/backup_full.sh          # 7 = dueño (root) rwx · 5 = grupo r-x · 0 = otros nada
```

> 💡 **¿Por qué 750 y no 777?** El script corre como root y comprime carpetas del sistema. Si cualquiera pudiera modificarlo (777), podría meterle comandos que root ejecutaría a medianoche.

## Cómo cumple cada punto de la consigna

| Consigna | Cómo lo resuelve el script |
|---|---|
| 5.2 Nombre con fecha AAAAMMDD | `FECHA=$(date +%Y%m%d)` y el nombre se arma como `<carpeta>_bkp_<FECHA>.tar.gz`. `/var/log` → `log_bkp_20241102.tar.gz` |
| 5.3 Guardar en `/backup_dir` | Es el DESTINO que le pasamos (desde cron, siempre `/backup_dir`) |
| 5.4 Argumentos origen y destino | `$1` = origen, `$2` = destino. Si no son exactamente 2, avisa y sale con error |
| 5.5 Opción `-help` | `-help` (también `-h` y `--help`) muestra cómo usarlo |
| 5.6 Validar los sistemas de archivos | Función `fs_disponible`: que la carpeta exista, que `df` pueda leer su FS y, si está en `/etc/fstab`, que esté **montada** (`mountpoint -q`) |
| 5.7 Calendario de tareas | Las líneas de cron de 5.3 de esta guía |

> 💡 **La validación más importante:** si la partición de `/backup_dir` no se montó, la carpeta `/backup_dir` existe igual (vacía, sobre el disco del sistema). Sin la validación, el backup se guardaría en el disco equivocado sin que nadie se entere. El script lo detecta con `mountpoint` y no hace la copia.

## 5.2 Probarlo a mano

```bash
/opt/scripts/backup_full.sh -help                  # muestra la ayuda
/opt/scripts/backup_full.sh                        # sin argumentos → error y código 1
/opt/scripts/backup_full.sh /no/existe /backup_dir # origen inválido → error y código 2
/opt/scripts/backup_full.sh /var/log /backup_dir   # backup real
/opt/scripts/backup_full.sh /www_dir /backup_dir   # backup real
echo $?                                            # código de salida del último comando: 0 = OK
ls -lh /backup_dir                                 # log_bkp_AAAAMMDD.tar.gz y www_dir_bkp_AAAAMMDD.tar.gz
tar -tzf /backup_dir/www_dir_bkp_$(date +%Y%m%d).tar.gz   # -t = listar el contenido sin extraer
```

**Prueba de la validación:** desmontar el destino y ver que se niega a copiar.

```bash
umount /backup_dir
/opt/scripts/backup_full.sh /www_dir /backup_dir   # → "figura en /etc/fstab pero NO está montado" (código 3)
mount -a                                           # volver a montarlo
```

### Códigos de salida

| Código | Significado |
|---|---|
| 0 | Backup OK |
| 1 | Error de uso (faltan o sobran argumentos) |
| 2 | Origen no disponible |
| 3 | Destino no disponible o sin permiso de escritura |
| 4 | Falló `tar` (por ejemplo, disco lleno) |

> 💡 Con `/var/log` a veces aparece *"Aviso: algunos archivos cambiaron durante la copia"*. Es normal: el sistema sigue escribiendo logs mientras se comprimen. `tar` igual genera el backup (devuelve 1, que el script toma como advertencia y no como error).

## 5.3 Programarlo con cron

**cron** es el servicio que ejecuta tareas en horarios fijos. Cada usuario tiene su tabla de tareas (*crontab*).

```bash
crontab -e      # editar el crontab de root (la primera vez pregunta qué editor usar: elegir nano)
```

Pegar al final (archivo explicado: [`config/crontab-root.txt`](../config/crontab-root.txt)):

```
0 0 * * *       /opt/scripts/backup_full.sh /var/log /backup_dir >> /var/log/backup_full.log 2>&1
0 23 * * 1,3,5  /opt/scripts/backup_full.sh /www_dir /backup_dir >> /var/log/backup_full.log 2>&1
```

| Línea | Minuto | Hora | Día | Mes | Día de semana | Significa |
|---|---|---|---|---|---|---|
| 1 | 0 | 0 | * | * | * | Todos los días a las 00:00 |
| 2 | 0 | 23 | * | * | 1,3,5 | Lunes, miércoles y viernes a las 23:00 |

> ⚠️ La consigna dice `/var/logs`, pero en Debian la carpeta es **`/var/log`** (sin "s"). El propio ejemplo de la consigna (`log_bkp_...`) lo confirma.

```bash
crontab -l                  # muestra las tareas cargadas
systemctl status cron       # el servicio cron tiene que estar "active (running)"
```

**Para probar cron sin esperar a la medianoche:** agregar temporalmente una línea que corra en un par de minutos (por ejemplo `*/2 * * * *` = cada 2 minutos), revisar `/var/log/backup_full.log` y `/backup_dir`, y después **borrarla**.

## Restaurar un backup

```bash
tar -xzpf /backup_dir/www_dir_bkp_20241102.tar.gz -C /tmp/restaurado
#   -x = extraer · -C = en esta carpeta (para no pisar lo actual)
```

---

📸 **Capturas para el informe:** `-help` · un backup exitoso · `ls -lh /backup_dir` · la validación fallando con `/backup_dir` desmontado · `crontab -l`.
