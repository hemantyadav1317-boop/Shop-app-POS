import { createFileRoute, Link } from "@tanstack/react-router";
import { useState } from "react";
import { Bookmark, ReceiptText, ShoppingCart, Zap } from "lucide-react";
import { PosShell } from "@/components/pos/PosShell";
import { ProductGrid } from "@/components/pos/ProductGrid";
import { CartPanel } from "@/components/pos/CartPanel";
import { QuickSellDialog } from "@/components/pos/QuickSellDialog";
import { useCart } from "@/lib/cart";
import { Button } from "@/components/ui/button";
import { Sheet, SheetContent, SheetTitle } from "@/components/ui/sheet";

export const Route = createFileRoute("/_authenticated/pos")({
  head: () => ({
    meta: [
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
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
  const [quickOpen, setQuickOpen] = useState(false);

  const barBtn =
    "flex min-w-0 flex-1 items-center justify-center gap-1.5 rounded-lg border border-border bg-card px-3 py-3 text-xs font-semibold text-foreground";

  return (
    <PosShell title="New Sale">
      <div className="flex h-full min-h-0 flex-col">
      <div className="flex min-h-0 flex-1">
        <div className="flex min-w-0 flex-1 flex-col">
          <div className="min-h-0 flex-1">
            <ProductGrid />
          </div>
          <div className="pos-shortcuts flex shrink-0 gap-2 border-t border-border bg-card p-3">
            <Link to="/bills" className={barBtn}>
              <ReceiptText className="h-4 w-4 shrink-0" />
              <span className="truncate">Bills</span>
            </Link>
            <Link to="/saved" className={barBtn}>
              <Bookmark className="h-4 w-4 shrink-0" />
              <span className="truncate">Saved Bills</span>
            </Link>
            <Button variant="outline" type="button" onClick={() => setQuickOpen(true)} className={barBtn}>
              <Zap className="h-4 w-4 shrink-0 text-primary" />
              <span className="truncate">Quick Sell</span>
            </Button>
          </div>
        </div>
        <div className="pos-cart w-[320px] shrink-0 border-l border-border xl:w-[380px]">
          <CartPanel />
        </div>
      </div>

      <div className="pos-cart-launch shrink-0 border-t border-border bg-card p-3">
        <Button
          type="button"
          onClick={() => setCartOpen(true)}
          className="pointer-events-auto grid w-full grid-cols-[auto_minmax(0,1fr)_auto] items-center gap-3 h-14 rounded-lg bg-primary px-4 py-3 text-primary-foreground shadow-[var(--shadow-panel)]"
        >
          <ShoppingCart className="h-5 w-5 shrink-0" />
          <span className="truncate text-left text-sm font-semibold">{lines.length} items</span>
          <span className="shrink-0 text-base font-black">Rs {total.toFixed(2)}</span>
        </Button>
      </div>

      </div>

      <Sheet open={cartOpen} onOpenChange={setCartOpen}>
        <SheetContent side="bottom" className="h-[90dvh] p-0">
          <SheetTitle className="sr-only">Order</SheetTitle>
          <CartPanel onDone={() => setCartOpen(false)} />
        </SheetContent>
      </Sheet>

      <QuickSellDialog open={quickOpen} onOpenChange={setQuickOpen} />
    </PosShell>
  );
}
