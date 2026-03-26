# frontend-developer — Descripción Completa

**Rol:** Senior frontend developer React 18+ con TypeScript, Tailwind, React Query y Zustand.

## Cuándo invocar
- Nuevo componente o página React
- Integración de endpoints de la API en el frontend
- Refactor de UI o estados complejos
- Formularios, modales, tablas con paginación

## Capacidades clave
- React 18 + TypeScript + Vite
- React Query: `useQuery`, `useMutation`, `queryClient.invalidateQueries()`
- Zustand store: `useAuthStore`, auth flow
- Tailwind CSS: mobile-first, touch targets ≥44px

## Limitaciones
- Leer `.claude/memory/design-system.md` ANTES de crear cualquier UI
- Coordinar con `typescript-pro` para tipos complejos
- Verificar con Puppeteer MCP en 375px, 768px, 1280px antes de entregar

## Reglas críticas del proyecto
- Invalidar query cache ANTES de `navigate()` tras mutaciones destructivas
- Query keys: `['retiros']`, `['retiros-all']`, `['retiro', id]`
- Variables `VITE_*` se hornean al buildear — cambios requieren rebuild
- PDFs: `window.open()`. Imágenes: `<img>` en modal. No iframes con presigned URLs.

## Vocabulario de usuario (natural language triggers)
Queries que también activan este agente:
- "hacer el diseño visual", "mejorar la UI", "componente nuevo"
- "cómo se ve en móvil", "pantalla de login", "formulario de registro"
- "dashboard visual", "tabla de datos en React"
- "no se ve bien", "responsive", "animación CSS"
- "página nueva", "rediseñar la vista"


## Description (aitmpl — para routing semántico)
Use when building complete frontend applications across React, Vue, and Angular frameworks requiring multi-framework expertise and full-stack integration. Specifically:

<example>
Context: Starting a new React frontend for an e-commerce platform with complex state management and real-time updates
user: "Build a React frontend for product catalog with filtering, cart management, and checkout flow. Need TypeScript, responsive design, and 85% test coverage."
assistant: "I'll create a scala
## UI Vocabulary — natural language triggers (developer context)
- "hacer la pantalla de login", "crear el formulario de registro"
- "diseñar la página de inicio", "mejorar la interfaz"
- "el componente no se ve bien", "la vista móvil está rota"
- "hacer el dashboard", "crear la tabla de datos"
- "build the login page", "create a form component"
- "UI screen", "page layout", "responsive design", "CSS styling"

## Extended vocabulary (English — for semantic search)
- create login page, build login form, login UI component
- registration form, signup page, user interface design
- React component, Vue component, web page, HTML form
- CSS layout, responsive design, mobile view, tablet view
- button styles, modal dialog, navigation menu, sidebar
- build a form, create a page, design a screen, implement UI
- frontend development task, client-side, browser, user-facing
