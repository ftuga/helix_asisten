# FASE 9 HW-Aware — Implementación A2 (TRANCH 1)

> Plan v4 FASE 9, decisión post-Council A→B→C→D, sesión #19 2026-05-04.
> Objetivo: detección defensiva de HW para evitar tardanzas multi-hora reportadas por usuarios en máquinas modestas (WSL2 OOM, Capa 0 bloqueada).

## Componentes implementados

| ID | Helper | Función | Status |
|---|---|---|---|
| HW1 | `~/.claude/helpers/helix-hwprobe.sh` | Detecta CPU/RAM/GPU/disco/OS → cache `~/.claude/hw-profile.json` | ✓ implementado |
| HW2 | `~/.claude/helpers/helix-capa0-policy.sh` | Decide policy ON/OPT_IN/OFF basado en profile + bench si existe | ✓ implementado |
| HW3 | `~/.claude/helpers/helix-models-suggest.sh` | Lista modelos Ollama compatibles con el HW (no fuerza descarga) | ✓ implementado |
| HW4 | `~/.claude/helpers/helix-bench-capa0.sh` | Bench empírico con timeout 35s. Cache TTL 7d. Sobrescribe heurística HW2 | ✓ implementado |
| HW5 | `helix-installer` pregunta antes de descargar Ollama | Interfaz documentada para FASE 6 | ⏸ DIFERIDO a TRANCH 3 |

## Wireados

- `~/helix_asisten/scripts/capa0.sh` ahora consulta HW2 antes de invocar Ollama. Si policy=OFF → exit 2 inmediato (caller debe escalar a Capa 1).
- Timeout duro 30s en `ollama run` (override con `CAPA0_TIMEOUT` env var).
- HW4 bench cuando exista, override la heurística RAM de HW2.

## Decisión de policy (fuente de verdad)

```
1. ¿bench reciente en cache? → usar latencia empírica
   - <10s   → ON
   - 10-30s → OPT_IN (solo modelos pequeños)
   - >30s   → OFF (fallback Claude inmediato)
2. ¿no hay bench? → heurística RAM/GPU
   - GPU NVIDIA + ≥4GB VRAM → large → ON
   - RAM ≥16GB sin GPU → large → ON
   - RAM 8-16GB → medium → OPT_IN
   - RAM <8GB → small → OFF
3. ollama no instalado → OFF
```

## Mitigation council dissent #3 (umbral 8GB sin cita)

El umbral 8GB en la heurística es **declarado, NO citado**. La synthesis del Council #1 explicitó este disenso residual.

**Mitigation aplicada:** HW4 bench produce el dato empírico que reemplaza la heurística. Una vez bench corre (1× por instalación + cada 7 días), HW2 usa latencia medida en lugar de RAM heurística. Esto convierte la decisión de "8GB es umbral" a "tu HW responde en Xms — esa es la verdad".

Documentado en `helix-hwprobe.sh` campo `tier_source` con valor `heuristic|empirical` y `tier_source_note` con explicación.

## Tier classification

| Tier | Trigger heurística | Bench equivalente | Policy default |
|---|---|---|---|
| `large` | RAM≥16GB ó GPU NVIDIA ≥4GB VRAM | latencia <10s | ON |
| `medium` | RAM 8-16GB sin GPU | latencia 10-30s | OPT_IN |
| `small` | RAM <8GB | latencia >30s o timeout | OFF |

## Profile schema (`~/.claude/hw-profile.json`)

```json
{
  "schema": "helix-hw-profile/v1",
  "probed_at": "ISO 8601",
  "host": "<hostname>",
  "os": "wsl2|linux|macos",
  "cpu": { "cores": N, "freq_mhz": N, "model": "..." },
  "ram_mb": { "total": N, "used": N, "available": N },
  "gpu": { "kind": "nvidia|amd|intel-igpu|other|none", "name": "...", "vram_mb": N },
  "disk_free_gb": N,
  "tier": "small|medium|large",
  "tier_source": "heuristic|empirical",
  "tier_source_note": "..."
}
```

## Bench schema (`~/.claude/cache/capa0-bench.json`)

```json
{
  "schema": "helix-capa0-bench/v1",
  "benched_at": "ISO 8601",
  "status": "ok|ollama_missing|no_models_installed",
  "model": "<modelo usado para bench>",
  "mode": "quick|full",
  "prompt": "say only OK",
  "latency_ms": N,
  "timeout_sec": 35,
  "policy_recommended": "ON|OPT_IN|OFF"
}
```

## HW5 — interfaz para FASE 6 installer (DIFERIDO)

Cuando se implemente `helix-installer.sh` (FASE 6, TRANCH 3 pospuesto):

```bash
# Pseudo-código
bash $HELIX_DIR/helpers/helix-hwprobe.sh --quiet
TIER=$(bash $HELIX_DIR/helpers/helix-hwprobe.sh --tier)

case "$TIER" in
  small)
    echo "Tu HW es modesto (RAM <8GB). Capa 0 (modelos locales) puede tardar."
    read -p "¿Habilitar Capa 0 igual? [y/N]: " ans
    [[ "$ans" =~ ^[yY]$ ]] || SKIP_OLLAMA=1
    ;;
  medium)
    echo "Tu HW soporta Capa 0 con modelos pequeños (~5GB descarga)."
    read -p "¿Descargar phi3:mini? [Y/n]: " ans
    [[ "$ans" =~ ^[nN]$ ]] || ollama pull phi3:mini
    ;;
  large)
    echo "Tu HW soporta Capa 0 full. Recomendado: helix-scout + helix-coder (~7GB)."
    read -p "¿Descargar todos los modelos custom Helix? [Y/n]: " ans
    [[ "$ans" =~ ^[nN]$ ]] || install_helix_models
    ;;
esac

# Bench post-install para tier empírico
bash $HELIX_DIR/helpers/helix-bench-capa0.sh
```

## Auditoría

| Verificación | Comando | Resultado esperado |
|---|---|---|
| Profile generado | `cat ~/.claude/hw-profile.json` | JSON con campos schema, probed_at, cpu, ram_mb, gpu, tier |
| Policy decision | `bash ~/.claude/helpers/helix-capa0-policy.sh --json` | JSON con policy + reason + tier_source |
| Models compatibles | `bash ~/.claude/helpers/helix-models-suggest.sh` | Tabla con FIT por modelo |
| Bench (~30s) | `bash ~/.claude/helpers/helix-bench-capa0.sh` | latencia_ms + policy_recommended |
| capa0.sh wired | `bash ~/helix_asisten/scripts/capa0.sh logs "test"` | Si policy=OFF → exit 2 con mensaje. Si ON → respuesta del modelo |

## Próximos pasos

- **A3** cementing D2/D3/D4 + B docs (siguiente sesión)
- Ejecutar bench HW4 manualmente la primera vez para tener tier empírico (no urgente, tier=large heurística ya OK)
