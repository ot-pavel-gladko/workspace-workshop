# frontend-ui-primitives

## Purpose

Generic, presentational UI building blocks based on [shadcn/ui](https://ui.shadcn.com/): each file wraps a Radix UI primitive (or composes several) with Tailwind styling via `cn()` and CVA variants. These are app-agnostic visual atoms — no API calls, no business logic — consumed by `frontend-features` and `frontend-layout-common`. **Edit sparingly; prefer regenerating via the shadcn CLI (`npx shadcn@latest add <component>`) over hand-editing.**

## Public Interface

| File | Exported component(s) | Radix-backed? |
|---|---|---|
| `alert.tsx` | `Alert`, `AlertTitle`, `AlertDescription` | No |
| `avatar.tsx` | `Avatar`, `AvatarImage`, `AvatarFallback` | Yes (`@radix-ui/react-avatar`) |
| `badge.tsx` | `Badge`, `badgeVariants` | Yes (`@radix-ui/react-slot`) |
| `button-group.tsx` | `ButtonGroup`, `ButtonGroupSeparator`, `ButtonGroupText`, `buttonGroupVariants` | Yes (`@radix-ui/react-slot`) |
| `button.tsx` | `Button`, `buttonVariants` | Yes (`@radix-ui/react-slot`) |
| `card.tsx` | `Card`, `CardHeader`, `CardFooter`, `CardTitle`, `CardAction`, `CardDescription`, `CardContent` | No |
| `checkbox.tsx` | `Checkbox` | Yes (`@radix-ui/react-checkbox`) |
| `dialog.tsx` | `Dialog`, `DialogClose`, `DialogContent`, `DialogDescription`, `DialogFooter`, `DialogHeader`, `DialogOverlay`, `DialogPortal`, `DialogTitle`, `DialogTrigger` | Yes (`@radix-ui/react-dialog`) |
| `dropdown-menu.tsx` | `DropdownMenu`, `DropdownMenuTrigger`, `DropdownMenuContent`, `DropdownMenuGroup`, `DropdownMenuItem`, `DropdownMenuCheckboxItem`, `DropdownMenuRadioGroup`, `DropdownMenuRadioItem`, `DropdownMenuLabel`, `DropdownMenuSeparator`, `DropdownMenuShortcut`, `DropdownMenuSub`, `DropdownMenuSubTrigger`, `DropdownMenuSubContent`, `DropdownMenuPortal` | Yes (`@radix-ui/react-dropdown-menu`) |
| `form.tsx` | `Form`, `FormItem`, `FormLabel`, `FormControl`, `FormDescription`, `FormMessage`, `FormField`, `useFormField` | Yes (`@radix-ui/react-label`, `@radix-ui/react-slot`) |
| `input.tsx` | `Input` | No |
| `label.tsx` | `Label` | Yes (`@radix-ui/react-label`) |
| `loading-button.tsx` | `LoadingButton`, `buttonVariants` | Yes (`@radix-ui/react-slot`) |
| `pagination.tsx` | `Pagination`, `PaginationContent`, `PaginationLink`, `PaginationItem`, `PaginationPrevious`, `PaginationNext`, `PaginationEllipsis` | No |
| `password-input.tsx` | `PasswordInput` | No |
| `select.tsx` | `Select`, `SelectContent`, `SelectGroup`, `SelectItem`, `SelectLabel`, `SelectScrollDownButton`, `SelectScrollUpButton`, `SelectSeparator`, `SelectTrigger`, `SelectValue` | Yes (`@radix-ui/react-select`) |
| `separator.tsx` | `Separator` | Yes (`@radix-ui/react-separator`) |
| `sheet.tsx` | `Sheet`, `SheetTrigger`, `SheetClose`, `SheetContent`, `SheetHeader`, `SheetFooter`, `SheetTitle`, `SheetDescription` | Yes (`@radix-ui/react-dialog`) |
| `sidebar.tsx` | `Sidebar`, `SidebarProvider`, `SidebarTrigger`, `SidebarContent`, `SidebarHeader`, `SidebarFooter`, `SidebarGroup`, `SidebarMenu`, `SidebarMenuItem`, `SidebarMenuButton`, `SidebarMenuAction`, `SidebarMenuBadge`, `SidebarMenuSkeleton`, `SidebarMenuSub`, `SidebarMenuSubButton`, `SidebarMenuSubItem`, `SidebarInset`, `SidebarInput`, `SidebarRail`, `SidebarSeparator`, `SidebarGroupAction`, `SidebarGroupContent`, `SidebarGroupLabel`, `useSidebar` | Yes (slot, sheet, tooltip) |
| `skeleton.tsx` | `Skeleton` | No |
| `sonner.tsx` | `Toaster` | No (uses `sonner` + `next-themes`) |
| `table.tsx` | `Table`, `TableHeader`, `TableBody`, `TableFooter`, `TableHead`, `TableRow`, `TableCell`, `TableCaption` | No |
| `tabs.tsx` | `Tabs`, `TabsList`, `TabsTrigger`, `TabsContent` | Yes (`@radix-ui/react-tabs`) |
| `tooltip.tsx` | `Tooltip`, `TooltipTrigger`, `TooltipContent`, `TooltipProvider` | Yes (`@radix-ui/react-tooltip`) |

## Internal Structure

Flat directory at `frontend/src/components/ui/` — one primitive per file. Notable special cases:

- **`form.tsx`** — integrates `react-hook-form` (`FormField`, `useFormField` context); the only file with form-state awareness.
- **`loading-button.tsx`** and **`password-input.tsx`** — app-flavored composites built on `Button`/`Input` that add a spinner state and a visibility toggle respectively; these may require hand-edits when app behavior changes.
- **`sonner.tsx`** — thin wrapper around the `sonner` toast library wired to `next-themes` for dark-mode support.
- **`sidebar.tsx`** — the largest file; a composite that internally uses `Sheet`, `Skeleton`, `Tooltip`, `Button`, `Input`, and `Separator`, plus a `useSidebar` context hook and `useMobile` for responsive collapse.

## Dependencies

- **Radix UI primitives** — `@radix-ui/react-avatar`, `@radix-ui/react-checkbox`, `@radix-ui/react-dialog`, `@radix-ui/react-dropdown-menu`, `@radix-ui/react-label`, `@radix-ui/react-select`, `@radix-ui/react-separator`, `@radix-ui/react-slot`, `@radix-ui/react-tabs`, `@radix-ui/react-tooltip`
- **`class-variance-authority`** — CVA for typed variant definitions (`buttonVariants`, `badgeVariants`, etc.)
- **`tailwind-merge` / `clsx`** — accessed via `@/lib/utils` `cn()` helper; never called directly
- **`lucide-react`** — icons (chevrons, check marks, eye toggle, spinner, etc.)
- **`sonner`** + **`next-themes`** — toast notification system (`sonner.tsx` only)
- **`react-hook-form`** — form state integration (`form.tsx` only)

## Conventions

- All class merging goes through `cn()` from `@/lib/utils` — never raw `clsx` or `twMerge` calls.
- Variant styling is expressed via `cva()` (`class-variance-authority`); the variant map is exported alongside the component (e.g. `buttonVariants`) so consumers can reference variants without rendering the component.
- Components are purely presentational — no `fetch`, no Zustand/React Query, no router calls.
- Consumed by `frontend-features` (business-logic components) and `frontend-layout-common` (page shell / nav).
- Regenerate standard primitives with `npx shadcn@latest add <name>`; reserve hand-edits for `loading-button.tsx`, `password-input.tsx`, and `sidebar.tsx`.

## Files

See the Public Interface table above for the full file list. All 24 files live under `frontend/src/components/ui/`.
