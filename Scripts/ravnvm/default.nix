{
  pkgs ? import <nixpkgs> { },
  lib ? pkgs.lib,
}:

let
  # Import the unified shell script
  ravnvmScript = pkgs.writeShellApplication {
    name = "ravnvm";
    runtimeInputs = with pkgs; [
      qemu
      curl
      python3
      git
      coreutils
      findutils
      gnused
      gawk
    ];
    text = builtins.readFile ./ravnvm.sh;
  };
in
{
  defaultPackage = ravnvmScript;

  mkRavnVM =
    {
      memory ? "4G",
      cpus ? 2,
      extraArgs ? "",
    }:
    pkgs.writeShellApplication {
      name = "run-ravnvm";
      runtimeInputs = [ ravnvmScript ];
      text = ''
        VM_MEMORY="${memory}" VM_CPUS="${toString cpus}" VM_EXTRA_ARGS="${extraArgs}" ravnvm "$@"
      '';
    };
}
