import { useEffect, useState, type ReactNode } from "react";
import { Link } from "@tanstack/react-router";
import { Maximize, Menu, Minimize } from "lucide-react";
import { MobileSidebar } from "./AppSidebar";
import { Button } from "@/components/ui/button";
import { BOTTOM_NAV } from "@/lib/nav";

export function PosShell({
  title,
  children,
  headerRight,
  hideBottomNav = false,
}: {
  title: string;
  children: ReactNode;
  headerRight?: ReactNode;
  hideBottomNav?: boolean;
}) {
  const [open, setOpen] = useState(false);
  const [fs, setFs] = useState(false);

  useEffect(() => {
    const on = () => setFs(!!document.fullscreenElement);
    document.addEventListener("fullscreenchange", on);
    return () => document.removeEventListener("fullscreenchange", on);
  }, []);

  function toggleFullscreen() {
    if (document.fullscreenElement) void document.exitFullscreen();
    else void document.documentElement.requestFullscreen?.().catch(() => {});
  }

  return (
    <div className="flex h-dvh w-full overflow-hidden bg-background/70">
      <MobileSidebar open={open} onOpenChange={setOpen} />
      <div className="flex min-w-0 flex-1 flex-col">
        <header className="grid grid-cols-[auto_minmax(0,1fr)_auto] items-center gap-2 border-b border-border bg-card/90 px-2 py-2 backdrop-blur sm:px-4">
          <Button
            variant="ghost"
            size="icon"
            aria-label="Open menu"
            onClick={() => setOpen(true)}
          >
            <Menu className="h-5 w-5" />
          </Button>
          <h1 className="truncate text-base font-bold sm:text-lg">{title}</h1>
          <div className="flex shrink-0 items-center gap-1">
            {headerRight}
            <Button
              variant="ghost"
              size="icon"
              className="hidden md:inline-flex"
              aria-label={fs ? "Exit full screen" : "Full screen"}
              onClick={toggleFullscreen}
            >
              {fs ? <Minimize className="h-5 w-5" /> : <Maximize className="h-5 w-5" />}
            </Button>
          </div>
        </header>

        <main className="min-h-0 flex-1 overflow-hidden">{children}</main>

        {!hideBottomNav && (
          <nav className="grid shrink-0 grid-cols-5 border-t border-border bg-card pb-[env(safe-area-inset-bottom)] md:hidden">
            {BOTTOM_NAV.map((item) => (
              <Link
                key={item.to}
                to={item.to}
                activeProps={{ className: "text-primary" }}
                className="flex flex-col items-center gap-1 py-2 text-[11px] font-medium text-muted-foreground"
              >
                <item.icon className="h-5 w-5" />
                <span className="truncate">{item.label}</span>
              </Link>
            ))}
          </nav>
        )}
      </div>
    </div>
  );
}
