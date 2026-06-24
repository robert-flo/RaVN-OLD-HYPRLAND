#!/usr/bin/env sh
# Chromium/Chrome Wayland and GPU session environment variables

# General variables
export LIBVA_MESSAGING_LEVEL="1"
export LIBGL_ALWAYS_SOFTWARE="0"
export ENABLE_VAAPI="1"
export VAAPI_DISABLE_ENCODER_CHECKING="1"
export EGL_PLATFORM="wayland"

# GPU-specific variables
if [ "$GPU_SETUP" = "amd-only" ] || [ "$GPU_SETUP" = "hybrid-amd-intel" ]; then
  export LIBVA_DRIVER_NAME="radeonsi"
  export ENABLE_VDPAU="1"
  export RADV_PERFTEST="sam"
  export AMD_VULKAN_ICD="RADV"
elif [ "$GPU_SETUP" = "intel-only" ]; then
  export LIBVA_DRIVER_NAME="iHD"
fi
