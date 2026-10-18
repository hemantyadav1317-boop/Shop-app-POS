import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { toast } from "sonner";
import { Play, Trash2 } from "lucide-react";
import { PosShell } from "@/components/pos/PosShell";
import { Button } from "@/components/ui/button";
import { useShop } from "@/lib/shop";
import { useInvalidatePos, useSavedOrders } from "@/lib/queries";
import { supabase } from "@/integrations/supabase/client";
import { useCart, type CartLine } from "@/lib/cart";
import { useRef, useState } from "react";
import { savedOrderTotal } from "@/lib/checkout-rules";

export const Route = createFileRoute("/_authenticated/saved")({
  head: () => ({
    meta: [
      { title: "Saved Orders — Shop POS" },
      { name: "description", content: "Adhoore orders save karein aur baad me resume karein." },
      { property: "og:title", content: "Saved Orders — Shop POS" },
      { property: "og:description", content: "Adhoore orders save karein aur baad me resume karein." },
    ],
  }),
  component: SavedPage,
});

function SavedPage() {
  const { shop } = useShop();
  const { data: orders, isLoading } = useSavedOrders(shop?.id);
  const invalidate = useInvalidatePos();
  const cart = useCart();
  const navigate = useNavigate();
  const [busyId, setBusyId] = useState<string | null>(null);
  const resumeLock = useRef(false);

  async function resume(order: { id: string; lines: unknown; customer_name: string | null; customer_phone: string | null; customer_id?: string | null; discount?: number }) {
    if (resumeLock.current) return;
    if (cart.lines.length && !window.confirm("Replace the current order with this saved bill?")) return;
    resumeLock.current = true;
    setBusyId(order.id);
    try {
    const { data: removed, error } = await supabase.from("saved_orders").delete().eq("id", order.id).select("id");
    if (error || !removed?.length) return void toast.error(error?.message ?? "This saved order was already resumed. Refresh the list.");
    cart.loadLines(order.lines as CartLine[], order.customer_name ? {
      id: order.customer_id ?? null,
      name: order.customer_name ?? "",
      phone: order.customer_phone ?? "",
    } : null);
    cart.setDiscount(Number(order.discount ?? 0));
    invalidate();
    void navigate({ to: "/pos" });
    } finally { resumeLock.current = false; setBusyId(null); }
  }

  async function remove(id: string) {
    const { error } = await supabase.from("saved_orders").delete().eq("id", id);
    if (error) toast.error(error.message);
    else {
      invalidate();
      toast.success("Order deleted");
    }
  }

  return (
    <PosShell title="Saved Orders">
      <div className="h-full overflow-y-auto p-3">
        {isLoading ? (
          <p className="py-10 text-center text-sm text-muted-foreground">Loading…</p>
        ) : !orders?.length ? (
          <p className="py-16 text-center text-sm text-muted-foreground">Koi saved order nahi hai.</p>
        ) : (
          <ul className="space-y-2.5">
            {orders.map((o) => {
              const lines = (o.lines ?? []) as CartLine[];
              const total = savedOrderTotal(lines, Number(o.discount));
              return (
                <li key={o.id} className="rounded-2xl bg-card p-3 shadow-[var(--shadow-tile)]">
                  <div className="flex items-start justify-between gap-3">
                    <div className="min-w-0">
                      <p className="truncate text-sm font-semibold">
                        {o.customer_name || "Walk-in"} · {lines.length} items
                      </p>
                      <p className="truncate text-xs text-muted-foreground">
                        {new Date(o.created_at).toLocaleString("en-IN")}
                      </p>
                    </div>
                    <span className="shrink-0 font-black text-primary">Rs {total.toFixed(2)}</span>
                  </div>
                  <div className="mt-2 flex gap-2">
                    <Button size="sm" disabled={busyId !== null} onClick={() => void resume(o)}>
                      <Play className="mr-1 h-4 w-4" /> Resume
                    </Button>
                    <Button size="sm" variant="outline" disabled={busyId !== null} onClick={() => void remove(o.id)}>
                      <Trash2 className="mr-1 h-4 w-4" /> Delete
                    </Button>
                  </div>
                </li>
              );
            })}
          </ul>
        )}
      </div>
    </PosShell>
  );
}
