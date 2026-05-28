#!/usr/bin/env bash
#|---/ /+-----------------------------------------------+---/ /|#
#|--/ /-| Script to enable early loading for nvidia drm |--/ /-|#
#|-/ /--| Prasanth Rangan                               |-/ /--|#
#|/ /---+-----------------------------------------------+/ /---|#

# Verifica si hay una tarjeta gráfica NVIDIA instalada en el sistema listando los dispositivos PCI
if [ $(lspci -k | grep -A 2 -E "(VGA|3D)" | grep -i nvidia | wc -l) -gt 0 ]; then
    # Verifica si los módulos de NVIDIA ya están configurados para cargarse temprano en mkinitcpio.conf
    if [ $(grep 'MODULES=' /etc/mkinitcpio.conf | grep nvidia | wc -l) -eq 0 ]; then
        # Añade los módulos de NVIDIA a la variable MODULES para habilitar la carga temprana (Early KMS)
        sudo sed -i "/MODULES=/ s/)$/ nvidia nvidia_modeset nvidia_uvm nvidia_drm)/" /etc/mkinitcpio.conf
        # Regenera las imágenes de inicio (initramfs) para aplicar los cambios de mkinitcpio
        sudo mkinitcpio -P
        
        # Verifica si el parámetro modeset=1 para nvidia-drm ya está configurado
        if [ $(grep 'options nvidia-drm modeset=1' /etc/modprobe.d/nvidia.conf | wc -l) -eq 0 ]; then
            # Habilita DRM (Direct Rendering Manager) modeset, fundamental para usar Wayland con NVIDIA
            echo 'options nvidia-drm modeset=1' | sudo tee -a /etc/modprobe.d/nvidia.conf
        fi
    fi
fi

sudo touch /usr/share/pixmaps/archcraft-logo.png


# Verifica si hay una tarjeta gráfica Intel instalada en el sistema listando los dispositivos PCI
if [ $(lspci -k | grep -A 2 -E "(VGA|3D)" | grep -i intel | wc -l) -gt 0 ]; then
    # Verifica si el módulo de Intel (i915) ya está configurado para cargarse temprano
    if [ $(grep 'MODULES=' /etc/mkinitcpio.conf | grep i915 | wc -l) -eq 0 ]; then
        # Añade el módulo i915 a la variable MODULES para Early KMS
        sudo sed -i "/MODULES=/ s/)$/ i915)/" /etc/mkinitcpio.conf
        # Regenera las imágenes de inicio (initramfs)
        sudo mkinitcpio -P
        
        # (Opcional) Activar mejoras de rendimiento y ahorro de energía para Intel
        if [ ! -f /etc/modprobe.d/i915.conf ] || [ $(grep 'enable_fbc=1' /etc/modprobe.d/i915.conf | wc -l) -eq 0 ]; then
            # enable_fbc=1 activa la compresión de framebuffer (ahorra batería)
            # enable_guc=3 activa el firmware GuC/HuC para mejor codificación de video
            echo 'options i915 enable_fbc=1 enable_guc=3' | sudo tee -a /etc/modprobe.d/i915.conf
        fi
    fi
fi
