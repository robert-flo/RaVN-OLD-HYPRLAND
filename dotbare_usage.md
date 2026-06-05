# Guía de Trabajo Diario: Gestión de Dotfiles con dotbare y RaVN

Esta guía detalla los flujos de trabajo cotidianos y casos de uso prácticos para administrar tus dotfiles utilizando el esquema de doble repositorio:
1. **`dotbare` (en `$HOME`):** Controla tus archivos activos y tu historial local de playthrough.
2. **`RaVN` (en `/home/dominus/hola/RaVN`):** Es la fuente de la verdad del instalador y las plantillas limpias.

---

## Atajos Recomendados en tu Shell

Para agilizar el flujo de trabajo, añade estos alias a tu archivo de alias de Zsh (`~/.config/zsh/user.zsh`):

```zsh
# Sincronizar cambios de tu $HOME activo de vuelta a las plantillas de RaVN
alias ravn-sync="/home/dominus/hola/RaVN/Scripts/sync_back.sh"

# Ver diferencias en el instalador de desarrollo
alias ravn-status="git -C /home/dominus/hola/RaVN status"
alias ravn-diff="git -C /home/dominus/hola/RaVN diff"
```

---

## Caso de Uso 1: Modificar una configuración activa y guardar los cambios

* **Objetivo:** Quieres cambiar tus atajos de teclado o preferencias de Hyprland en tu sistema y guardar el cambio tanto en tu historial de dotfiles como en el instalador oficial.

### Paso 1: Edita el archivo en tu `$HOME`
Modifica tu archivo activo directamente (por ejemplo, con tu editor o mediante la GUI):
```bash
nano ~/.config/hypr/userprefs.conf
# O usando dotbare fedit (abre un fzf de tus archivos rastreados)
dotbare fedit
```

### Paso 2: Revisa y prepara tus cambios en tu `$HOME`
Ejecuta `dotbare fstat` para interactuar con tus cambios en la terminal:
```bash
dotbare fstat
```
* **En el menú interactivo:**
  * Usa las flechas para posicionarte sobre `.config/hypr/userprefs.conf`.
  * Verás el diff coloreado en la ventana lateral.
  * Presiona `Tab` para seleccionarlo (se marcará con un asterisco).
  * Presiona `Enter` para hacer el `stage` (`git add`).

### Paso 3: Haz commit y push en tu playthrough de dotfiles
Guarda el cambio en el historial de tu máquina:
```bash
dotbare commit -m "Ajuste en la velocidad de animaciones"
dotbare push
```

### Paso 4: Sincroniza hacia la fuente de la verdad (`RaVN`)
Copia tu cambio de vuelta a las plantillas del instalador:
```bash
ravn-sync
```
*El script detectará que tu archivo local es más nuevo y lo copiará a `RaVN/Configs/.config/hypr/userprefs.conf`.*

### Paso 5: Publica en el instalador oficial
Ve a tu repositorio de desarrollo para confirmar y subir a tu repositorio principal de GitHub:
```bash
cd /home/dominus/hola/RaVN
git status
git add Configs/.config/hypr/userprefs.conf
git commit -m "update(configs): actualizar velocidad de animaciones por defecto"
git push
```

---

## Caso de Uso 2: Deshacer un cambio experimental en tu sistema (Rollback)

* **Objetivo:** Hiciste una serie de modificaciones experimentales en tu barra `waybar` o configuraciones de Zsh, todo se rompió y quieres volver al último estado limpio y funcional.

### Paso 1: Identifica el estado con `dotbare fstat`
Ejecuta:
```bash
dotbare fstat
```
Verás la lista de archivos modificados que no has guardado.

### Paso 2: Descartar los cambios
* **Opción A (Interactiva):**
  Ejecuta `dotbare fcheckout`:
  ```bash
  dotbare fcheckout
  ```
  * Selecciona los archivos que deseas restaurar en el menú de `fzf` y presiona `Enter`.
* **Opción B (Línea de comandos rápida):**
  Si sabes qué archivo quieres restaurar:
  ```bash
  dotbare checkout -- .config/waybar/config.jsonc
  ```
*El archivo en tu `$HOME` volverá instantáneamente al estado de tu último commit de dotfiles.*

---

## Caso de Uso 3: Rastrear un archivo nuevo que no estaba en el repositorio

* **Objetivo:** Has creado un archivo nuevo (por ejemplo, alias personalizados en `.config/zsh/my-aliases.zsh`) y quieres agregarlo de forma permanente a tu sistema de seguimiento e instalador.

### Paso 1: Agrega el archivo a la lista de restauración
Abre [restore_cfg.psv](file:///home/dominus/hola/RaVN/Scripts/restore_cfg.psv) en tu editor y añade la línea con bandera `P` indicando la dependencia (ej. `zsh`):
```text
P|${HOME}/.config/zsh|my-aliases.zsh|zsh
```

### Paso 2: Registra el archivo en `dotbare`
Para que `dotbare` empiece a vigilar este nuevo archivo en tu `$HOME`:
```bash
dotbare add ~/.config/zsh/my-aliases.zsh
```
*El archivo ahora es parte del índice de tu repositorio bare.*

### Paso 3: Sincroniza hacia el repositorio de desarrollo
Ejecuta el script de sincronización inversa:
```bash
ravn-sync
```
*Dado que `my-aliases.zsh` no existía en `RaVN/Configs/`, el script detectará que es un archivo `[nuevo]` y lo copiará a `/home/dominus/hola/RaVN/Configs/.config/zsh/my-aliases.zsh`.*

### Paso 4: Confirma el archivo y los cambios en `RaVN`
```bash
cd /home/dominus/hola/RaVN
git add Scripts/restore_cfg.psv Configs/.config/zsh/my-aliases.zsh
git commit -m "feat(zsh): agregar alias personalizados"
git push
```

---

## Caso de Uso 4: Migrar o instalar tus dotfiles en una computadora nueva

* **Objetivo:** Tienes una máquina recién formateada y quieres aplicar exactamente tus configuraciones personalizadas instalando todo desde cero.

### Paso 1: Clona tu repositorio de desarrollo `RaVN`
```bash
git clone git@github.com:robert-flo/RaVN.git ~/hola/RaVN
```

### Paso 2: Ejecuta el instalador
```bash
cd ~/hola/RaVN/Scripts
./install.sh
```
* **Qué ocurrirá automáticamente:**
  1. Se instalarán todos los paquetes necesarios del sistema.
  2. Las configuraciones de `Configs/` se copiarán a tu nuevo `$HOME`.
  3. `install.sh` llamará a `dotbare_init.sh`.
  4. Se inicializará tu base de datos bare en `$HOME/.cfg` y todos tus archivos con bandera `P` quedarán bajo seguimiento desde el primer segundo.

---

## Tabla de Comandos Rápidos de `dotbare`

Usa estos comandos desde cualquier ubicación de tu terminal:

| Comando | Acción |
| :--- | :--- |
| `dotbare fstat` | Menú interactivo de estado de archivos (stage/unstage con `Tab`) |
| `dotbare fadd -f` | Busca cualquier archivo en el directorio actual y lo añade al rastreo |
| `dotbare fedit` | Menú interactivo para seleccionar y editar tus dotfiles en tu `$EDITOR` |
| `dotbare flog` | Navegador de commits interactivo (presiona `Enter` para ver el diff completo de un commit) |
| `dotbare freset` | Menú interactivo para des-preparar (`unstage`) archivos de tu Git |
| `dotbare fcheckout` | Menú interactivo para descartar cambios locales en archivos específicos |
| `dotbare commit -m "..."` | Crea un commit con los cambios preparados en tu playthrough local |
| `dotbare push` | Sube tus cambios al repositorio remoto de dotfiles |
