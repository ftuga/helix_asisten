# Skill: react-query-patterns
> Auto-generada · Versión v1.0
> **Descripción:** Patrones React Query + Zustand + Axios para el frontend de CLIENTE_PRIVADO

## Cuándo usar esta skill
- Al agregar nuevas queries o mutaciones al frontend
- Al gestionar estado de autenticación
- Al agregar nuevos métodos a la API

## Estructura de api/index.ts

```typescript
// ✅ SIEMPRE agregar métodos aquí — nunca fetch directo
export const retirosApi = {
  list: (params?) => axios.get('/api/retiros', { params }).then(r => r.data),
  get: (id: string) => axios.get(`/api/retiros/${id}`).then(r => r.data),
  create: (data: RetiroCreate) => axios.post('/api/retiros', data).then(r => r.data),
  update: (id: string, data: RetiroUpdate) => axios.put(`/api/retiros/${id}`, data).then(r => r.data),
  cerrarEtapa: (id: string, area: string) =>
    axios.post(`/api/retiros/${id}/etapas/${area}/cerrar`).then(r => r.data),
  reabrirEtapa: (id: string, area: string) =>
    axios.delete(`/api/retiros/${id}/etapas/${area}/cerrar`).then(r => r.data),
};
```

## Patrones React Query

```typescript
// Query básica
const { data: retiro, isLoading, error } = useQuery({
  queryKey: ['retiro', id],
  queryFn: () => retirosApi.get(id!),
  enabled: !!id,
});

// Mutación con invalidación
const toggleTarea = useMutation({
  mutationFn: ({ tareaId, completada }: { tareaId: string; completada: boolean }) =>
    tareasApi.toggle(retiroId, tareaId, completada),
  onSuccess: () => {
    queryClient.invalidateQueries({ queryKey: ['retiro', retiroId] });
  },
});
```

## Zustand Auth Store

```typescript
// store/auth.ts — patrón de uso
const { user, token, logout } = useAuthStore();

// ✅ Detección de admin
if (user?.rol === 'admin') { /* acceso total */ }

// ⛔ NUNCA
if (user?.area === 'admin') { /* admin es rol, no área */ }

// Rehydration al cargar la app
useEffect(() => {
  useAuthStore.getState().loadUser(); // Valida token existente
}, []);
```

## ProtectedRoute Pattern

```tsx
// App.tsx
<Route path="/retiros/nuevo" element={
  <ProtectedRoute allowedAreas={['rrhh']} allowedRoles={['admin']}>
    <NuevoRetiroPage />
  </ProtectedRoute>
} />

// ProtectedRoute — admin SIEMPRE pasa
const canAccess = user?.rol === 'admin' ||
  (allowedAreas?.includes(user?.area) || allowedRoles?.includes(user?.rol));
```

## Compras — Casos Especiales

```typescript
// Reportes de compras: usar retirosApi.list(), NO reportesApi.porArea()
// (reportes por área devuelve vacío para compras que no tienen tareas)
const { data } = useQuery({
  queryKey: ['reportes-compras'],
  queryFn: () => retirosApi.list({ con_activos: true }),
  enabled: user?.area === 'compras',
});

// Dashboard/historial compras: solo retiros con activos_pendientes > 0
const retirosFiltrados = retiros?.filter(r =>
  user?.area !== 'compras' || r.activos_pendientes > 0
);
```

## Dependencias
- Ninguna (skill base frontend)

## Historial de cambios
| Versión | Fecha | Cambio |
|---|---|---|
| v1.0 | INIT | Patrones principales del proyecto |
