# 6) Entregables: repositorio en GitHub

> **Consigna 6:** repositorio en GitHub con README (nombres del grupo) y los directorios `/root`, `/etc`, `/opt`, `/www_dir` y `/backup_dir` comprimidos por separado en `.tar.gz`, más `/var` cortado en partes.

---

## 6.1 Generar los archivos (en la VM)

Hacerlo **al final**, cuando todo lo demás funciona: los `.tar.gz` son una "foto" de cómo quedó la VM.

```bash
bash verificar_tp.sh                  # primero: chequear que estén todos los puntos en OK
bash empaquetar_entregables.sh        # genera todo en /home/entregables
ls -lh /home/entregables
```

El script ([`scripts/empaquetar_entregables.sh`](../scripts/empaquetar_entregables.sh), comentado) hace:

| Archivo | Cómo se genera |
|---|---|
| `root.tar.gz`, `etc.tar.gz`, `opt.tar.gz`, `www_dir.tar.gz`, `backup_dir.tar.gz` | `tar -czpf <nombre>.tar.gz -C / <carpeta>`, una por carpeta |
| `var.tar.gz.part-00`, `-01`, ... | `tar -czpf - -C / var \| split -b 45M -d -a 2 -`: comprime y corta en el mismo paso |
| `SHA256SUMS.txt` | Huella de cada archivo, para comprobar que llegaron enteros |

**¿Por qué cortar `/var`?** Es la carpeta más pesada (logs, bases de datos de MariaDB, cachés) y **GitHub rechaza archivos de más de 100 MB**. Con `split` queda en pedazos de 45 MB que se suben sin problema. Para volver a armarlo: `cat var.tar.gz.part-* > var.tar.gz`.

## 6.2 Pasar los archivos a la PC

Usamos el SSH que configuramos en la consigna 2.2. **scp** = copiar archivos por SSH.

```bash
# En la PC (PowerShell / terminal), dentro de la carpeta del repositorio:
scp -i id_rsa_tp root@192.168.0.150:/home/entregables/* ./entregables/
#   -i id_rsa_tp     → la clave privada (igual que con ssh)
#   root@IP:ruta     → de dónde copiar (la VM)
#   ./entregables/   → a dónde (la carpeta del repo)
```

## 6.3 Subirlos al repositorio

```bash
git add entregables/
git commit -m "Entregables: directorios de la VM comprimidos y /var en partes"
git push
```

> **Repositorio privado, recomendado.** `etc.tar.gz` incluye `/etc/shadow` (los hashes de las contraseñas) y `root.tar.gz` incluye la clave privada SSH. Es una VM de práctica, pero conviene crear el repo como **Private** y agregar al profesor como colaborador (*Settings → Collaborators*). Si la cátedra pide que sea público, dejarlo público.

## 6.4 README con los integrantes

Completar la tabla de integrantes del [README](../README.md) con nombre, apellido y usuario de GitHub de cada uno.

## Checklist final

- [ ] `verificar_tp.sh` da todos los puntos en OK
- [ ] SSH y la web probados **desde la PC física**
- [ ] README con los 5 integrantes
- [ ] Los 5 `.tar.gz` + las partes de `/var` + `SHA256SUMS.txt` subidos
- [ ] Capturas pegadas en `informe/capturas/` e informe exportado a PDF
