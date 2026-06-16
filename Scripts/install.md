# Main Installation Script

`install.sh` is the primary installer script for the RaVN desktop environment configuration.

| Option | Flag | Description |
| ------ | ---- | ----------- |
| `i` | `-i` | **Install** Hyprland and standard packages without configuration files. |
| `d` | `-d` | **Default** installation of packages without configurations in non-interactive mode (`--noconfirm`). |
| `r` | `-r` | **Restore** personal configuration files, themes, fonts, and settings. |
| `s` | `-s` | **Services**: Enable and configure system/user systemd services. |
| `n` | `-n` | **No Nvidia**: Ignore Nvidia graphics card detection and skip Nvidia-specific package additions. |
| `h` | `-h` | **Shell**: Re-evaluate and re-configure user Shell options (zsh/fish). |
| `m` | `-m` | **No Theme**: Skip themed resource and font patcher reinstallations. |
| `t` | `-t` | **Test Run**: Dry-run simulation mode where no changes are written to the system. |
| `o` | `-o` | **Overwrite**: Force overwriting target configurations (maps preservation rules to overwrite/sync). |

## Important Behavior & Flag Combinations

> [!IMPORTANT]
> **No arguments vs. passing flags:**
> - Running `./install.sh` without any arguments is equivalent to `./install.sh -irs` (Installs packages, restores configurations, and enables system services).
> - If you pass **any** option (like `-o`, `-n`, `-t`, or `-m`), the default action group (`-irs`) is **disabled**. You must explicitly specify which actions to perform.
> - For example, running `./install.sh -o` alone will not execute any installations, restorations, or services. To restore configurations with overwrite enabled, you must combine the restore action flag (`-r`) with the overwrite flag (`-o`), resulting in: `./install.sh -ro`.

## Usage Examples

* **Standard Installation (Default when running without arguments):**
  ```bash
  ./install.sh
  # (Equivalent to running: ./install.sh -irs)
  ```
  *(Installs packages, restores configurations, and registers system services)*

* **Standard Installation skipping Nvidia drivers:**
  ```bash
  ./install.sh -irsn
  ```

* **Dry-run simulation of a full installation:**
  ```bash
  ./install.sh -irst
  ```

* **Restore configuration files, forcing overwrite on target files:**
  ```bash
  ./install.sh -ro
  ```
