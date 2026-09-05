import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { toast } from "sonner";
import { Play, Trash2 } from "lucide-react";
import { PosShell } from "@/components/pos/PosShell";
import { Button } from "@/components/ui/button";
import { useShop } from "@/lib/shop";
import { useInvalidatePos, useSavedOrders } from "@/lib/queries";
import { supabase } from "@/integrations/supabase/client";
import { useCart, type CartLine } from "@/lib/cart";

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

  async function resume(order: { id: string; lines: unknown; customer_name: string | null; customer_phone: string | null }) {
    cart.loadLines(order.lines as CartLine[], {
      id: null,
      name: order.customer_name ?? "",
      phone: order.customer_phone ?? "",
    });
    await supabase.from("saved_orders").delete().eq("id", order.id);
    invalidate();
    void navigate({ to: "/pos" });
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
              const total = lines.reduce((s, l) => s + l.price * l.qty, 0);
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
                    <Button size="sm" onClick={() => void resume(o)}>
                      <Play className="mr-1 h-4 w-4" /> Resume
                    </Button>
                    <Button size="sm" variant="outline" onClick={() => void remove(o.id)}>
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
