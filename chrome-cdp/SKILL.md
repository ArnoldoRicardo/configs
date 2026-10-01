---
name: chrome-cdp
description: Use when the user wants to drive/automate Google Chrome that is logged into their REAL profile — screenshot or click through authenticated web pages (Google Cloud Console, dashboards, admin panels, Outlook/Rippling/Zoom/FocalPoint, tiendas), do a task "together" in the browser, or connect Playwright/CDP to an already-signed-in session. Trigger on phrases like "abre chrome", "manéjalo con playwright", "hazlo conmigo en el navegador", "screenshot of <logged-in site>", or any need to operate a site as the logged-in user. Also use when CDP on 127.0.0.1:9222 fails, hangs or "se desconecta".
---

# chrome-cdp

Chrome **vive en think-x1** (la laptop, usuario `arlf0`), con una copia del perfil real
para que ya esté logueado. Claude/OMP trabajan en **cyxpc-b** y lo ven en su propio
`http://127.0.0.1:9222` por un túnel `ssh -R` que levanta think-x1.

Todo lo maneja un solo comando, `chrome-debug`, que vive **en esta misma carpeta del skill**
(repo `ArnoldoRicardo/configs`, carpeta `chrome-cdp/`; `~/.local/bin/chrome-debug` es un
symlink a él). Es el mismo archivo en las dos máquinas:

| máquina  | papel   | qué hace `chrome-debug` |
|----------|---------|-------------------------|
| think-x1 | servidor (hay Chrome) | levanta Chrome + túnel como unidades `systemd --user` (`chrome-cdp`, `chrome-cdp-tunnel`), reusa lo sano, verifica de punta a punta desde cyxpc-b |
| cyxpc-b  | cliente (no hay Chrome) | diagnostica el CDP del túnel; si falta algo, corre `chrome-debug` en think-x1 por ssh |

```
chrome-debug [URL] [--insecure] [--fresh] [--port N] [--no-tunnel]   levanta / reusa / abre URL en pestaña nueva
chrome-debug status     diagnóstico, no toca nada (exit 0 = todo bien)
chrome-debug restart    reinicia Chrome y túnel   ← CIERRA las pestañas abiertas
chrome-debug stop       cierra Chrome y túnel
chrome-debug clean      stop + borra la copia del perfil (tiene cookies)
```
Exit: `0` ok · `1` error · `3` pantalla de think-x1 bloqueada · `4` Tailscale SSH pide aprobación.

## Antes de automatizar: `chrome-debug status` (en cyxpc-b)

Si no da ✅, corre `chrome-debug` y actúa según el resultado:

| lo que ves (en cyxpc-b) | causa | qué hacer |
|---|---|---|
| ✅ CDP por el túnel | todo bien | conecta |
| `nada escucha` (curl exit 7) | túnel caído | `chrome-debug` lo intenta en think-x1. Normalmente el túnel se reconecta solo en ~5 s; si persiste, think-x1 está suspendida o sin red |
| `el túnel está, pero detrás no hay Chrome` (exit 52/56) | Chrome de think-x1 cerrado | `chrome-debug` lo relanza |
| `Chrome no contesta` (timeout, exit 28) | **pantalla de think-x1 bloqueada** (exit 3 allá) | pide al usuario que **desbloquee la laptop**. No relances: Chrome está congelado, no muerto; al desbloquear revive con sus pestañas |
| exit 4 + liga `login.tailscale.com` | Tailscale SSH (cyxpc-b → think-x1) pide aprobación | pasa la liga al usuario; tras aprobar, repite. O que el usuario corra `chrome-debug` en think-x1 |

**Por qué se congela al bloquear:** light-locker bloquea a los ~10 min de inactividad y
cambia de VT al greeter (`:1`); Xorg deja de atender la sesión `:0` y el hilo principal de
Chrome se queda esperando al servidor X. Proceso y túnel siguen vivos, el CDP da timeout.

**Nunca uses `restart` sin preguntar**: cierra las pestañas del usuario (pierden estado de
formularios). Si un Chrome existente no responde y la pantalla NO está bloqueada, el script
se niega a tocarlo y sugiere `restart`: esa decisión es del usuario.

## Conectar con Playwright (Python, en cyxpc-b)
Venv aislado, sin descargar navegador (nos conectamos a uno):
```bash
python3 -m venv /tmp/pw-venv && /tmp/pw-venv/bin/pip install -q playwright
```
```python
from playwright.sync_api import sync_playwright
with sync_playwright() as p:
    browser = p.chromium.connect_over_cdp("http://127.0.0.1:9222")  # 127.0.0.1, NO localhost
    ctx = browser.contexts[0]
    page = next((pg for pg in ctx.pages if "TARGET" in pg.url), None) or ctx.new_page()
    page.goto("https://...", wait_until="domcontentloaded")
    page.screenshot(path="/tmp/shot.png")
```
Lee `/tmp/shot.png` para ver la página. Prefiere locators por rol/label/texto; screenshot
después de cada paso antes de cualquier clic con consecuencias. Para abrir una pestaña sin
Playwright: `chrome-debug https://...`.

- **No cierres la última pestaña**: Chrome se sale con ella. Abre una nueva en vez de reusar
  la única, y al terminar cierra solo las que abriste tú.
- `browser.close()` sobre una conexión CDP solo desconecta; no cierra Chrome.
- Un Chrome recién lanzado solo tiene `about:blank`: las pestañas de Outlook/Zoom/etc. hay
  que abrirlas (y confirmar con el usuario la cuenta correcta antes de leer nada).

## Gotchas (por qué el script hace lo que hace)
- **Copia del perfil** (`/tmp/chrome-debug-profile` en think-x1): Chrome 136+ rechaza
  `--remote-debugging-port` sobre el perfil por defecto. Sin `--fresh` la copia persiste
  (conserva login). `--fresh` re-copia; pide al usuario cerrar antes su Chrome principal.
- **`127.0.0.1`, no `localhost`** en think-x1: Chrome escucha solo IPv4. En cyxpc-b el túnel
  escucha en `127.0.0.1` y `::1`, pero usa `127.0.0.1` siempre.
- **Unidades `systemd --user`**: sobreviven a la terminal y a Tailscale SSH (que mata los
  procesos de su sesión aunque haya `setsid`). Logs: `journalctl --user -u chrome-cdp-tunnel`
  / `-u chrome-cdp` en think-x1.
- **Entorno gráfico**: el script copia DISPLAY/XAUTHORITY/D-Bus/keyring del escritorio
  (openbox), así que funciona igual lanzado por ssh y las cookies se descifran.
- **Túnel**: va a `cyxpc-b-ts` (Tailscale; sirve arriba y abajo, la LAN 192.168.100.x es la
  misma subred en los dos módems), sin ControlMaster (no se cae junto con otras sesiones),
  `ExitOnForwardFailure` + `Restart=always`. Ya no se abre `ssh -N -R` a mano: si hay uno
  viejo, `chrome-debug` lo cierra y lo reemplaza.
- cyxpc-b → think-x1 por ssh es **Tailscale SSH** (aprobación por navegador periódica);
  think-x1 → cyxpc-b-ts también lo atiende Tailscale SSH (no aplica el sshd_config).

## Seguridad y limpieza
- La copia del perfil tiene cookies y sesiones reales. Al terminar un trabajo puntual:
  `chrome-debug clean` (en think-x1, o desde cyxpc-b si Tailscale SSH está aprobado).
  Borra también descargas sensibles y screenshots de `/tmp`.
- Sesiones autenticadas = sensible. El usuario mete credenciales/2FA/CAPTCHA y aprueba
  clics con consecuencias; tú navegas, lees, haces screenshots y llenas campos no sensibles.
- Nunca pegues en el chat secretos leídos de páginas o archivos.
