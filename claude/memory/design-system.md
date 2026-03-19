# Sistema de Diseño UI — CLIENTE_PRIVADO
> Extraído de CLAUDE.md. Cargar cuando se trabaje en componentes frontend o páginas.

## Filosofía: "Precision Craft"
Diseño refinado y editorial — espacios con propósito, sin componentes genéricos.
Referentes: Linear.app, Vercel Dashboard, Raycast.

## ⚠️ Regla fundamental: MOBILE-FIRST SIEMPRE
Todo componente y página se diseña primero para móvil (320px–430px) y luego escala a escritorio.
Nunca diseñar solo para desktop y "adaptar" después — eso produce resultados mediocres.

- Breakpoints en orden ascendente: base (móvil) → `sm:` (640px) → `md:` (768px) → `lg:` (1024px) → `xl:` (1280px)
- Touch targets mínimo **44×44px** en móvil (botones, íconos, links)
- Nunca usar hover como única forma de revelar información — en móvil no existe
- Navegación: drawer o bottom nav en móvil, sidebar en desktop
- Tablas complejas: en móvil convertir a cards apiladas, no scroll horizontal
- Modales: bottom-sheet full-width en móvil, centrado con overlay en desktop
- Inputs y selects: `font-size` mínimo **16px** en móvil para evitar zoom automático en iOS

## Stack UI de este proyecto
- **Tailwind CSS v4** — usar sintaxis v4 (`@theme`, `@utility`). Consultar **Context7 MCP** antes de usar cualquier feature nueva.
- **Recharts** — siempre con `<ResponsiveContainer width="100%" />` para que los gráficos sean responsivos
- **react-day-picker** — estilizar con Tailwind, NO importar estilos externos del paquete
- **Componentes custom** — botones, modales, tablas, inputs: CSS propio con Tailwind, sin librerías de componentes UI

## Paleta de Color
Definir en el CSS global del proyecto:

```css
:root {
  /* Fondos */
  --bg:        #0a0a0f;
  --surface:   #111118;
  --surface-2: #1a1a24;

  /* Bordes */
  --border:        #ffffff10;
  --border-strong: #ffffff20;

  /* Texto */
  --text-1: #f0f0f5;   /* Principal */
  --text-2: #8888aa;   /* Secundario */
  --text-3: #55556a;   /* Muted */

  /* Acento — usar con disciplina, no en todo */
  --accent:      #6c63ff;
  --accent-glow: #6c63ff40;
  --accent-soft: #6c63ff15;

  /* Semánticos */
  --success: #22c55e;
  --warning: #f59e0b;
  --danger:  #ef4444;
  --info:    #38bdf8;
}
```

## Tipografía
```css
/* Importar en index.html o CSS global */
@import url('https://fonts.googleapis.com/css2?family=Geist:wght@300;400;500;600;700&family=Geist+Mono:wght@400;500&display=swap');
```

| Uso | Clase Tailwind | Peso | Nota móvil |
|---|---|---|---|
| Título de página | `text-2xl` | 600 | `text-xl` en móvil |
| Sección / Card title | `text-base` | 500 | — |
| Cuerpo | `text-sm` | 400 | — |
| Metadatos / Labels | `text-xs` | 400 | — |
| Código | `font-mono text-xs` | 400 | — |
| Input / Select | `text-base` | 400 | Mínimo 16px para evitar zoom iOS |

## Animaciones — Reglas
- `transition duration-150` → feedback inmediato: botones, inputs, checkboxes
- `transition duration-300` → transiciones de layout: modales, drawers, tooltips
- `transition duration-500` → entradas de página, elementos hero, skeletons
- En móvil respetar siempre `prefers-reduced-motion`:

```css
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    transition-duration: 0.01ms !important;
  }
}
```

## Patrones de Componentes Responsivos

**Botones**
```tsx
// Full-width en móvil, auto en desktop
<button className="w-full sm:w-auto px-4 py-3 sm:py-2 text-base sm:text-sm ...">
```

**Grids**
```tsx
// 1 col móvil → 2 cols tablet → 3 cols desktop
<div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
```

**Navegación**
```tsx
// Sidebar oculto en móvil, visible en desktop
<nav className="hidden lg:flex flex-col w-64 ..."> {/* Desktop sidebar */}
// Bottom nav en móvil
<nav className="fixed bottom-0 inset-x-0 flex lg:hidden ..."> {/* Mobile */}
```

**Tablas → Cards en móvil**
```tsx
// Desktop: tabla. Móvil: cards apiladas
<div className="hidden md:block"><table>...</table></div>
<div className="md:hidden space-y-3">
  {rows.map(r => <CardRow key={r.id} {...r} />)}
</div>
```

**Modales**
```tsx
// Desktop: centrado. Móvil: bottom-sheet
<div className="fixed inset-0 flex items-end sm:items-center justify-center">
  <div className="w-full sm:max-w-md rounded-t-2xl sm:rounded-2xl bg-[--surface] p-6">
```

## Reglas de Diseño — NO negociables
- ❌ Nunca usar Inter, Roboto, Arial o fuentes genéricas del sistema
- ❌ Nunca gradientes púrpura sobre fondo blanco
- ❌ Nunca diseñar solo para desktop y adaptar después — **mobile-first siempre**
- ❌ Nunca información accesible solo por hover
- ✅ Micro-animaciones en hover/focus/active con `transition`
- ✅ Inputs: borde `--border`, focus ring `--accent` con glow suave
- ✅ Usar **Puppeteer MCP** para tomar screenshot y verificar resultado visual
- ✅ Usar **Browser Tools MCP** para debuggear errores de consola y animaciones

## Herramientas MCP para Diseño
| MCP | Cuándo usarlo |
|---|---|
| **Context7** | Antes de usar cualquier feature de Tailwind v4 o API de animación |
| **Puppeteer** | Para screenshot y verificar resultado visual en desktop y móvil |
| **Browser Tools** | Para inspeccionar errores JS, consola y auditar accesibilidad |
| **Sequential Thinking** | Al diseñar componentes complejos — razonar layout antes de codear |

## Checklist de diseño antes de entregar un componente
```
□ ¿Se ve bien en 375px (iPhone SE / móvil pequeño)?
□ ¿Se ve bien en 768px (tablet)?
□ ¿Se ve bien en 1280px (desktop)?
□ ¿Los touch targets son ≥ 44px en móvil?
□ ¿Los inputs tienen font-size ≥ 16px (sin zoom iOS)?
□ ¿Las animaciones respetan prefers-reduced-motion?
□ ¿Usé Puppeteer MCP para verificar visualmente?
□ ¿No hay información solo accesible por hover?
□ ¿Las tablas se convierten en cards en móvil?
□ ¿Los modales son bottom-sheet en móvil?
```

Al registrar aprendizajes de diseño usar categoría: `interfaz`
