# Skill: mlops-gitops-deploy
> Auto-generada por el agente el 2026-06-29 18:08
> **Descripción:** Playbook MLOps en k8s/microk8s + ArgoCD (app-of-apps) con loop CI->CD por GitOps. Cubre: deploy.sh por fases que genera secrets desde .env (imagePullSecret, pgAdmin servers.json+pgpass, datasources Grafana, TLS) sin commitearlos; build-and-push + bump-image-tags (bump SOLO desde rama default) que pinnea :short-sha y ArgoCD despliega; destroy.sh que borra Apps antes del namespace (evita selfHeal); Evidently con sidecar TLS; gotchas WSL (DNS svc corto, node-exporter shared mount). Invocar al desplegar/operar un pipeline ML en k8s con GitOps.

## Cuándo usar esta skill
<!-- Completar con el agente -->

## Patrón / Solución

<!-- El agente completará esto -->

## Ejemplos de uso
<!-- El agente agrega ejemplos reales del proyecto -->

## Dependencias
<!-- Skills relacionadas -->

## Historial de cambios
| Versión | Fecha | Cambio |
|---|---|---|
| v1.0 | 2026-06-29 | Creación inicial |
