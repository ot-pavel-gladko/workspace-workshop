# frontend-state-hooks

## Purpose

Client-side state and utility layer for the React frontend. Provides custom hooks for authentication (`useAuth`), UI feedback (`useCustomToast`, `useCopyToClipboard`), and responsive layout (`useMobile`), plus shared helpers for Tailwind class composition (`cn`) and centralised API error handling (`handleError`, `getInitials`).

## Public Interface

| Export | Signature / Returns | Purpose |
|---|---|---|
| `useAuth` (default) | `{ user, loginMutation, signUpMutation, logout }` | Auth state via TanStack Query; token stored in `localStorage` as `access_token` |
| `isLoggedIn` | `() => boolean` | Checks `localStorage.getItem("access_token") !== null`; gates the `currentUser` query |
| `useCustomToast` (default) | `{ showSuccessToast, showErrorToast }` | Wraps `sonner` with pre-styled success/error toasts |
| `useCopyToClipboard` | `{ copiedText, copy }` | Clipboard API wrapper; clears `copiedText` after 2 s |
| `useIsMobile` | `boolean \| undefined` | Matches `(max-width: 767px)` media query; `undefined` on first render (SSR-safe) |
| `cn` (lib/utils) | `(...inputs: ClassValue[]) => string` | `clsx` + `tailwind-merge` — conflict-free Tailwind class composition |
| `handleError` | `(this: (msg:string)=>void, err: ApiError) => void` | Extracts message from `ApiError`/`AxiosError` and calls the bound toast function |
| `getInitials` | `(name: string) => string` | Returns up to 2 uppercase initials from a display name |

`loginMutation.mutate(data)` calls `LoginService.loginAccessToken`, stores the returned token, then navigates to `/`. `logout()` removes the token and navigates to `/login`. Errors in login/signup call `handleError` bound to `showErrorToast`.

## Internal Structure

```
frontend/src/
  hooks/
    useAuth.ts            # auth state, login, signup, logout
    useCustomToast.ts     # toast helper
    useCopyToClipboard.ts # clipboard hook
    useMobile.ts          # responsive breakpoint hook
  lib/
    utils.ts              # cn() — Tailwind class utility
  utils.ts                # handleError, getInitials — API error helpers
```

## Dependencies

| Package / Module | Used by |
|---|---|
| `@tanstack/react-query` | `useAuth` — `useQuery` (currentUser), `useMutation` (login, signup), `useQueryClient` (invalidation) |
| `@tanstack/react-router` | `useAuth` — `useNavigate` for post-login/logout redirects |
| `@/client` (generated) | `useAuth` — `LoginService`, `UsersService`, `UserPublic`, `UserRegister`, `ApiError` |
| `axios` | `utils.ts` — `AxiosError` detection in `extractErrorMessage` |
| `sonner` | `useCustomToast` — toast notifications |
| `clsx` + `tailwind-merge` | `lib/utils.ts` — `cn()` |
| `react` | `useCopyToClipboard`, `useMobile` — `useState`, `useEffect` |

## Conventions

- Auth token lives at `localStorage["access_token"]`; `isLoggedIn()` is the single gate used to enable the `currentUser` query.
- After signup, `queryClient.invalidateQueries({ queryKey: ["users"] })` is called in `onSettled` to keep user lists fresh.
- API errors are centralised: `handleError` is bound to `showErrorToast` via `.bind(showErrorToast)`, keeping mutation `onError` handlers uniform across auth flows.
- `useMobile` initialises to `undefined` (not `false`) so SSR/hydration renders can distinguish "not yet measured" from "desktop".

## Files

| Path | Role |
|---|---|
| `frontend/src/hooks/useAuth.ts` | Auth hook — login, signup, logout, current user query, token storage |
| `frontend/src/hooks/useCustomToast.ts` | Toast notifications (success / error) via `sonner` |
| `frontend/src/hooks/useCopyToClipboard.ts` | Clipboard copy with 2-second auto-clear |
| `frontend/src/hooks/useMobile.ts` | Mobile viewport detection (768 px breakpoint) |
| `frontend/src/lib/utils.ts` | `cn()` — Tailwind class merging utility |
| `frontend/src/utils.ts` | `handleError`, `getInitials` — shared API error + string helpers |
