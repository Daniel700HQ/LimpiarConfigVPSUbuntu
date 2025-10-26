#!/bin/bash

# ##############################################################################
# Script de Limpieza y Configuración Inicial para VPS Debian/Ubuntu (v2.2)
#
# VERSIÓN TOTALMENTE AUTOMÁTICA
#
# Propósito:
#   - Se ejecuta de principio a fin sin intervención del usuario.
#   - Desactiva y elimina las actualizaciones automáticas (unattended-upgrades).
#   - Configura el entorno (firewall, escritorio, RDP).
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
NUEVA_CONTRASENA="d4r2,r.122+FFGZEEH55KV1Ee"
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

echo "[ PASO 1/9 ] Desactivando y eliminando las actualizaciones automáticas..."
# Detener los servicios por si están en ejecución, ignorando errores si no existen.
systemctl stop unattended-upgrades.service >/dev/null 2>&1 || true
systemctl disable unattended-upgrades.service >/dev/null 2>&1 || true

# Purgar el paquete para eliminarlo completamente del sistema.
# apt-get no falla si el paquete no está instalado, simplemente lo notifica.
apt-get purge --autoremove -y unattended-upgrades
echo "Unattended-upgrades eliminado."

echo "[ PASO 2/9 ] Actualizando la lista de paquetes..."
apt-get update -y

echo "[ PASO 3/9 ] Instalando paquetes básicos (sudo, si no existe)..."
apt-get install -y sudo

echo "[ PASO 4/9 ] Purgando UFW y sus dependencias..."
apt-get purge --autoremove -y *ufw*

echo "[ PASO 5/9 ] Instalando iptables y la herramienta de persistencia..."
echo "iptables-persistent iptables-persistent/autosave_v4 boolean true" | debconf-set-selections
echo "iptables-persistent iptables-persistent/autosave_v6 boolean true" | debconf-set-selections
apt-get install -y iptables iptables-persistent

echo "[ PASO 6/9 ] Limpiando las reglas actuales de iptables..."
iptables -F
iptables -X
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT
echo "Firewall limpiado. Todas las conexiones están permitidas."

echo "[ PASO 8/9 ] Guardando la configuración vacía de iptables para que persista..."
netfilter-persistent save
echo "Configuración de iptables guardada."

# --- Creación del usuario como paso final ---

echo "[ PASO 9/9 ] Creando y configurando el nuevo usuario administrativo..."
if id "$NUEVO_USUARIO" &>/dev/null; then
    echo "El usuario '$NUEVO_USUARIO' ya existe. Actualizando grupos y contraseña."
else
    adduser --disabled-password --gecos "" "$NUEVO_USUARIO"
    echo "Usuario '$NUEVO_USUARIO' creado."
fi

echo "$NUEVO_USUARIO:$NUEVA_CONTRASENA" | chpasswd
echo "Contraseña establecida para '$NUEVO_USUARIO'."

usermod -aG sudo "$NUEVO_USUARIO"
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
