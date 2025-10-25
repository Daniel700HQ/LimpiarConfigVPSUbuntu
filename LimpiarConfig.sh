#!/bin/bash

# ##############################################################################
# Script de Limpieza y Configuración Inicial para VPS Debian/Ubuntu (v2.1)
#
# VERSIÓN TOTALMENTE AUTOMÁTICA - CREACIÓN DE USUARIO AL FINAL
#
# Propósito:
#   - Se ejecuta de principio a fin sin intervención del usuario.
#   - Configura todo el entorno de software (firewall, escritorio, RDP).
#   - Como paso final, crea un nuevo usuario administrativo.
#   - Reinicia el sistema al finalizar.
#
# ¡¡¡ADVERTENCIA MÁXIMA!!!
#   Este script comenzará a modificar el sistema 5 segundos después de ejecutarlo.
#   NO HAY PASO DE CONFIRMACIÓN. Úsalo bajo tu propia responsabilidad.
#   Para cancelar, presiona CTRL+C durante la cuenta atrás.
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
  echo "ERROR: Por favor, ejecuta este script como root o con sudo."
  exit 1
fi

# --- PAUSA DE SEGURIDAD ANTES DE EMPEZAR ---
echo "------------------------------------------------------------------"
echo "ATENCIÓN: El script comenzará la configuración automática en 5 segundos."
echo "Presiona CTRL+C para cancelar AHORA."
echo "------------------------------------------------------------------"
sleep 5

# --- Comienza la configuración del sistema ---

echo "[ PASO 1/8 ] Actualizando la lista de paquetes..."
apt-get update -y

echo "[ PASO 2/8 ] Instalando paquetes básicos (sudo, si no existe)..."
apt-get install -y sudo

echo "[ PASO 3/8 ] Purgando UFW y sus dependencias..."
apt-get purge --autoremove -y *ufw*

echo "[ PASO 4/8 ] Instalando iptables y la herramienta de persistencia..."
# Pre-configuramos las respuestas para evitar que iptables-persistent pregunte
echo "iptables-persistent iptables-persistent/autosave_v4 boolean true" | debconf-set-selections
echo "iptables-persistent iptables-persistent/autosave_v6 boolean true" | debconf-set-selections
apt-get install -y iptables iptables-persistent

echo "[ PASO 5/8 ] Limpiando las reglas actuales de iptables..."
iptables -F
iptables -X
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT
echo "Firewall limpiado. Todas las conexiones están permitidas."

echo "[ PASO 6/8 ] Instalando XFCE4, SDDM y XRDP..."
apt-get install -y xfce4 xfce4-goodies sddm dbus-x11 xrdp

# Configurar XRDP para usar la sesión de XFCE
adduser xrdp ssl-cert
if [ -f /etc/xrdp/startwm.sh ]; then
    cp /etc/xrdp/startwm.sh /etc/xrdp/startwm.sh.bak
    sed -i '/^test -x/d' /etc/xrdp/startwm.sh
    sed -i '/^exec \/bin\/sh/d' /etc/xrdp/startwm.sh
    echo -e "\n# Iniciar sesión XFCE\nstartxfce4" >> /etc/xrdp/startwm.sh
fi
systemctl enable xrdp
echo "XRDP ha sido configurado y habilitado."

echo "[ PASO 7/8 ] Guardando la configuración vacía de iptables para que persista..."
netfilter-persistent save
echo "Configuración de iptables guardada."

# --- Creación del usuario como paso final ---

echo "[ PASO 8/8 ] Creando y configurando el nuevo usuario administrativo..."
if id "$NUEVO_USUARIO" &>/dev/null; then
    echo "El usuario '$NUEVO_USUARIO' ya existe. Actualizando grupos y contraseña."
else
    # Crear el usuario sin pedir contraseña interactivamente
    adduser --disabled-password --gecos "" "$NUEVO_USUARIO"
    echo "Usuario '$NUEVO_USUARIO' creado."
fi

# Establecer la contraseña de forma no interactiva
echo "$NUEVO_USUARIO:$NUEVA_CONTRASENA" | chpasswd
echo "Contraseña establecida para '$NUEVO_USUARIO'."

# Añadir el usuario a los grupos 'sudo' (privilegios admin) y 'ssl-cert' (requerido por xrdp)
usermod -aG sudo,ssl-cert "$NUEVO_USUARIO"
echo "Permisos de administrador concedidos a '$NUEVO_USUARIO'."


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
