import { createFileRoute, Link } from "@tanstack/react-router";
import { ChevronRight, LogOut } from "lucide-react";
import { PosShell } from "@/components/pos/PosShell";
import { Button } from "@/components/ui/button";
import { ThemeToggle } from "@/components/pos/ThemeToggle";
import { PRIMARY_NAV } from "@/lib/nav";
import { useShop } from "@/lib/shop";
import { useAuth } from "@/lib/auth";
import { signOutAndRedirect } from "@/lib/signout";

export const Route = createFileRoute("/_authenticated/more")({
  head: () => ({
    meta: [
      { title: "More — Shop POS" },
      { name: "description", content: "Sabhi modules ek jagah: purchases, vendors, expenses, daybook, reports, settings." },
      { property: "og:title", content: "More — Shop POS" },
      { property: "og:description", content: "Sabhi modules ek jagah: purchases, vendors, expenses, daybook, reports, settings." },
    ],
  }),
  component: MorePage,
});

function MorePage() {
  const { shop, role } = useShop();
  const { user } = useAuth();

  return (
    <PosShell title="More">
      <div className="h-full overflow-y-auto p-3">
        <div className="rounded-2xl bg-card p-4 shadow-[var(--shadow-tile)]">
          <p className="truncate text-base font-bold">{shop?.name ?? "My Shop"}</p>
          <p className="truncate text-xs text-muted-foreground">
            {role ?? "member"} · {user?.email}
          </p>
          <div className="mt-3">
            <ThemeToggle />
          </div>
        </div>

        <nav className="mt-3 overflow-hidden rounded-2xl bg-card shadow-[var(--shadow-tile)]">
          {PRIMARY_NAV.map((item) => (
            <Link
              key={item.to}
              to={item.to}
              className="grid grid-cols-[auto_minmax(0,1fr)_auto] items-center gap-3 border-b border-border px-4 py-3.5 last:border-b-0 active:bg-muted"
            >
              <item.icon className="h-[18px] w-[18px] shrink-0" />
              <span className="truncate text-sm">{item.label}</span>
              <ChevronRight className="h-4 w-4 shrink-0 text-muted-foreground" />
            </Link>
          ))}
        </nav>

        <Button variant="outline" className="mt-3 w-full" onClick={() => void signOutAndRedirect()}>
          <LogOut className="mr-1 h-4 w-4" /> Log out
        </Button>
      </div>
    </PosShell>
  );
}
