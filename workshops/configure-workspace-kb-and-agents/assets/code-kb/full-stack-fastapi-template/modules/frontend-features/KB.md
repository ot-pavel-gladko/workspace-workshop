# frontend-features

## Purpose

Feature-level CRUD UI components grouped by domain, living under `frontend/src/components/`. Each domain area (Admin, Items, UserSettings, Pending) owns its own subfolder with self-contained dialog forms, an actions dropdown menu, and TanStack Table column definitions. These components are consumed by route pages to compose full list/detail views.

## Public Interface

### Admin — user management (superuser-only)

| Component | Feature | What it does |
|---|---|---|
| `AddUser` | Admin | Dialog form to create a new user (email, password, admin flag) |
| `EditUser` | Admin | Dialog form to update user details and role |
| `DeleteUser` | Admin | Confirmation dialog to delete a user account |
| `UserActionsMenu` | Admin | Dropdown (edit / delete) rendered in each user table row |
| `columns` / `UserTableData` | Admin | TanStack Table column definitions with role badge and actions |

### Items — item management

| Component | Feature | What it does |
|---|---|---|
| `AddItem` | Items | Dialog form to create a new item (title, description) |
| `EditItem` | Items | Dialog form to update item fields |
| `DeleteItem` | Items | Confirmation dialog to delete an item |
| `ItemActionsMenu` | Items | Dropdown (edit / delete) rendered in each item table row |
| `columns` | Items | TanStack Table column definitions with clipboard copy for ID |

### UserSettings — self-service account management

| Component | Feature | What it does |
|---|---|---|
| `ChangePassword` | UserSettings | Inline form to change the current user's password |
| `UserInformation` | UserSettings | Toggle view/edit form for profile name and email |
| `DeleteAccount` | UserSettings | Warning section wrapping the delete confirmation trigger |
| `DeleteConfirmation` | UserSettings | Dialog to confirm self-deletion, then logs the user out |

### Pending — loading states

| Component | Feature | What it does |
|---|---|---|
| `PendingItems` | Pending | Skeleton table shown while items data loads |
| `PendingUsers` | Pending | Skeleton table shown while users data loads |

## Internal Structure

Each domain subfolder follows a consistent shape:

```
Admin/
  AddUser.tsx       — dialog form
  EditUser.tsx      — dialog form
  DeleteUser.tsx    — confirmation dialog
  UserActionsMenu.tsx — dropdown composing Edit + Delete dialogs
  columns.tsx       — ColumnDef[] for <DataTable>

Items/            — same shape as Admin/
UserSettings/     — no columns.tsx; ChangePassword + UserInformation are inline forms
Pending/          — skeleton-only components, no mutations
```

All CRUD dialogs share the same internal anatomy: a `react-hook-form` `useForm` with a `zod` schema, a `useMutation` from TanStack Query that calls the generated API client, `useQueryClient` for cache invalidation on success, and `useCustomToast` for feedback. `columns.tsx` files export a `ColumnDef[]` array consumed directly by the shared `DataTable` component.

## Dependencies

| Dependency | Role |
|---|---|
| `react-hook-form` + `zod` | Form state management and schema-based validation |
| `@tanstack/react-query` (`useMutation`, `useQueryClient`) | API mutations and query cache invalidation |
| `frontend/src/client` (`UsersService`, `ItemsService`, type models) | Generated OpenAPI client for all API calls |
| `@/components/ui/*` (dialog, input, button, form, loading-button, checkbox) | Shadcn/ui primitives (frontend-ui-primitives module) |
| `@tanstack/react-table` | Column definition types for DataTable integration |
| `@/hooks/useCustomToast` | Toast notifications on success/error |
| `@/hooks/useAuth` | Current user context (used by UserActionsMenu, UserInformation, DeleteConfirmation) |
| `@/utils:handleError` | Centralised API error handling |

## Conventions

- **One component per CRUD action** — `AddX`, `EditX`, `DeleteX` are separate files; no shared mega-form.
- **Mutation + invalidation pattern** — every mutating component calls `queryClient.invalidateQueries` on success to keep the list view fresh.
- **`columns.tsx` feeds the shared DataTable** — column definitions are decoupled from the page and passed as a prop; each domain has its own file.
- **Zod schemas colocated with the form** — validation schemas are defined in the same file as the component, not in a shared schema module.
- **Dialogs are self-contained** — they own their own open/close state and are triggered either by a standalone button (Add) or from within an ActionsMenu (Edit/Delete).

## Files

| Path | Role |
|---|---|
| `frontend/src/components/Admin/AddUser.tsx` | Dialog form — create user |
| `frontend/src/components/Admin/EditUser.tsx` | Dialog form — edit user |
| `frontend/src/components/Admin/DeleteUser.tsx` | Confirmation dialog — delete user |
| `frontend/src/components/Admin/UserActionsMenu.tsx` | Row-level dropdown composing Edit + Delete |
| `frontend/src/components/Admin/columns.tsx` | TanStack Table columns for user list |
| `frontend/src/components/Items/AddItem.tsx` | Dialog form — create item |
| `frontend/src/components/Items/EditItem.tsx` | Dialog form — edit item |
| `frontend/src/components/Items/DeleteItem.tsx` | Confirmation dialog — delete item |
| `frontend/src/components/Items/ItemActionsMenu.tsx` | Row-level dropdown composing Edit + Delete |
| `frontend/src/components/Items/columns.tsx` | TanStack Table columns for item list with clipboard copy |
| `frontend/src/components/UserSettings/ChangePassword.tsx` | Inline form — change own password |
| `frontend/src/components/UserSettings/UserInformation.tsx` | Toggle view/edit form — profile details |
| `frontend/src/components/UserSettings/DeleteAccount.tsx` | Warning section wrapping delete trigger |
| `frontend/src/components/UserSettings/DeleteConfirmation.tsx` | Confirmation dialog — delete own account + logout |
| `frontend/src/components/Pending/PendingItems.tsx` | Skeleton table for items loading state |
| `frontend/src/components/Pending/PendingUsers.tsx` | Skeleton table for users loading state |
