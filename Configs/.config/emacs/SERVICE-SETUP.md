# Emacs External Service Setup

This guide covers the external dependencies required for Emacs keybindings
that wrap external tools: password-store (`pass`), mu4e (email), and EMMS (music).

## Password Store (pass) — Super+P

[pass](https://www.passwordstore.org/) is the standard Unix password manager.

### Required on the system:

```bash
# Arch Linux
sudo pacman -S pass

# The pass Emacs package (pass.el) is auto-installed via Elpaca
```

### One-time setup:

```bash
# Generate a GPG key (if you don't have one)
gpg --full-generate-key

# Initialize the password store (use the GPG key ID from above)
pass init "<your-gpg-key-id>"
# Example: pass init "ABC123DEF4567890"
```

### Optional: Git for synchronization:

```bash
pass git init
pass git remote add origin <your-remote>
```

### Verification:

```bash
# Insert a test entry
pass insert test/example

# Verify it appears in Emacs
pass git status
```

Without a configured password store at `~/.password-store/`, the Super+P
keybinding will silently do nothing.

---

## Mu4e (Email) — Super+M

Mu4e requires [mu](https://www.djcbsoftware.nl/code/mu/mu4e.html) (the mail
indexer) and offline email synchronization via
[mbsync](https://isync.sourceforge.io/) (isync) and
[msmtp](https://marlam.de/msmtp/).

### Required on the system:

```bash
# Arch Linux
sudo pacman -S mu isync msmtp
```

### Configuration files:

1. **`~/.mbsyncrc`** — IMAP sync configuration
2. **`~/.msmtprc`** — SMTP (outgoing mail) configuration
3. **`~/.authinfo.gpg`** — GPG-encrypted credentials file
4. **`~/Mail/`** — Local mail directory

### Mu4e per-user config:

Copy the template and edit with your details:

```bash
cp ~/.config/emacs/lisp/custom/mail-user.el.example \
   ~/.config/emacs/lisp/custom/mail-user.el
```

### Initial index:

```bash
mu init --maildir=~/Mail --my-address=<your-email>
mu index
```

### Verification:

```bash
mu find from:<your-email>
```

Without mu4e configured, the Super+M keybinding will open an error buffer
in Emacs.

---

## EMMS (Music Player) — Super+Ctrl+M

[EMMS](https://www.gnu.org/software/emms/) (Emacs Multimedia System) plays
audio files through external backends like `mpv`, `vlc`, or `mplayer`.

### Required on the system:

```bash
# Arch Linux
sudo pacman -S mpv
```

Optionally, any MPD (Music Player Daemon) setup is supported:

```bash
sudo pacman -S mpd mpc
```

### Music directory:

Place your music files in `~/Music/`. EMMS is pre-configured to scan this
directory.

### Verification:

```bash
ls ~/Music/
```

Without any audio files or a backend player, the Super+Ctrl+M keybinding
will open the EMMS playlist buffer (empty but functional).
