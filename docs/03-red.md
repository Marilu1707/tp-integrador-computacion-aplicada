# 3) Configuración de red: IP estática

> **Consigna 3:** IP estática del mismo rango que la máquina física, con los campos ADDRESS, NETMASK y GATEWAY en el archivo de configuración.
> **Escenario Palermo Cloud:** un servidor tiene que tener siempre la misma dirección; si cambiara, los clientes no lo encontrarían.

---

## Por qué IP estática

Con DHCP, el router le asigna a la VM **cualquier IP libre**, y puede cambiar en cada arranque. Para un servidor eso no sirve: la web, el SSH y cualquier cliente tienen que saber **siempre** dónde encontrarlo.

## Paso 1: averiguar los datos de la red (en la PC física)

En Windows, abrir CMD y ejecutar `ipconfig`. Anotar del adaptador que tiene Internet:

| Dato en Windows | Ejemplo | Para qué lo usamos |
|---|---|---|
| Dirección IPv4 | 192.168.0.23 | Saber el rango: la VM tiene que ser 192.168.0.**algo** |
| Máscara de subred | 255.255.255.0 | → `netmask` |
| Puerta de enlace predeterminada | 192.168.0.1 | → `gateway` |

Elegir para la VM una IP **libre** del mismo rango, por ejemplo `192.168.0.150`. Para comprobar que nadie la usa: `ping 192.168.0.150` desde la PC. Si **no** responde, está libre.

> **Importante:** La VM tiene que estar en **Adaptador puente** (ver [doc 1](01-configuracion-entorno.md)). Con NAT nunca va a estar en el rango de la PC.

## Paso 2: ver el nombre de la interfaz (en la VM)

```bash
ip a        # lista las interfaces de red. Buscar la que NO es "lo" (suele ser enp0s3)
```

## Paso 3: editar el archivo de configuración

```bash
cp /etc/network/interfaces /etc/network/interfaces.bak   # copia de seguridad
nano /etc/network/interfaces
```

Debe quedar como [`config/etc/network/interfaces`](../config/etc/network/interfaces) (explicado línea por línea), con **los datos de su red**:

```
allow-hotplug enp0s3
iface enp0s3 inet static        # static = IP fija (antes decía dhcp)
    address 192.168.0.150       # ADDRESS: la IP de la VM
    netmask 255.255.255.0       # NETMASK: la máscara de la red
    gateway 192.168.0.1         # GATEWAY: el router de la casa
```

## Paso 4: DNS (para que siga funcionando Internet por nombre)

Al dejar de usar DHCP, la VM puede quedarse sin servidor DNS, y entonces `apt update` falla con *"Temporary failure resolving deb.debian.org"*.

```bash
nano /etc/resolv.conf
```

```
nameserver 192.168.0.1      # el router (suele hacer de DNS)
nameserver 8.8.8.8          # DNS público de Google, de respaldo
```

## Paso 5: aplicar y verificar

```bash
systemctl restart networking     # vuelve a leer /etc/network/interfaces
ip a                             # la interfaz tiene que mostrar 192.168.0.150
ip route                         # "default via 192.168.0.1" = el gateway quedó bien
ping -c 3 192.168.0.1            # llega al router (red local)
ping -c 3 8.8.8.8                # llega a Internet (por el gateway)
ping -c 3 deb.debian.org         # resuelve nombres (DNS)
```

Y desde la PC física: `ping 192.168.0.150` tiene que responder.

> **Nota:** Si `restart networking` no toma el cambio, reiniciar la VM (`reboot`) o hacer `ifdown enp0s3 && ifup enp0s3`.
> **Importante:** Si estamos conectados por SSH al cambiar la IP, la sesión se corta: hay que reconectar a la IP nueva.

---

**Capturas para el informe:** `cat /etc/network/interfaces` · `ip a` con la IP nueva · `ping` desde la PC a la VM.
