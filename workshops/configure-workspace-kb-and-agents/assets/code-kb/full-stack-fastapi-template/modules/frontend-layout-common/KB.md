# frontend-layout-common

## Purpose

Provides the shared application chrome used across all authenticated views: the sidebar (navigation, user menu, appearance toggle) and a set of cross-feature building blocks (AuthLayout, DataTable, Logo, Footer, error/404 pages). Also owns the `ThemeProvider`/`useTheme` context that drives the global light/dark/system theme.

## Public Interface

### Sidebar

| Component | Role |
|-----------|------|
| `AppSidebar` | Root sidebar wrapper; composes Main, User, Appearance, Logo |
| `Main` | Navigation menu; renders dashboard, items, and admin links with active-route highlighting |
| `User` | User dropdown in sidebar footer; avatar, settings link, logout |

### Common

| Component | Role |
|-----------|------|
| `AuthLayout` | Two-column wrapper for public auth pages; embeds Logo and Footer |
| `DataTable<TData, TValue>` | Generic paginated table — accepts `columns: ColumnDef<TData,TValue>[]` and `data: TData[]`; used by all feature `columns.tsx` files |
| `Appearance` / `SidebarAppearance` | Light/dark/system toggle for standalone or sidebar contexts |
| `Footer` | Copyright notice and social media links |
| `Logo` | Responsive logo with light/dark theme variants |
| `ErrorComponent` | Full-page error display with home button |
| `NotFound` | 404 page with home button |

### Theme provider

| Export | Role |
|--------|------|
| `ThemeProvider` | Context provider; persists theme to `localStorage`, responds to OS media query |
| `useTheme` | Hook consumed by Logo, Appearance, and any component needing current theme |
| `Theme` | Union type `"light" \| "dark" \| "system"` |

## Internal Structure

```
frontend/src/components/
  Common/          # AuthLayout, DataTable, Appearance, Footer, Logo,
                   #   ErrorComponent, NotFound
  Sidebar/         # AppSidebar, Main, User
  theme-provider.tsx
```

`Common/` holds stateless or lightly stateful UI building blocks. `Sidebar/` holds the three components that together form the left-nav chrome. `theme-provider.tsx` is a standalone context module with no sub-directory.

## Dependencies

| Dependency | Used by |
|------------|---------|
| `frontend-ui-primitives` (shadcn: sidebar, table, avatar, button, dropdown-menu, select) | AppSidebar, Main, User, DataTable |
| `next-themes` / custom `theme-provider` | Appearance, Logo, ThemeProvider |
| `@tanstack/react-router` | Main, User, Logo, ErrorComponent, NotFound (Link/useNavigate) |
| `@tanstack/react-table` | DataTable (ColumnDef, useReactTable) |
| `useAuth` (`@/hooks/useAuth`) | AppSidebar (nav item visibility), User (current user + logout) |
| `react-icons` | Footer |

## Conventions

- **DataTable** is the single shared table component. Feature modules supply a `columns.tsx` that exports `ColumnDef[]`; they pass it alongside their data array to `<DataTable columns={columns} data={data} />`. DataTable owns pagination entirely (rows-per-page select, first/prev/next/last buttons).
- **Theme** flows through `ThemeProvider` (mounted at app root) and read via `useTheme`. No component imports a raw `next-themes` hook directly — they all go through the re-exported `useTheme` from `theme-provider.tsx`.
- **AuthLayout** is the standard shell for all public (unauthenticated) pages (`/login`, `/signup`, etc.). Authenticated pages use the sidebar layout instead.

## Files

| Path | Role |
|------|------|
| `frontend/src/components/Common/AuthLayout.tsx` | Two-column auth page shell |
| `frontend/src/components/Common/DataTable.tsx` | Generic paginated table |
| `frontend/src/components/Common/Appearance.tsx` | Theme toggle (standalone + sidebar variants) |
| `frontend/src/components/Common/Footer.tsx` | Copyright + social links footer |
| `frontend/src/components/Common/Logo.tsx` | Theme-aware responsive logo |
| `frontend/src/components/Common/ErrorComponent.tsx` | Full-page error display |
| `frontend/src/components/Common/NotFound.tsx` | 404 page |
| `frontend/src/components/Sidebar/AppSidebar.tsx` | Sidebar root wrapper |
| `frontend/src/components/Sidebar/Main.tsx` | Sidebar navigation menu |
| `frontend/src/components/Sidebar/User.tsx` | Sidebar user dropdown |
| `frontend/src/components/theme-provider.tsx` | ThemeProvider context + useTheme hook |
