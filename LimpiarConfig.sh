#!/bin/bash

# ##############################################################################
# Script de Limpieza y Configuración Inicial para VPS Debian/Ubuntu (v2.0)
#
# VERSIÓN TOTALMENTE AUTOMÁTICA - SIN CONFIRMACIÓN
#
# Propósito:
#   - Se ejecuta de principio a fin sin intervención del usuario.
#   - Crea un nuevo usuario administrativo con contraseña preestablecida.
#   - Elimina UFW, limpia iptables y instala un escritorio XFCE con XRDP.
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

# --- Comienza la ejecución del script ---

echo "[ PASO 1/8 ] Actualizando la lista de paquetes..."
apt-get update -y

echo "[ PASO 2/8 ] Instalando paquetes básicos (sudo, si no existe)..."
# Usamos apt-get para máxima compatibilidad
apt-get install -y sudo

echo "[ PASO 3/8 ] Creando y configurando el nuevo usuario administrativo..."
if id "$NUEVO_USUARIO" &>/dev/null; then
    echo "El usuario '$NUEVO_USUARIO' ya existe. Omitiendo creación."
else
    adduser --disabled-password --gecos "" "$NUEVO_USUARIO"
    echo "Usuario '$NUEVO_USUARIO' creado."
fi
echo "$NUEVO_USUARIO:$NUEVA_CONTRASENA" | chpasswd
echo "Contraseña establecida para '$NUEVO_USUARIO'."
usermod -aG sudo,ssl-cert "$NUEVO_USUARIO"
echo "Permisos de administrador concedidos a '$NUEVO_USUARIO'."

echo "[ PASO 4/8 ] Purgando UFW y sus dependencias..."
apt-get purge --autoremove -y *ufw*

echo "[ PASO 5/8 ] Instalando iptables y la herramienta de persistencia..."
# Pre-configuramos las respuestas para evitar que iptables-persistent pregunte
echo "iptables-persistent iptables-persistent/autosave_v4 boolean true" | debconf-set-selections
echo "iptables-persistent iptables-persistent/autosave_v6 boolean true" | debconf-set-selections
apt-get install -y iptables iptables-persistent

echo "[ PASO 6/8 ] Limpiando las reglas actuales de iptables..."
iptables -F
iptables -X
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT
echo "Firewall limpiado. Todas las conexiones están permitidas."

echo "[ PASO 7/8 ] Instalando XFCE4, SDDM y XRDP..."
apt-get install -y xfce4 xfce4-goodies sddm dbus-x11 xrdp

adduser xrdp ssl-cert
if [ -f /etc/xrdp/startwm.sh ]; then
    # Creamos una copia de seguridad y modificamos el archivo de inicio de xrdp
    cp /etc/xrdp/startwm.sh /etc/xrdp/startwm.sh.bak
    # Eliminamos las líneas de inicio por defecto
    sed -i '/^test -x/d' /etc/xrdp/startwm.sh
    sed -i '/^exec \/bin\/sh/d' /etc/xrdp/startwm.sh
    # Añadimos la línea para iniciar XFCE y salimos
    echo "# Iniciar sesión XFCE" >> /etc/xrdp/startwm.sh
    echo "startxfce4" >> /etc/xrdp/startwm.sh
    echo "exit 0" >> /etc/xrdp/startwm.sh
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
