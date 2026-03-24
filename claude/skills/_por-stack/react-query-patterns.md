# Skill: react-query-patterns
> Versión v2.0 — Patrones genéricos
> **Descripción:** Patrones React Query + Zustand + Axios para frontends React/TypeScript

## Cuándo usar esta skill
- Al agregar nuevas queries o mutaciones al frontend
- Al gestionar estado de autenticación
- Al agregar nuevos métodos a la API

## Estructura de api/index.ts

```typescript
// ✅ SIEMPRE agregar métodos aquí — nunca fetch directo desde componentes
export const itemsApi = {
  list: (params?) => axios.get('/api/items', { params }).then(r => r.data),
  get: (id: string) => axios.get(`/api/items/${id}`).then(r => r.data),
  create: (data: ItemCreate) => axios.post('/api/items', data).then(r => r.data),
  update: (id: string, data: ItemUpdate) => axios.put(`/api/items/${id}`, data).then(r => r.data),
  delete: (id: string) => axios.delete(`/api/items/${id}`).then(r => r.data),
};
```

## Patrones React Query

```typescript
// Query básica
const { data: item, isLoading, error } = useQuery({
  queryKey: ['item', id],
  queryFn: () => itemsApi.get(id!),
  enabled: !!id,
});

// Mutación con invalidación de cache
const updateItem = useMutation({
  mutationFn: ({ id, data }: { id: string; data: ItemUpdate }) =>
    itemsApi.update(id, data),
  onSuccess: (_, { id }) => {
    // ✅ Invalidar ANTES de navigate() en mutaciones destructivas
    queryClient.invalidateQueries({ queryKey: ['item', id] });
    queryClient.invalidateQueries({ queryKey: ['items'] });
  },
});
```

## Zustand Auth Store

```typescript
// store/auth.ts — patrón de uso
const { user, token, logout } = useAuthStore();

// ✅ Chequeo de roles
if (user?.role === 'admin') { /* acceso total */ }

// ⛔ NUNCA mezclar role con area/department
if (user?.area === 'admin') { /* admin es rol, no área */ }

// Rehydration al cargar la app
useEffect(() => {
  useAuthStore.getState().loadUser(); // Valida token existente en localStorage
}, []);
```

## ProtectedRoute Pattern

```tsx
// App.tsx — protección por rol y/o área
<Route path="/admin" element={
  <ProtectedRoute allowedRoles={['admin']}>
    <AdminPage />
  </ProtectedRoute>
} />

// ProtectedRoute — admin SIEMPRE pasa
const canAccess = user?.role === 'admin' ||
  allowedAreas?.includes(user?.area) ||
  allowedRoles?.includes(user?.role);
```

## Regla clave: invalidar ANTES de navegar

```typescript
// ❌ MAL — navega antes de que el cache se actualice
onSuccess: () => {
  navigate('/items');
  queryClient.invalidateQueries({ queryKey: ['items'] });
}

// ✅ BIEN — primero invalida, luego navega
onSuccess: () => {
  queryClient.invalidateQueries({ queryKey: ['items'] });
  navigate('/items');
}
```

## Historial de cambios
| Versión | Fecha | Cambio |
|---|---|---|
| v2.0 | 2026-03-24 | Generalizado — eliminadas referencias a proyecto específico |
| v1.0 | INIT | Patrones iniciales |
