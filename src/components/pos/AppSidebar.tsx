import { Link } from "@tanstack/react-router";
import {
  BookOpen,
  ClipboardList,
  Crown,
  FileText,
  HelpCircle,
  LayoutGrid,
  Package,
  Receipt,
  Settings,
  ShoppingBag,
  Users,
  Wallet,
} from "lucide-react";
import { Sheet, SheetContent, SheetTitle } from "@/components/ui/sheet";

const NAV = [
  { to: "/", label: "New Sale", icon: ShoppingBag },
  { to: "/bills", label: "Bill History", icon: FileText },
  { to: "/saved", label: "Saved Orders", icon: ClipboardList },
  { to: "/inventory", label: "Inventory / Stock", icon: Package },
  { to: "/customers", label: "Customer Management", icon: Users },
  { to: "/reports", label: "Report", icon: LayoutGrid },
] as const;

const SECONDARY = [
  { label: "Expenses", icon: Wallet },
  { label: "DayBook", icon: BookOpen },
  { label: "Credit Notes", icon: Receipt },
  { label: "Settings", icon: Settings },
  { label: "Help", icon: HelpCircle },
] as const;

function SidebarBody({ onNavigate }: { onNavigate?: () => void }) {
  return (
    <div className="flex h-full min-h-0 flex-col bg-sidebar text-sidebar-foreground">
      <div className="px-5 pb-5 pt-6">
        <div className="grid h-14 w-14 shrink-0 place-items-center rounded-2xl bg-sidebar-primary text-lg font-black text-sidebar-primary-foreground">
          YV
        </div>
        <p className="mt-3 truncate text-base font-semibold">Yadav Veggie &amp; Fruits</p>
        <p className="truncate text-xs opacity-70">Admin · Store POS</p>
      </div>

      <nav className="min-h-0 flex-1 overflow-y-auto bg-card px-2 py-3 text-card-foreground">
        {NAV.map((item) => (
          <Link
            key={item.to}
            to={item.to}
            onClick={onNavigate}
            activeOptions={{ exact: item.to === "/" }}
            activeProps={{ className: "bg-accent text-accent-foreground font-semibold" }}
            className="flex items-center gap-3 rounded-xl px-3 py-2.5 text-sm transition-colors hover:bg-muted"
          >
            <item.icon className="h-[18px] w-[18px] shrink-0" />
            <span className="truncate">{item.label}</span>
          </Link>
        ))}
        <div className="my-3 h-px bg-border" />
        {SECONDARY.map((item) => (
          <div
            key={item.label}
            className="flex items-center gap-3 rounded-xl px-3 py-2.5 text-sm text-muted-foreground"
          >
            <item.icon className="h-[18px] w-[18px] shrink-0" />
            <span className="truncate">{item.label}</span>
          </div>
        ))}
      </nav>

      <div className="flex items-center gap-3 bg-sidebar px-5 py-4">
        <Crown className="h-5 w-5 shrink-0" />
        <span className="truncate text-sm font-semibold uppercase tracking-wide">Upgrade to premium</span>
      </div>
    </div>
  );
}

export function DesktopSidebar() {
  return (
    <aside className="hidden w-64 shrink-0 border-r border-border lg:block">
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
