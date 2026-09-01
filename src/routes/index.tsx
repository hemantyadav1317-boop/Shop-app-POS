import { createFileRoute } from "@tanstack/react-router";
import { useState } from "react";
import { ShoppingCart } from "lucide-react";
import { PosShell } from "@/components/pos/PosShell";
import { ProductGrid } from "@/components/pos/ProductGrid";
import { CartPanel } from "@/components/pos/CartPanel";
import { usePos } from "@/lib/pos-store";
import { formatRs } from "@/lib/pos-data";
import { Sheet, SheetContent, SheetTitle } from "@/components/ui/sheet";

export const Route = createFileRoute("/")({
  head: () => ({
    meta: [
      { title: "New Sale — Yadav Veggie & Fruits POS" },
      {
        name: "description",
        content: "Fast billing POS for your shop: products, cart, discounts and payments on phone or tablet.",
      },
      { property: "og:title", content: "New Sale — Yadav Veggie & Fruits POS" },
      {
        property: "og:description",
        content: "Fast billing POS for your shop: products, cart, discounts and payments on phone or tablet.",
      },
    ],
  }),
  component: SalePage,
});

function SalePage() {
  const { total, cart } = usePos();
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

      {/* Mobile / tablet cart bar */}
      <div className="pointer-events-none fixed inset-x-0 bottom-0 p-3 lg:hidden">
        <button
          type="button"
          onClick={() => setCartOpen(true)}
          className="pointer-events-auto grid w-full grid-cols-[auto_minmax(0,1fr)_auto] items-center gap-3 rounded-2xl bg-primary px-4 py-3 text-primary-foreground shadow-[var(--shadow-panel)]"
        >
          <ShoppingCart className="h-5 w-5 shrink-0" />
          <span className="truncate text-left text-sm font-semibold">{cart.length} items in order</span>
          <span className="shrink-0 text-base font-black">{formatRs(total)}</span>
        </button>
      </div>

      <Sheet open={cartOpen} onOpenChange={setCartOpen}>
        <SheetContent side="bottom" className="h-[88dvh] p-0 lg:hidden">
          <SheetTitle className="sr-only">Order</SheetTitle>
          <CartPanel onDone={() => setCartOpen(false)} />
        </SheetContent>
      </Sheet>
    </PosShell>
  );
}
