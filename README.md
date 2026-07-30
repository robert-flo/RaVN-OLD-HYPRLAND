# Ravn's Arch Linux Configuration

A deeply modified Arch Linux configuration based on [HyDE](https://github.com/HyDE-Project/HyDE), designed for power users seeking a scalable, professional, and complete development environment optimized for AI-assisted software development in 2026. Built with dotbare for selective dotfile tracking, automated installation scripts, and a comprehensive Makefile for seamless system administration. It integrates the modular RaVN bootstrap framework ([Scripts/ravn](Scripts/ravn)), custom CLI utilities ([Configs/.local/bin](Configs/.local/bin)), and a dedicated [git-setup.sh](git-setup.sh) script for streamlined Git and SSH configuration.

---

<br>

<a id="installation"></a>
<img src="https://readme-typing-svg.herokuapp.com?font=Lexend+Giga&size=25&pause=1000&color=CCA9DD&vCenter=true&width=435&height=25&lines=INSTALLATION" width="450"/>



### Full Installation (This Branch)
Get the latest features and updates:
```shell
sudo pacman -S --needed git base-devel
git clone --depth 1 https://github.com/robert-flo/RaVN ~/RaVN
cd ~/RaVN/Scripts
./install.sh
```
---

<br> 

<a id="updating"></a>
<img src="https://readme-typing-svg.herokuapp.com?font=Lexend+Giga&size=25&pause=1000&color=CCA9DD&vCenter=true&width=435&height=25&lines=UPDATING" width="450"/>

To update RaVN and restore all resources, including any system-level resources required by the full workflow, run:

> [!CAUTION]
> The following commands will discard any uncommitted local changes in the repository.

```shell
cd ~/RaVN/Scripts
git fetch --update-shallow --depth 1 origin master
git reset --hard origin/master
./install.sh -r
```

To test or apply only the managed configuration under your home directory, without `sudo`, use:

```shell
./install.sh -o
```

`-o` overwrites managed user configuration and skips fonts, themes, migrations,
launchers, package installation, and other privileged-capable phases. `-ro` is
an equivalent compatibility alias. After a successful restore, it runs
`hyde-shell reload` so Waybar and the active HyDE session use the deployed
configuration. If HyDE is unavailable, the installer warns and continues.

To preview this workflow without changing files or reloading the desktop session,
use `./install.sh -ot`; it reports that the HyDE reload would run.

> [!WARNING]
> Please note that any configurations you made will be overwritten if listed to be done so as listed by `Scripts/restore_cfg.psv`.
> However, all replaced configs are backed up and may be recovered from in `~/.config/cfg_backups`.


---

<br>
<a id="ravnvm"></a>
<img src="https://readme-typing-svg.herokuapp.com?font=Lexend+Giga&size=25&pause=1000&color=CCA9DD&vCenter=true&width=435&height=25&lines=RAVNVM" width="450"/>


RaVNVM is a script that allows you to run RaVN in a virtual machine for testing and development.

## Quick Start

### Arch Linux

```bash
# Download and run (will auto-detect missing packages)
curl -L https://raw.githubusercontent.com/robert-flo/RaVN/master/Scripts/ravnvm/ravnvm.sh -o ravnvm
chmod +x ravnvm
./ravnvm
```

---

<br>


<a id="See It in Action"></a>
<img src="https://readme-typing-svg.herokuapp.com?font=Lexend+Giga&size=25&pause=1000&color=CCA9DD&vCenter=true&width=435&height=25&lines=See%20It%20in%20Action" width="450"/>



<div align="center">

<https://github.com/user-attachments/assets/7f8fadc8-e293-4482-a851-e9c6464f5265>

</div>



Read more at [robert-flo.github.io/ravn](https://robert-flo.github.io/ravn).

---

<br>

<a id="contributing"></a>
<img src="https://readme-typing-svg.herokuapp.com?font=Lexend+Giga&size=25&pause=1000&color=CCA9DD&vCenter=true&width=435&height=25&lines=CONTRIBUTING" width="450"/>

- I actual prefer a well written issue describing features/bugs u want rather than a vibe-coded PR
- I review every line personally and will close if I feel like the quality is not up to standard

---

<br>

## License

This configuration is released under the [GNU General Public License v3.0](https://www.gnu.org/licenses/gpl-3.0.html).
