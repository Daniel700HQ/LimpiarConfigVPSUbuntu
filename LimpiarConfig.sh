#!/bin/bash

# ##############################################################################
# Script de Limpieza y Configuración Inicial para VPS Debian/Ubuntu
#
# Propósito:
#   - Actualiza el sistema.
#   - Elimina UFW (Uncomplicated Firewall).
#   - Instala y limpia las reglas de iptables, dejándolo abierto por defecto.
#   - Instala un entorno de escritorio ligero (XFCE4) con SDDM.
#   - Instala y configura XRDP para permitir el acceso por Escritorio Remoto.
#   - Guarda la configuración limpia de iptables para que persista tras el reinicio.
#
# ADVERTENCIA:
#   - Este script reiniciará el servidor al finalizar.
#   - Dejará el firewall completamente abierto. El puerto de Escritorio Remoto (3389)
#     estará expuesto a Internet. Es CRÍTICO configurar el firewall después.
#   - Ejecútalo solo en una instalación nueva o si estás seguro de tus acciones.
#
# ##############################################################################

# Detener el script si algún comando falla
set -e

# 1. Verificar que el script se ejecuta como root
if [ "$EUID" -ne 0 ]; then
  echo "Por favor, ejecuta este script como root o con sudo."
  exit 1
fi

# 2. Confirmación del usuario antes de proceder
echo "------------------------------------------------------------------"
echo "ADVERTENCIA: Este script realizará cambios significativos en el sistema:"
echo "  - Purgará cualquier configuración de UFW."
echo "  - Limpiará TODAS las reglas de iptables, dejando el servidor expuesto."
echo "  - Instalará un entorno de escritorio (XFCE4) y un servidor RDP (XRDP)."
echo "  - El servidor se REINICIARÁ al finalizar."
echo "------------------------------------------------------------------"
read -p "¿Estás seguro de que deseas continuar? (s/n): " response

# Convertir la respuesta a minúsculas
response=${response,,}

if [[ "$response" != "s" ]]; then
  echo "Operación cancelada."
  exit 0
fi

# --- Comienza la ejecución del script ---

echo "[ PASO 1/7 ] Actualizando la lista de paquetes..."
apt update

echo "[ PASO 2/7 ] Purgando UFW y sus dependencias..."
apt purge --autoremove -y *ufw*

echo "[ PASO 3/7 ] Instalando iptables y la herramienta de persistencia..."
apt install -y iptables iptables-persistent

echo "[ PASO 4/7 ] Limpiando las reglas actuales de iptables..."
iptables -F
iptables -X
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT
echo "Firewall limpiado. Todas las conexiones están permitidas temporalmente."

echo "[ PASO 5/7 ] Instalando XFCE4, SDDM y XRDP..."
# Se añade xrdp a la lista de instalación
apt install -y xfce4 xfce4-goodies sddm dbus-x11 xrdp

echo "[ PASO 6/7 ] Configurando XRDP para usar la sesión de XFCE..."
# 1. Añadir el usuario xrdp al grupo ssl-cert para que pueda leer los certificados.
#    Esto es necesario en muchas distribuciones para que la pantalla de login funcione.
adduser xrdp ssl-cert

# 2. Indicar a XRDP que inicie una sesión de XFCE para los usuarios que se conecten.
#    Creamos (o sobrescribimos) el archivo .xsession en el directorio de configuración
#    por defecto para que se aplique a todos los nuevos usuarios.
#    Una forma más directa es configurar el startwm.sh de xrdp.
echo "xfce4-session" > /etc/skel/.xsession

# Como alternativa, modificamos directamente el script de inicio de xrdp.
# Esta opción es más robusta si ya existen usuarios en el sistema.
# Comentamos las últimas dos líneas del script original y añadimos el inicio de XFCE.
if [ -f /etc/xrdp/startwm.sh ]; then
    sed -i.bak '/^test -x/s/^/#/' /etc/xrdp/startwm.sh
    sed -i '/^exec \/bin\/sh/s/^/#/' /etc/xrdp/startwm.sh
    echo -e "\n# Iniciar sesión XFCE\nstartxfce4" >> /etc/xrdp/startwm.sh
fi

# 3. Habilitar el servicio xrdp para que se inicie automáticamente en cada arranque.
systemctl enable xrdp
echo "XRDP ha sido configurado y habilitado."

echo "[ PASO 7/7 ] Guardando la configuración vacía de iptables para que persista..."
netfilter-persistent save
echo "Configuración de iptables guardada."

# --- Finalización ---

echo "------------------------------------------------------------------"
echo "¡Limpieza y configuración completadas!"
echo "El sistema se reiniciará en 5 segundos..."
echo "Después del reinicio, podrás conectarte usando un cliente de Escritorio Remoto (RDP)."
echo "¡IMPORTANTE! El puerto 3389 está abierto. Configura iptables para restringir el acceso."
echo "------------------------------------------------------------------"
sleep 5

reboot
