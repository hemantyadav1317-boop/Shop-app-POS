import { Link } from "@tanstack/react-router";
import { LogOut, Store } from "lucide-react";
import { Sheet, SheetContent, SheetTitle } from "@/components/ui/sheet";
import { PRIMARY_NAV } from "@/lib/nav";
import { useShop } from "@/lib/shop";
import { useAuth } from "@/lib/auth";
import { ThemeToggle } from "./ThemeToggle";
import { signOutAndRedirect } from "@/lib/signout";

function SidebarBody({ onNavigate }: { onNavigate?: () => void }) {
  const { shop, role } = useShop();
  const { user } = useAuth();

  return (
    <div className="flex h-full min-h-0 flex-col bg-sidebar text-sidebar-foreground">
      <div className="px-4 pb-4 pt-5">
        <div className="flex items-center gap-3">
          <div className="grid h-11 w-11 shrink-0 place-items-center rounded-2xl bg-sidebar-primary text-sidebar-primary-foreground">
            <Store className="h-5 w-5" />
          </div>
          <div className="min-w-0">
            <p className="truncate text-sm font-semibold">{shop?.name ?? "My Shop"}</p>
            <p className="truncate text-xs opacity-70">
              {role ? role[0]!.toUpperCase() + role.slice(1) : "—"} · {user?.email ?? ""}
            </p>
          </div>
        </div>
      </div>

      <nav className="min-h-0 flex-1 overflow-y-auto bg-card px-2 py-3 text-card-foreground">
        {PRIMARY_NAV.map((item) => (
          <Link
            key={item.to}
            to={item.to}
            onClick={onNavigate}
            activeProps={{ className: "bg-accent text-accent-foreground font-semibold" }}
            className="flex items-center gap-3 rounded-xl px-3 py-2.5 text-sm transition-colors hover:bg-muted"
          >
            <item.icon className="h-[18px] w-[18px] shrink-0" />
            <span className="truncate">{item.label}</span>
          </Link>
        ))}
      </nav>

      <div className="flex items-center justify-between gap-2 bg-sidebar px-3 py-3">
        <ThemeToggle />
        <button
          type="button"
          onClick={() => void signOutAndRedirect()}
          className="flex items-center gap-2 rounded-xl px-3 py-2 text-sm font-medium hover:bg-sidebar-accent"
        >
          <LogOut className="h-4 w-4" /> Logout
        </button>
      </div>
    </div>
  );
}

export function DesktopSidebar() {
  return (
    <aside className="hidden w-64 shrink-0 border-r border-border md:block">
      <SidebarBody />
    </aside>
  );
}

export function MobileSidebar({
  open,
  onOpenChange,
}: {
  open: boolean;
  onOpenChange: (v: boolean) => void;
}) {
  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent side="left" className="w-[280px] p-0">
        <SheetTitle className="sr-only">Menu</SheetTitle>
        <SidebarBody onNavigate={() => onOpenChange(false)} />
      </SheetContent>
    </Sheet>
  );
}
