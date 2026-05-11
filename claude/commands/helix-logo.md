---
description: Activa/desactiva el logo (ajolote) como fondo de Windows Terminal.
---

# /helix-logo — Logo de fondo en Windows Terminal

Edita `profiles.defaults` en el `settings.json` de Windows Terminal para mostrar (o quitar) el ajolote como `backgroundImage`. Hace backup automático antes de cada cambio.

## Uso

```
/helix-logo on       # activa el logo
/helix-logo off      # lo desactiva
/helix-logo status   # reporta estado actual
/helix-logo toggle   # invierte el estado
```

Si no se pasa argumento, ejecutar `status`.

## Cómo lo ejecuta Claude

Llamar al helper:

```bash
bash ~/.helix/helpers/helix-logo.sh <argumento>
```

Argumentos válidos: `on`, `off`, `status`, `toggle`. Cualquier otro → mostrar `--help` del helper.

## Limitación conocida (decir al usuario tras `on`/`off`)

Windows Terminal NO refresca el `backgroundImage` de tabs ya abiertas. El cambio se ve recién al abrir una **tab/ventana nueva**. Esto es un límite del propio WT, no del comando. Referencia: `~/.helix/snapshots/global/20260505-170825.yaml`.

## Detalles operativos

- Settings de WT: auto-detectado bajo `/mnt/c/Users/<usuario>/AppData/Local/Packages/Microsoft.WindowsTerminal_*/LocalState/settings.json`. Override manual con `HELIX_WT_DIR`.
- PNG del logo: `…/LocalState/ajolote-final-v3.png`
- Keys que toca en `profiles.defaults`: `backgroundImage`, `backgroundImageOpacity` (0.35), `backgroundImageAlignment` (topRight), `backgroundImageStretchMode` (uniform).
- Backup por cambio: `settings.json.bak.helix-logo.<YYYYMMDD-HHMMSS>` en el mismo dir.
- `on` cuando ya está ON, o `off` cuando ya está OFF → no-op, sin escribir.
