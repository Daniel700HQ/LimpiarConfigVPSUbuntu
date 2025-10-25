#!/bin/bash

# ##############################################################################
# Script de Limpieza y Configuración Inicial para VPS Debian/Ubuntu (v1.1)
#
# Propósito:
#   - Actualiza el sistema.
#   - Crea un nuevo usuario administrativo con contraseña preestablecida.
#   - Elimina UFW (Uncomplicated Firewall).
#   - Instala y limpia las reglas de iptables.
#   - Instala un escritorio ligero (XFCE4) y un servidor RDP (XRDP).
#   - Guarda la configuración limpia de iptables para que persista.
#
# ADVERTENCIA:
#   - Este script reiniciará el servidor al finalizar.
#   - Dejará el firewall completamente abierto. ¡Debes configurarlo después!
#
# ##############################################################################

# --- CONFIGURACIÓN DEL NUEVO USUARIO ---
# ¡IMPORTANTE! Cambia estos valores por unos seguros y únicos.
NUEVO_USUARIO="admin_remoto"
NUEVA_CONTRASENA="P@$$w0rdS3gur0!"
# ------------------------------------

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
echo "  - Creará un nuevo usuario llamado '$NUEVO_USUARIO'."
echo "  - Purgará UFW y limpiará TODAS las reglas de iptables."
echo "  - Instalará XFCE4 y XRDP, exponiendo el puerto 3389."
echo "  - El servidor se REINICIARÁ al finalizar."
echo "------------------------------------------------------------------"
read -p "¿Estás seguro de que deseas continuar? (s/n): " response

# ** CORRECCIÓN APLICADA AQUÍ **
# Convertir la respuesta a minúsculas de forma compatible con todos los shells
response=$(echo "$response" | tr '[:upper:]' '[:lower:]')

if [[ "$response" != "s" ]]; then
  echo "Operación cancelada."
  exit 0
fi

# --- Comienza la ejecución del script ---

echo "[ PASO 1/8 ] Actualizando la lista de paquetes..."
apt update

echo "[ PASO 2/8 ] Instalando paquetes básicos (sudo, si no existe)..."
apt install -y sudo

echo "[ PASO 3/8 ] Creando y configurando el nuevo usuario administrativo..."
if id "$NUEVO_USUARIO" &>/dev/null; then
    echo "El usuario '$NUEVO_USUARIO' ya existe. Omitiendo creación."
else
    adduser --disabled-password --gecos "" "$NUEVO_USUARIO"
    echo "Usuario '$NUEVO_USUARIO' creado."
fi
echo "$NUEVO_USUARIO:$NUEVA_CONTRASENA" | chpasswd
echo "Contraseña establecida para '$NUEVO_USUARIO'."
echo "Añadiendo a '$NUEVO_USUARIO' a los grupos 'sudo' y 'ssl-cert'..."
usermod -aG sudo,ssl-cert "$NUEVO_USUARIO"
echo "Permisos de administrador concedidos."

echo "[ PASO 4/8 ] Purgando UFW y sus dependencias..."
apt purge --autoremove -y *ufw*

echo "[ PASO 5/8 ] Instalando iptables y la herramienta de persistencia..."
apt install -y iptables iptables-persistent

echo "[ PASO 6/8 ] Limpiando las reglas actuales de iptables..."
iptables -F
iptables -X
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT
echo "Firewall limpiado. Todas las conexiones están permitidas."

echo "[ PASO 7/8 ] Instalando XFCE4, SDDM y XRDP..."
apt install -y xfce4 xfce4-goodies sddm dbus-x11 xrdp

adduser xrdp ssl-cert
if [ -f /etc/xrdp/startwm.sh ]; then
    sed -i.bak '/^test -x/s/^/#/' /etc/xrdp/startwm.sh
    sed -i '/^exec \/bin\/sh/s/^/#/' /etc/xrdp/startwm.sh
    echo -e "\n# Iniciar sesión XFCE\nstartxfce4" >> /etc/xrdp/startwm.sh
fi
systemctl enable xrdp
echo "XRDP ha sido configurado y habilitado."

echo "[ PASO 8/8 ] Guardando la configuración vacía de iptables para que persista..."
netfilter-persistent save
echo "Configuración de iptables guardada."

# --- Finalización ---

echo "------------------------------------------------------------------"
echo "¡CONFIGURACIÓN COMPLETADA!"
echo ""
echo "Se ha creado el siguiente usuario:"
echo "  Usuario:    $NUEVO_USUARIO"
echo "  Contraseña: $NUEVA_CONTRASENA"
echo ""
echo "El sistema se reiniciará en 10 segundos."
echo "Después del reinicio, conéctate usando Escritorio Remoto con estas credenciales."
echo "¡Recuerda asegurar tu firewall (iptables) lo antes posible!"
echo "------------------------------------------------------------------"
sleep 10

reboot
