import { createFileRoute } from "@tanstack/react-router";
import { useState } from "react";
import { ShoppingCart } from "lucide-react";
import { PosShell } from "@/components/pos/PosShell";
import { ProductGrid } from "@/components/pos/ProductGrid";
import { CartPanel } from "@/components/pos/CartPanel";
import { useCart } from "@/lib/cart";
import { Sheet, SheetContent, SheetTitle } from "@/components/ui/sheet";

export const Route = createFileRoute("/_authenticated/pos")({
  head: () => ({
    meta: [
      { title: "New Sale — Shop POS" },
      { name: "description", content: "Tez billing: product, cart, discount aur payment ek screen par." },
      { property: "og:title", content: "New Sale — Shop POS" },
      { property: "og:description", content: "Tez billing: product, cart, discount aur payment ek screen par." },
    ],
  }),
  component: PosPage,
});

function PosPage() {
  const { total, lines } = useCart();
  const [cartOpen, setCartOpen] = useState(false);

  return (
    <PosShell title="New Sale">
      <div className="flex h-full min-h-0">
        <div className="min-w-0 flex-1">
          <ProductGrid />
        </div>
        <div className="hidden w-[360px] shrink-0 border-l border-border lg:block">
          <CartPanel />
        </div>
      </div>

      <div className="pointer-events-none fixed inset-x-0 bottom-[68px] p-3 md:bottom-0 lg:hidden">
        <button
          type="button"
          onClick={() => setCartOpen(true)}
          className="pointer-events-auto grid w-full grid-cols-[auto_minmax(0,1fr)_auto] items-center gap-3 rounded-2xl bg-primary px-4 py-3 text-primary-foreground shadow-[var(--shadow-panel)]"
        >
          <ShoppingCart className="h-5 w-5 shrink-0" />
          <span className="truncate text-left text-sm font-semibold">{lines.length} items in order</span>
          <span className="shrink-0 text-base font-black">Rs {total.toFixed(2)}</span>
        </button>
      </div>

      <Sheet open={cartOpen} onOpenChange={setCartOpen}>
        <SheetContent side="bottom" className="h-[90dvh] p-0 lg:hidden">
          <SheetTitle className="sr-only">Order</SheetTitle>
          <CartPanel onDone={() => setCartOpen(false)} />
        </SheetContent>
      </Sheet>
    </PosShell>
  );
}
