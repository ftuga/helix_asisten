# Helix Team — [NOMBRE DEL PROYECTO]
> Generado: [FECHA] por /helix-analiza | Actualizar con: /helix-actualiza

## Equipo Activo

| Rol | Agente | Dominio | Archivos típicos |
|---|---|---|---|
| — | — | — | Completar con /helix-analiza |

## Output Contracts

> Define qué produce cada agente y quién lo consume.
> Sin esto, el paralelismo en Capa 2 se rompe en el handoff.

| Agente productor | Produce | Lo consume |
|---|---|---|
| backend-architect | OpenAPI spec, endpoint types, schema decisions | frontend-developer, test-engineer, typescript-pro |
| database-architect | Schema migrations, model definitions | python-pro, postgresql-dba, frontend-developer (types) |
| python-pro | Endpoint implementado, response models | test-engineer, frontend-developer |
| ui-designer | Tokens, componentes visuales, specs | frontend-developer |
| frontend-developer | Componentes, pages, types | test-engineer |

> Completar con los contratos reales del proyecto al ejecutar /helix-analiza.

## MCPs Activos para este proyecto

| MCP | Para qué | Estado |
|---|---|---|
| context7 | Documentación de libs del stack | pendiente verificar |

## Definition of Done

- [ ] Tests escritos y pasando para el cambio
- [ ] code-reviewer aprobó antes de cerrar
- [ ] Sin secrets ni variables hardcodeadas
- [ ] helix-bitacora.md actualizado
- [ ] Si UI → verificado con puppeteer en 375px, 768px, 1280px
- [ ] Si endpoint nuevo → registrado en router principal

## Protocolo de Despacho

Cuando el requerimiento toca ≥2 dominios:
1. Identificar dominios afectados (leer tabla Equipo Activo)
2. Mapear output contracts: ¿qué necesita cada agente del anterior?
3. Si 1 dominio → Capa 1: Agent tool directo
4. Si 2+ dominios sin dependencias → Capa 2: swarm_init + agent_spawn en paralelo
5. Si 2+ dominios con dependencias (ver Output Contracts) → Capa 1 secuencial
6. Cada agente recibe: requerimiento + su output contract de entrada
7. Al terminar: actualizar helix-backlog.md con resultado
