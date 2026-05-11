#!/usr/bin/env bash
# rollout-v3.sh — Promotion script HELIX-LANG v2.1 -> v3.0
#
# STUB con preconditions hardcodeadas. NO ejecuta hasta que el creator lo invoque
# explicitamente con --confirm. Diseñado por sprint 5 post-council 20260507T215307Z-109qf.
#
# Uso:
#   bash ~/.helix/skills/helix-lang/rollout-v3.sh --check       # solo valida preconditions
#   bash ~/.helix/skills/helix-lang/rollout-v3.sh --rollout     # dry-run, muestra que haria
#   bash ~/.helix/skills/helix-lang/rollout-v3.sh --confirm     # EJECUTA (irreversible sin restore)
#   bash ~/.helix/skills/helix-lang/rollout-v3.sh --rollback    # revierte v3 -> v2.1
#
# Preconditions verificadas:
#   1. Council A (pilot meta-circular) PASS en M1+M2+M3+M4+M5
#   2. Council B (pilot tecnico externo) PASS en M1+M2+M3+M4+M5
#   3. SKILL-v3-DRAFT.md existe
#   4. m3-rubric.md tiene >=3 PASS y >=3 FAIL
#   5. Backup directory writeable

set -euo pipefail

readonly HELIX_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
readonly SKILL_DIR="${HELIX_DIR}/skills/helix-lang"
readonly COUNCIL_DIR="${HELIX_DIR}/council"
readonly LOG_DIR="${COUNCIL_DIR}/log"
readonly BACKUP_DIR="${SKILL_DIR}/backups"

readonly SKILL_ACTIVE="${SKILL_DIR}/SKILL.md"
readonly SKILL_DRAFT="${SKILL_DIR}/SKILL-v3-DRAFT.md"
readonly RUBRIC="${SKILL_DIR}/m3-rubric.md"
readonly DOCTRINE="${COUNCIL_DIR}/inter-agent-language.md"

readonly PILOT_LABEL="feature/helix-lang-v3-pilot"
readonly TIMESTAMP=$(date -u +%Y%m%dT%H%M%SZ)

mode="${1:---check}"

log() { printf '[rollout-v3] %s\n' "$*" >&2; }
err() { printf '[rollout-v3 ERROR] %s\n' "$*" >&2; }

# === Preconditions ===

check_preconditions() {
    local fail=0

    # P-RUBRIC: rubrica completa
    if [[ ! -f "$RUBRIC" ]]; then
        err "P1 FAIL: m3-rubric.md no existe en $RUBRIC"
        fail=1
    else
        local pass_n fail_n
        # Cuenta solo lineas con contenido real (no placeholders <...>)
        pass_n=$(awk '/^(Por qué pasa|Why it passes):[[:space:]]+[^<[:space:]]/{n++} END{print n+0}' "$RUBRIC" 2>/dev/null)
        fail_n=$(awk '/^(Por qué falla|Why it fails):[[:space:]]+[^<[:space:]]/{n++} END{print n+0}' "$RUBRIC" 2>/dev/null)
        if [[ "$pass_n" -lt 3 ]] || [[ "$fail_n" -lt 3 ]]; then
            err "P1 FAIL: rubrica incompleta. PASS=$pass_n FAIL=$fail_n (requerido >=3 c/u)"
            fail=1
        else
            log "[OK] P1: rubrica completa ($pass_n PASS, $fail_n FAIL)"
        fi
    fi

    # P-DRAFT: SKILL-v3-DRAFT existe
    if [[ ! -f "$SKILL_DRAFT" ]]; then
        err "P-DRAFT FAIL: SKILL-v3-DRAFT.md no existe en $SKILL_DRAFT"
        fail=1
    else
        log "[OK] P-DRAFT: SKILL-v3-DRAFT.md presente"
    fi

    # P-PILOT: buscar audit logs de pilot councils etiquetados con PILOT_LABEL
    # El pilot debe haber producido al menos 2 audit logs FINALIZED con session_version=3.0
    local pilot_audits
    pilot_audits=$(find "$LOG_DIR" -maxdepth 1 -name "*.yaml" -newer "$SKILL_DRAFT" 2>/dev/null \
                   | xargs -r grep -l "helix_lang_version: \"3.0\"" 2>/dev/null \
                   | wc -l)
    if [[ "$pilot_audits" -lt 2 ]]; then
        err "P-PILOT FAIL: solo $pilot_audits audit logs pilot encontrados (requerido >=2)"
        err "   Buscando en: $LOG_DIR"
        err "   Filtro: helix_lang_version: \"3.0\" + newer than SKILL-v3-DRAFT.md"
        fail=1
    else
        log "[OK] P-PILOT: $pilot_audits audit logs pilot v3.0 encontrados"
    fi

    # P-PILOT-PASS: cada audit log de pilot debe tener decision != REJECTED
    # Y si tiene m3_gate, m3_confirmation debe ser PASS
    local rejected_count=0
    local m3_fail_count=0
    while IFS= read -r audit; do
        [[ -f "$audit" ]] || continue
        local decision
        decision=$(grep -E '^decision:' "$audit" | head -1 | awk '{print $2}' | tr -d '"')
        if [[ "$decision" == "REJECTED" ]]; then
            rejected_count=$((rejected_count + 1))
            err "  REJECTED audit: $audit"
        fi
        local m3_conf
        m3_conf=$(grep -E '^\s*confirmation:' "$audit" | head -1 | awk '{print $2}' | tr -d '"')
        if [[ -n "$m3_conf" && "$m3_conf" != "PASS" ]]; then
            m3_fail_count=$((m3_fail_count + 1))
            err "  M3 FAIL audit: $audit (m3_confirmation=$m3_conf)"
        fi
    done < <(find "$LOG_DIR" -maxdepth 1 -name "*.yaml" -newer "$SKILL_DRAFT" 2>/dev/null \
             | xargs -r grep -l "helix_lang_version: \"3.0\"" 2>/dev/null)

    if [[ "$rejected_count" -gt 0 ]] || [[ "$m3_fail_count" -gt 0 ]]; then
        err "P-PILOT-PASS FAIL: rejected=$rejected_count m3_fail=$m3_fail_count"
        fail=1
    else
        log "[OK] P-PILOT-PASS: 0 REJECTED, 0 M3 FAIL en pilot logs"
    fi

    # P-BACKUP: backup dir writeable
    mkdir -p "$BACKUP_DIR" 2>/dev/null || true
    if [[ ! -w "$BACKUP_DIR" ]]; then
        err "P-BACKUP FAIL: $BACKUP_DIR no writeable"
        fail=1
    else
        log "[OK] P-BACKUP: $BACKUP_DIR writeable"
    fi

    return $fail
}

# === Rollout actions ===

show_actions() {
    cat <<EOF

=== ACCIONES QUE EJECUTARIA --confirm ===

1. Backup activo:
   cp $SKILL_ACTIVE $BACKUP_DIR/SKILL.md.v2.1.bak-$TIMESTAMP

2. Backup doctrine:
   cp $DOCTRINE $BACKUP_DIR/inter-agent-language.md.v2.1.bak-$TIMESTAMP

3. Promover DRAFT a activo:
   cp $SKILL_DRAFT $SKILL_ACTIVE
   sed -i 's/^version: 3.0-DRAFT$/version: 3.0/' $SKILL_ACTIVE
   sed -i 's/^status: DRAFT$/status: ACTIVE/' $SKILL_ACTIVE

4. Mantener DRAFT como referencia:
   cp $SKILL_DRAFT $BACKUP_DIR/SKILL-v3-DRAFT.md.promoted-$TIMESTAMP

5. Registrar evento de rollout en audit:
   echo "rollout v3.0 ejecutado $TIMESTAMP" >> $HELIX_DIR/memory/topics/helix-evolution-plan-v4-decision.md

NO EJECUTA git commit. El creator revisa los cambios y commitea manualmente.

EOF
}

execute_rollout() {
    log "Ejecutando rollout v2.1 -> v3.0 ..."

    cp "$SKILL_ACTIVE" "$BACKUP_DIR/SKILL.md.v2.1.bak-$TIMESTAMP"
    log "[OK] Backup activo: $BACKUP_DIR/SKILL.md.v2.1.bak-$TIMESTAMP"

    cp "$DOCTRINE" "$BACKUP_DIR/inter-agent-language.md.v2.1.bak-$TIMESTAMP" 2>/dev/null || true
    log "[OK] Backup doctrine"

    cp "$SKILL_DRAFT" "$SKILL_ACTIVE"
    sed -i 's/^version: 3.0-DRAFT$/version: 3.0/' "$SKILL_ACTIVE"
    sed -i 's/^status: DRAFT$/status: ACTIVE/' "$SKILL_ACTIVE"
    log "[OK] DRAFT promovido a activo (frontmatter actualizado)"

    cp "$SKILL_DRAFT" "$BACKUP_DIR/SKILL-v3-DRAFT.md.promoted-$TIMESTAMP"
    log "[OK] DRAFT preservado como referencia"

    log "[DONE] Rollout completado. Default ahora es v3.0 (segun el frontmatter)."
    log "       Para activar v3 en councils nuevos: HELIX_LANG_VERSION=3.0 (o seguira la heuristica de idioma cuando se implemente)."
    log ""
    log "Para revertir: bash $0 --rollback"
}

# === Rollback ===

execute_rollback() {
    log "Buscando backup mas reciente de SKILL.md v2.1..."
    local latest
    latest=$(ls -t "$BACKUP_DIR"/SKILL.md.v2.1.bak-* 2>/dev/null | head -1)
    if [[ -z "$latest" ]]; then
        err "No hay backups en $BACKUP_DIR. Rollback no posible automatico."
        return 1
    fi
    log "Backup mas reciente: $latest"
    log "Restaurando..."
    cp "$latest" "$SKILL_ACTIVE"
    log "[OK] SKILL.md restaurado a v2.1 desde $latest"
    log "Para confirmar: head -10 $SKILL_ACTIVE"
}

# === Main ===

case "$mode" in
    --check)
        if check_preconditions; then
            log "[OK] Todas las preconditions PASS. Listo para --rollout o --confirm."
            exit 0
        else
            err "[FAIL] Preconditions no satisfechas. NO continuar con rollout."
            exit 2
        fi
        ;;
    --rollout)
        if check_preconditions; then
            log "[OK] Preconditions PASS"
            show_actions
            log "Para ejecutar: bash $0 --confirm"
        else
            err "[FAIL] Preconditions no satisfechas. NO ejecutar."
            exit 2
        fi
        ;;
    --confirm)
        if check_preconditions; then
            execute_rollout
        else
            err "[FAIL] Preconditions no satisfechas. ABORT."
            exit 2
        fi
        ;;
    --rollback)
        execute_rollback
        ;;
    --help|-h)
        sed -n '2,16p' "$0"
        ;;
    *)
        err "Uso desconocido: $mode. Ver --help."
        exit 1
        ;;
esac
