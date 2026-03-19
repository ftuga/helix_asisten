# Skill: azure-auth
> Auto-generada · Versión v1.0
> **Descripción:** Flujo completo Azure AD SSO → JWKS → JWT interno para CLIENTE_PRIVADO

## Cuándo usar esta skill
- Al modificar el flujo de autenticación
- Al agregar nuevos campos al token JWT
- Al depurar problemas de login con Microsoft 365

## Flujo Completo

```
MSAL Frontend → Azure AD → id_token
    → POST /api/auth/login { id_token }
    → Backend valida JWKS (cacheado 1h en memoria)
    → Busca user por azure_oid → fallback por email
    → Devuelve { access_token, refresh_token, user }
    → Zustand guarda en localStorage
    → Axios interceptor renueva en 401
```

## ⚠️ Reglas Críticas

```typescript
// ❌ NUNCA para detectar admin
if (user.area === 'admin') { ... }

// ✅ SIEMPRE
if (user.rol === 'admin') { ... }
```

```python
# Backend: usuario DEBE existir antes del primer login
# No hay auto-registro — insertar manualmente o via AdminPage
user = db.query(User).filter(User.azure_oid == oid).first()
if not user:
    user = db.query(User).filter(User.email == email).first()
    # Si user es None → 401 Unauthorized
```

## Configuración Azure Portal

1. Azure AD → App Registrations → New Registration
2. Redirect URI: `https://retiros.cliente_privado.com/auth/callback` (SPA)
3. Authentication → Enable **ID tokens** (Implicit grant)
4. Copiar `Application (client) ID` y `Directory (tenant) ID` → `.env`

## Refresh Token Flow (Axios)

```typescript
// api/index.ts — interceptor auto-refresh
axios.interceptors.response.use(
  res => res,
  async err => {
    if (err.response?.status === 401 && !err.config._retry) {
      err.config._retry = true;
      try {
        const { data } = await axios.post('/api/auth/refresh', { refresh_token });
        // Guardar nuevos tokens en Zustand
        return axios(err.config);
      } catch {
        // Limpiar localStorage y redirigir a /
        useAuthStore.getState().logout();
      }
    }
    return Promise.reject(err);
  }
);
```

## Modo Test (solo local)

```bash
POST /api/auth/login/test
{ "email": "admin@test.com", "password": "‹credencial-redactada›" }
# ⛔ ELIMINAR antes de producción
```

## Dependencias
- Ninguna (skill base)

## Historial de cambios
| Versión | Fecha | Cambio |
|---|---|---|
| v1.0 | INIT | Flujo completo documentado |
