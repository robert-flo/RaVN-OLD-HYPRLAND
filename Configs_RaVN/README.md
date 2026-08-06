# RaVN-owned resources

This tree contains only resources owned by the independent RaVN installer.
Its layout mirrors the user's home directory and is consumed by the category
manifests under `Scripts/`.

- `.config/waybar` is the RaVN configuration overlay.
- `.local/share/waybar` contains RaVN-owned Waybar resources.
- `.local/share/applications/icons` contains reusable RaVN launcher icons.

User binaries (`git-bare-clone`, `ravn-dot`, `meld-comparisons`, etc.) live in
`Configs/.local/bin` as the single source of truth. The binaries category
installer (`Scripts/binaries/`) reads that tree via `restore_binaries.psv`;
do not reintroduce a parallel copy under `Configs_RaVN/.local/bin`.

`Configs/` remains the upstream configuration tree for home-layout resources
that are not exclusive to the RaVN installer overlay (Waybar, icons).
