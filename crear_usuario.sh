#!/bin/bash

# Verificar que el script se ejecute como root (necesario para crear usuarios)
if [ "$EUID" -ne 0 ]; then
  echo "Por favor, ejecuta este script como root o usando sudo."
  exit 1
fi

# 1. Crear el usuario 'movies' con la shell por defecto (bash) y su directorio home
echo "Creando al usuario 'movies'..."
useradd -m -s /bin/bash movies

# 2. Configurar la contraseña '0394' para el usuario
echo "Configurando la contraseña..."
echo "movies:0394" | chpasswd

# 3. Asegurar que Flatpak esté configurado para este usuario de forma local
echo "Configurando entorno Flathub para el usuario..."
# Se crea el directorio de configuración de aplicaciones del usuario por si acaso
mkdir -p /home/movies/.local/share/flatpak

# Cambiar los propietarios del home al usuario correcto
chown -R movies:movies /home/movies

# 4. Agregar el repositorio de Flathub a nivel de usuario
# Ejecutamos el comando como si fuéramos el usuario 'movies'
su - movies -c "flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo"

echo "¡Listo! El usuario 'movies' ha sido creado con éxito."
echo "Nota: Para instalar aplicaciones, el usuario solo debe usar el parámetro '--user'. Ejemplo:"
echo "  flatpak install --user flathub com.valvesoftware.Steam"
