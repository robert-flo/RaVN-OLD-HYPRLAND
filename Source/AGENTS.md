# Purpose

Binary archives, theme assets, fonts, and graphical resources consumed by the installer and documentation. Contains pre-built `.tar.gz` / `.vsix` bundles and screenshot/image assets.

# Ownership

Owned by the RaVN installer pipeline (`restore_fnt.sh`, `restore_thm.sh`) and `README.md` documentation.

# Local Contracts

- **Archives** (`arcs/`): Compressed tarballs and VSIX packages. Named with a `Type_Name` convention (e.g., `Font_JetBrainsMono.tar.gz`, `Sddm_Candy.tar.gz`, `Code_Wallbash.vsix`).
- **Assets** (`assets/`): PNG images used in documentation and README — theme showcases, rofi styles, keybind diagrams, distro logos, and game launch screenshots.
- **No source compilation**: Archives are pre-built. If an archive needs updating, rebuild externally and replace the file.
- **Size awareness**: Archives are large binary blobs. Avoid unnecessary re-commits that inflate git history.

# Work Guidance

- When adding a new font or theme archive, follow the `Type_Name.tar.gz` naming convention in `arcs/`.
- When adding documentation screenshots, place them in `assets/` with a descriptive `category_name_N.png` name.
- Keybind diagrams live in `assets/keybinds/`.

# Verification

- Validate that new archives extract correctly without errors using standard extraction tools (`tar -xzf <archive>`).
- Ensure no broken symlinks are present in the compressed archives.

# Child DOX Index

This directory has no child boundaries.
