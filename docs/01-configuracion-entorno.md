# 1) Configuración del entorno

> **Consigna 1:** importar la VM, blanquear la clave de root y cambiarla por `palermo`, y poner el hostname `TPServer`.
> **Escenario Palermo Cloud:** recibimos el servidor del cliente sin la clave de administrador y tenemos que recuperar el acceso.

---

## 1.1 Armar e importar la máquina virtual

La VM viene partida en varios `.rar` (`.part1.rar`, `.part2.rar`, ...). Son **un solo archivo cortado en pedazos**.

1. Bajar **todas** las partes de Blackboard a la misma carpeta.
2. Clic derecho sobre la **primera** parte (`...part1.rar`) → *Extraer aquí* con WinRAR. WinRAR busca solo las demás partes y arma el archivo completo (normalmente un `.ova`).
3. En VirtualBox: **Archivo → Importar servicio virtualizado** → elegir el `.ova` → *Importar*.

> **Nota:** Si falta una parte o una está corrupta, WinRAR avisa con error de CRC. Hay que volver a bajar esa parte.

### Antes de prender la VM: poner la red en "Adaptador puente"

En VirtualBox: **Configuración → Red → Adaptador 1 → Conectado a: Adaptador puente** → elegir la placa de red de la PC (wifi o cable).

**Por qué:** con *Adaptador puente* la VM queda en la **misma red que la PC física**, como si fuera otra computadora de la casa. Lo necesitamos para la consigna 3 (IP del mismo rango) y para probar SSH y la web desde la PC. Con *NAT* (lo que viene por defecto) la VM queda "escondida" detrás de VirtualBox y la PC no la ve.

---

## 1.2 Blanquear la clave de root desde GRUB

No sabemos la clave de root. GRUB (el gestor de arranque) nos deja cambiar cómo arranca Linux y entrar directo a una consola de root **sin pedir contraseña**.

1. Prender la VM. Cuando aparece el menú azul de **GRUB**, antes de que termine la cuenta regresiva, presionar **`e`** (editar).
2. Buscar la línea que empieza con `linux` y termina en `ro quiet`. Por ejemplo:
   ```
   linux /boot/vmlinuz-5.10.0-xx-amd64 root=UUID=... ro quiet
   ```
3. Borrar `ro quiet` y escribir en su lugar:
   ```
   rw init=/bin/bash
   ```
   - `rw` → monta el disco en **lectura-escritura** (con `ro` = read only no podríamos guardar la clave nueva).
   - `init=/bin/bash` → en lugar de arrancar el sistema normal, arranca **directamente una consola bash como root**.
4. Presionar **F10** (o `Ctrl+X`) para arrancar con ese cambio. **No se guarda**: es solo para este arranque.
5. Aparece un prompt `root@(none):/#`. Cambiar la clave:
   ```bash
   passwd                  # pide la clave nueva dos veces: escribir  palermo
   ```
   > La consigna dice: primero blanquear y después cambiarla por `palermo`. Como ya estamos acá, la ponemos directamente en `palermo`.
6. Arrancar el sistema normal:
   ```bash
   exec /sbin/init         # reemplaza el bash por el arranque normal de Debian
   ```

> **Importante:** Si `passwd` da *"Authentication token manipulation error"*, el disco quedó en solo lectura. Ejecutar `mount -o remount,rw /` y repetir `passwd`.

### Verificar

Entrar con usuario `root` y clave `palermo`. Si entra, la clave quedó bien.

---

## 1.3 Cambiar el hostname a `TPServer`

El **hostname** es el nombre de la máquina en la red (el que aparece en el prompt: `root@TPServer`).

```bash
hostnamectl set-hostname TPServer   # cambia el nombre y lo guarda en /etc/hostname
nano /etc/hosts                     # editar el archivo de nombres locales
```

En `/etc/hosts`, cambiar el nombre viejo en la línea `127.0.1.1`:

```
127.0.0.1   localhost
127.0.1.1   TPServer      # ← antes decía el nombre anterior de la máquina
```

**Por qué tocar `/etc/hosts`:** si el nombre nuevo no figura ahí, comandos como `sudo` tardan o avisan *"unable to resolve host TPServer"*, porque la máquina no sabe cuál es su propia dirección.

### Verificar

```bash
hostname            # tiene que mostrar: TPServer
cat /etc/hostname   # también TPServer
```

El prompt cambia a `root@TPServer` al volver a iniciar sesión (`exit` y entrar de nuevo).

---

**Capturas para el informe:** la línea editada en GRUB · el `passwd` exitoso · el resultado de `hostname`.
