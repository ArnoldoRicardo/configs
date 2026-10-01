# configs

Configuración que uso en todas mis máquinas (think-x1, cyxpc-b, azul).

## vim

Máquina nueva:

    curl -fsSL https://raw.githubusercontent.com/ArnoldoRicardo/configs/main/vimrc > ~/.vimrc

Un solo archivo para local y remoto: detecta en arranque si vim tiene `+clipboard` y
si hay sesión X, y elige el camino al portapapeles.

- **Con X11** (think-x1; necesita `vim-gtk3`, el `vim` de Debian viene con `-clipboard`):
  `y` copia directo al portapapeles del sistema. `d`, `x` y `c` no lo tocan, así que
  borrar no te pisa lo que copiaste en el navegador. `,p` pega lo copiado fuera de vim.
  Al salir, un `VimLeave` le pasa el contenido a `xsel` — si no, X11 lo pierde al morir
  el proceso.
- **Por ssh** (cyxpc-b, azul): `,y`, `,Y` y `:Copy` emiten OSC 52. Llega al portapapeles
  de la laptop si la sesión va por sshclip, o por un terminal con soporte OSC 52 nativo.

Sin gestor de plugins: arranca igual de rápido por ssh que en local.

## chrome-cdp

Chrome ya logueado (copia del perfil real) con DevTools Protocol, para automatizarlo con
Playwright/OMP/Claude Code. Chrome corre en think-x1 y cyxpc-b lo ve en su propio
`127.0.0.1:9222` por un túnel `ssh -R` que se reconecta solo.

La carpeta es a la vez el skill de Claude Code (`SKILL.md`) y el comando (`chrome-debug`,
bash). El mismo script sirve en las dos máquinas: si hay Chrome hace de servidor (levanta
Chrome + túnel como unidades `systemd --user`), si no, de cliente (diagnostica y lo arregla
en think-x1 por ssh). `chrome-debug status` dice qué falla; `chrome-debug --help`, el resto.

Instalar (think-x1 y cyxpc-b), con el repo clonado en `~/dev/configs`:

    ln -sfn ~/dev/configs/chrome-cdp ~/.claude/skills/chrome-cdp
    ln -sf  ~/dev/configs/chrome-cdp/chrome-debug ~/.local/bin/chrome-debug

Si la pantalla de think-x1 se bloquea, Chrome se congela hasta desbloquearla (light-locker
cambia de VT y Xorg deja de atender la sesión).

## init.vim (legacy)

Config de Neovim generada con vim-bootstrap en 2021. Ya no la uso, se queda por historia.

    curl -fsSL https://raw.githubusercontent.com/ArnoldoRicardo/configs/main/init.vim > ~/.config/nvim/init.vim

## oh-my-zsh

    sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
