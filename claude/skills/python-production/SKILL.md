---
name: python-production
description: Python production-grade patterns — src/ layout, type hints strict, imports rules, config con pydantic, tests coverage, pre-commit gates, mlops-friendly structure. Usar al crear/refactorizar cualquier código Python que deba escalar (>100 líneas, >1 módulo, o con deps externas). Complementa clean-code con especificidades de Python 3.11+.
allowed-tools: Read, Write, Edit, Bash
version: 1.0
priority: HIGH
---

# Python Production — escalable, testeable, mantenible

> Reglas duras para código Python que debe sobrevivir a refactors, equipos multi-persona y ventanas de mantenimiento largas. Opus en "make it work" mode viola estas rutinariamente — este skill existe para prevenirlo.

---

## Reglas DURAS (no negociables)

### 1. Imports
- **TODOS los imports al top del módulo.** Jamás dentro de funciones, excepto con justificación explícita:
  - Dep opcional con fallback: `try: import optuna / HAS_OPTUNA = True / except ImportError: HAS_OPTUNA = False` a **nivel módulo**.
  - Romper ciclo de imports documentado en comentario.
  - "Para que sea lazy" → NO. Python cachea imports. Re-importar en cada call es overhead innecesario + rompe autocomplete + rompe testing con mocks.
- Orden (PEP 8 + `ruff isort`): stdlib → third-party → local. Cada grupo ordenado alfabéticamente, separados por línea en blanco.
- Prefer `from pkg import name` sobre `import pkg.sub.module as x` cuando se usa mucho.

### 2. Módulos — tamaño y responsabilidad
- **Máximo 300 líneas por módulo.** Si crece, split por responsabilidad.
- **SRP**: un módulo = un concepto. `train.py` entrena, `metrics.py` mide, `tracking.py` loguea.
- **God-scripts** (entrenar + preprocesar + loggear + reportar en 600 líneas) son anti-patrón: imposibles de testear, de cambiar, de reutilizar.

### 3. Packaging
- **`src/` layout obligatorio** para cualquier proyecto que supere 5 módulos relacionados.
  ```
  project/
  ├── src/mypkg/               # paquete instalable
  │   ├── __init__.py
  │   ├── data/
  │   ├── models/
  │   └── eval/
  ├── scripts/                 # CLI entry points SOLAMENTE (thin wrappers)
  ├── tests/
  │   ├── unit/
  │   └── integration/
  └── pyproject.toml           # [project.scripts] para CLIs
  ```
- `pip install -e .` (o `uv pip install -e .`). No `sys.path.insert` hacks.
- CLI = script delgado (≤50 líneas) que importa del paquete y orquesta.

### 4. Type hints
- **Todas las funciones públicas tipadas.** PEP 484/585/604.
  - Python 3.9+: `list[str]` no `List[str]`
  - Python 3.10+: `str | None` no `Optional[str]`
- `mypy --strict` en CI. Errores bloqueantes.
- Privadas (prefijo `_`) pueden omitir si son obvias.

### 5. Config
- **NUNCA** `os.environ.get("X", "5")` con cast manual. Usar `pydantic.BaseSettings` o `dataclass + dotenv`:
  ```python
  from pydantic_settings import BaseSettings

  class Config(BaseSettings):
      optuna_n_trials: int = 100
      lgbm_num_threads: int = 4
      mlflow_tracking_uri: str = "http://localhost:5000"
      model_config = {"env_prefix": "MME_"}
  ```
- Magic numbers → constantes con nombre o `Config`.

### 6. Tests
- **Coverage gate 75% mínimo.** `pytest --cov-fail-under=75` en CI.
- **Test por módulo**. Cada `src/mypkg/foo.py` tiene `tests/unit/test_foo.py`.
- Fixtures en `conftest.py` (raíz de tests/ + por subdir si aplica).
- Tests de integración separados (`tests/integration/`) — corren E2E con stack real.

### 7. Docstrings
- Google-style (único estándar). Enforced por `pydocstyle` en CI.
  ```python
  def train_model(X: pd.DataFrame, y: np.ndarray) -> ModelResult:
      """Entrena un modelo Poisson con offset.

      Args:
          X: Features engineered (ver `features_v1.json`).
          y: Target counts (≥0).

      Returns:
          ModelResult con modelo serializado + métricas val.

      Raises:
          ValueError: si y tiene valores negativos.
      """
  ```

### 8. No mutabilidad oculta
- Funciones NO mutan args. Si necesitan modificar, retornan copia.
- `pd.DataFrame` → `.copy()` antes de modificar.

### 9. Errores
- **Nunca** `except Exception: pass`. Loggear + re-raise o manejar específico.
- Custom exceptions por dominio (no usar `ValueError` para todo).

### 10. CLI entry points
- Usar `typer` o `click`, no `argparse` manual (ambos validan tipos automáticamente + autogeneran help).
- CLI script = import + parse args + call package function. Nada de lógica.

---

## Smell detectors (auto-audit rápido)

Antes de cerrar cualquier tarea Python:

```bash
# 1. Imports fuera de top (anti-pattern)
grep -rn "    import \| from " src/ | grep -v "^\s*#"

# 2. Módulos >300 líneas (revisar si hay god-script)
find src/ -name "*.py" -exec wc -l {} + | awk '$1 > 300 {print}'

# 3. Type hints coverage
mypy --strict src/ 2>&1 | grep -c "error:"

# 4. Funciones >30 líneas (candidates a split)
# (usar ruff C901 complexity o radon)
radon cc src/ -nB

# 5. Coverage actual
pytest --cov=src --cov-report=term-missing
```

Si ≥1 falla → NO cerrar, refactor primero.

---

## Stack de herramientas (project-level)

| Herramienta | Rol | Config |
|---|---|---|
| `ruff` | Lint + format + isort (reemplaza flake8+black+isort) | `[tool.ruff]` en pyproject |
| `mypy` | Type checking estricto | `mypy --strict` |
| `pytest` | Testing | `--cov`, fixtures, `pytest.ini` |
| `pydantic` | Config + validación | `BaseSettings` |
| `pre-commit` | Gates locales | `.pre-commit-config.yaml` |
| `typer` | CLI | reemplaza argparse |
| `uv` | Package manager | lockfile reproducible |

---

## Patrones por tipo de proyecto

### ML / MLOps

```
src/mme/
├── config.py                 # pydantic Settings
├── data/
│   ├── loaders.py            # cargadores por fuente
│   └── preprocessing.py      # transforms reutilizables
├── features/
│   ├── selection.py          # LASSO, MI, PCA pipelines
│   └── augmentation.py       # offset → feature, encodings
├── models/
│   ├── base.py               # Protocol ModelResult, BaseModel ABC
│   ├── glm_negbin.py         # 1 modelo = 1 archivo
│   └── lgbm_poisson.py
├── eval/
│   ├── metrics.py            # puro cálculo, sin I/O
│   └── explainability.py     # SHAP helpers
├── tracking/
│   ├── mlflow_client.py      # encapsula lib MLflow
│   └── artifacts.py          # serialización
└── orchestration/
    └── pipelines.py          # orquesta los módulos anteriores
```

**Regla ML-específica:** `train()` retorna `ModelResult` puro; el logging a MLflow es una call SEPARADA (`log_result(result, experiment)`). Facilita testear training sin mockear MLflow.

### FastAPI / Backend

```
src/api/
├── config.py
├── main.py                   # app factory
├── routers/                  # 1 router por recurso
├── services/                 # business logic
├── repositories/             # persistencia
├── schemas/                  # pydantic request/response
└── deps.py                   # DI (database, auth, etc.)
```

---

## Recursos de lectura (en orden de prioridad)

1. **"Architecture Patterns with Python"** — Percival & Gregory, O'Reilly 2020 · cosmicpython.com (libre)
   - DDD, hexagonal, Repository + Unit of Work patterns aplicados a Python
2. **"Robust Python"** — Patrick Viafore, O'Reilly 2021
   - Type hints avanzados, Protocols, manejo de complejidad
3. **"Fluent Python" 2ª ed** — Luciano Ramalho, O'Reilly 2022
   - Idioms modernos, dataclasses, typing, async
4. **"Effective Python" 2ª ed** — Brett Slatkin, Addison-Wesley 2019
   - 90 items específicos con antes/después
5. **"Designing Machine Learning Systems"** — Chip Huyen, O'Reilly 2022
   - MLOps real, system design, feature stores, monitoring
6. **Google Python Style Guide** — https://google.github.io/styleguide/pyguide.html
   - Usado internamente por Google; docstrings Google-style nacen aquí
7. **Hypermodern Python** — cjolowicz.github.io/posts/hypermodern-python-01-setup/
   - Template proyecto Python moderno end-to-end
8. **scikit-learn Developer Guide** — https://scikit-learn.org/stable/developers/
   - Gold standard de APIs ML reutilizables (fit/transform/predict contracts)

**PEPs imprescindibles:**
- PEP 8 (style), 257 (docstrings), 484/585/604 (typing)
- PEP 517/518/621 (packaging moderno, pyproject.toml)
- PEP 695 (generics nuevos 3.12+)

**Podcast / comunidades:**
- Talk Python Podcast (Michael Kennedy)
- Real Python (realpython.com)
- Python Bytes (novedades semanales)

---

## Cuándo invocar este skill

- Al crear cualquier proyecto Python nuevo > 5 módulos
- Al refactorizar código legacy con deuda técnica
- Al revisar PRs Python
- Cuando el usuario mencione "calidad", "escalable", "mantenible", "mejores prácticas"
- Antes de declarar tarea Python completa (auto-check contra la lista de smells)

## Cuándo NO invocar

- Scripts one-shot de <100 líneas que van a tirarse
- Notebooks exploratorios (otras reglas aplican)
- Debug rápido de un bug puntual

---

## Auto-evaluación antes de cerrar

Antes de marcar completa cualquier tarea que tocó código Python:

```
□ Imports todos al top del módulo
□ Ningún módulo > 300 líneas
□ Type hints en todas las funciones públicas
□ mypy --strict sin errores en código nuevo
□ ruff check sin warnings en código nuevo
□ Tests unitarios para nueva lógica
□ Coverage no bajó respecto del baseline
□ Docstrings Google-style en funciones públicas
□ Config via pydantic Settings, no env directo
□ CLI script (si aplica) ≤ 50 líneas (thin wrapper)
□ No `except Exception: pass`
□ Sin imports dentro de funciones (con excepción documentada)
```

Si ≥2 fallan → el código NO está listo, sin importar que "funcione".
