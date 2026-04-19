#!/usr/bin/env bash
# helix-longmemeval.sh — Probe de recall para helix_reflexions (Qdrant).
# Inspirado en LongMemEval: mide precision@k, MRR y recall de memoria semántica.
# Uso:
#   helix-longmemeval.sh build              — genera dataset de prueba desde reflexions.jsonl
#   helix-longmemeval.sh run [threshold]    — ejecuta probe, reporta métricas
#   helix-longmemeval.sh compare <thr1> <thr2>  — A/B de 2 thresholds
set -uo pipefail

GLOBAL_DIR="$HOME/.claude"
HV="$GLOBAL_DIR/helix-vector.py"
QDRANT_URL="${QDRANT_URL:-http://localhost:6333}"
DATASET="$GLOBAL_DIR/data/longmemeval-dataset.jsonl"
mkdir -p "$(dirname "$DATASET")"

cmd="${1:-run}"
shift || true

BLUE="\033[0;34m"; GREEN="\033[0;32m"; YELLOW="\033[0;33m"; RED="\033[0;31m"; NC="\033[0m"

_qdrant_up() { curl -sf "$QDRANT_URL/healthz" &>/dev/null; }

case "$cmd" in

build)
    # Construye pares (query variant, expected_error_id) desde reflexions existentes.
    # Genera 3 variantes por reflexión: literal, paráfrasis corta, pregunta.
    REFLEXIONS="$GLOBAL_DIR/memory/reflexions.jsonl"
    [[ ! -f "$REFLEXIONS" ]] && { echo "Sin reflexions.jsonl para construir dataset"; exit 1; }

    export HV_REFLEXIONS="$REFLEXIONS" HV_DATASET="$DATASET"
    python3 <<'PYEOF'
import os, json
from pathlib import Path

src = Path(os.environ["HV_REFLEXIONS"])
dst = Path(os.environ["HV_DATASET"])
count = 0

with open(dst, "w") as out:
    for line in open(src):
        line = line.strip()
        if not line: continue
        try:
            r = json.loads(line)
        except: continue
        err = (r.get("error") or "")[:200].strip()
        if not err or len(err) < 20: continue
        # Variantes de query
        variants = [
            err,                                          # literal
            " ".join(err.split()[:10]),                   # primeras 10 palabras
            f"cómo resolver: {err[:80]}",                 # pregunta en español
            f"how to fix {' '.join(err.split()[:8])}",    # pregunta en inglés
        ]
        gold = err[:100]  # señal de oro para matching: substring del error
        for v in variants:
            out.write(json.dumps({"query": v, "expected_error_prefix": gold, "category": r.get("categoria", "")}, ensure_ascii=False) + "\n")
            count += 1

print(f"✅ Dataset generado: {count} queries a partir de {src.name}")
print(f"   → {dst}")
PYEOF
    ;;

run)
    THRESHOLD="${1:-0.65}"
    TOP_K="${2:-3}"

    [[ ! -f "$DATASET" ]] && { echo "No hay dataset. Ejecutá: helix-longmemeval.sh build"; exit 1; }
    _qdrant_up || { echo "Qdrant DOWN"; exit 1; }

    export HV_DATASET="$DATASET" HV_THRESHOLD="$THRESHOLD" HV_TOP_K="$TOP_K" HV_SCRIPT="$HV"
    python3 <<'PYEOF'
import os, json, subprocess, sys, time

dataset_path = os.environ["HV_DATASET"]
threshold = os.environ["HV_THRESHOLD"]
top_k = os.environ["HV_TOP_K"]
hv = os.environ["HV_SCRIPT"]

queries = [json.loads(l) for l in open(dataset_path) if l.strip()]
if not queries:
    print("Dataset vacío"); sys.exit(1)

total = len(queries)
hits_at_1 = 0
hits_at_k = 0
mrr_sum = 0.0
miss = 0
latencies = []

for i, q in enumerate(queries):
    query = q["query"]
    gold = q["expected_error_prefix"].lower().replace("_", " ")
    t0 = time.time()
    try:
        r = subprocess.run(
            ["python3", hv, "search", "helix_reflexions", query, "--top-k", top_k, "--threshold", threshold],
            capture_output=True, text=True, timeout=15
        )
        data = json.loads(r.stdout) if r.stdout else {"results": []}
    except Exception as e:
        miss += 1; continue
    latencies.append(time.time() - t0)
    results = data.get("results", [])
    found_rank = None
    for rank, res in enumerate(results, 1):
        pl = res.get("payload", {}) or {}
        err = (pl.get("error") or pl.get("text", "")).lower().replace("_", " ")
        # Match por substring: primeras 40 letras del gold deben estar en el resultado
        key = gold[:40]
        if key and key in err:
            found_rank = rank; break
    if found_rank == 1: hits_at_1 += 1; hits_at_k += 1; mrr_sum += 1.0
    elif found_rank and found_rank <= int(top_k):
        hits_at_k += 1; mrr_sum += 1.0 / found_rank
    else:
        miss += 1

p_at_1 = hits_at_1 / total * 100
p_at_k = hits_at_k / total * 100
mrr = mrr_sum / total
p95 = sorted(latencies)[int(len(latencies)*0.95)] if latencies else 0
avg_lat = sum(latencies) / len(latencies) if latencies else 0

BLUE="\033[0;34m"; GREEN="\033[0;32m"; YELLOW="\033[0;33m"; RED="\033[0;31m"; NC="\033[0m"
print(f"\n{BLUE}⬡ Helix LongMemEval — threshold={threshold} top_k={top_k}{NC}")
print(f"  Queries:     {total}")
print(f"  Precision@1: {p_at_1:5.1f}%  ({hits_at_1}/{total})")
print(f"  Precision@k: {p_at_k:5.1f}%  ({hits_at_k}/{total})")
print(f"  MRR:         {mrr:5.3f}")
print(f"  Misses:      {miss}")
print(f"  Latency avg: {avg_lat*1000:.0f}ms  p95: {p95*1000:.0f}ms")

# Benchmark reference (LongMemEval ICLR 2025):
# OMEGA 95.4 · Mastra 94.9 · Emergence 86 · Zep 71.2
if p_at_k >= 90: verdict = f"{GREEN}✅ Rango OMEGA/Mastra (≥90%){NC}"
elif p_at_k >= 70: verdict = f"{GREEN}✅ Rango Zep (≥70%){NC}"
elif p_at_k >= 50: verdict = f"{YELLOW}⚠️  Mediocre — tunear threshold o mejorar embeddings{NC}"
else: verdict = f"{RED}🚨 Bajo — revisar calidad de reflexiones almacenadas{NC}"
print(f"  Veredicto:   {verdict}")
PYEOF
    ;;

compare)
    T1="${1:-0.55}"
    T2="${2:-0.75}"
    echo -e "${BLUE}A/B thresholds $T1 vs $T2${NC}"
    bash "$0" run "$T1" 2>&1
    echo
    bash "$0" run "$T2" 2>&1
    ;;

*)
    echo -e "${BLUE}helix-longmemeval.sh — Probe de recall para helix_reflexions${NC}"
    echo ""
    echo "Comandos:"
    echo "  build                          Genera dataset desde reflexions.jsonl"
    echo "  run [threshold=0.65] [top_k=3] Ejecuta evaluación"
    echo "  compare <thr1> <thr2>          A/B de thresholds"
    ;;
esac
