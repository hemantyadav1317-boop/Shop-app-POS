import { useState, type ReactNode } from "react";
import { Menu } from "lucide-react";
import { DesktopSidebar, MobileSidebar } from "./AppSidebar";
import { Button } from "@/components/ui/button";

export function PosShell({
  title,
  children,
  headerRight,
}: {
  title: string;
  children: ReactNode;
  headerRight?: ReactNode;
}) {
  const [open, setOpen] = useState(false);

  return (
    <div className="flex h-dvh w-full overflow-hidden bg-background">
      <DesktopSidebar />
      <MobileSidebar open={open} onOpenChange={setOpen} />
      <div className="flex min-w-0 flex-1 flex-col">
        <header className="grid grid-cols-[auto_minmax(0,1fr)_auto] items-center gap-3 border-b border-border bg-card px-3 py-2.5 sm:px-4">
          <Button
            variant="ghost"
            size="icon"
            className="lg:hidden"
            aria-label="Open menu"
            onClick={() => setOpen(true)}
          >
            <Menu className="h-5 w-5" />
          </Button>
          <h1 className="truncate text-base font-bold sm:text-lg">{title}</h1>
          <div className="shrink-0">{headerRight}</div>
        </header>
        <main className="min-h-0 flex-1 overflow-hidden">{children}</main>
      </div>
    </div>
  );
}
