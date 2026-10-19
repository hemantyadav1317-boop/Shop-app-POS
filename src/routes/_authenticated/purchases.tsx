import { createFileRoute } from "@tanstack/react-router";
import { useState } from "react";
import { Plus, Trash2 } from "lucide-react";
import { toast } from "sonner";
import { PosShell } from "@/components/pos/PosShell";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Dialog,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { useShop } from "@/lib/shop";
import { useInvalidatePos, useProducts, usePurchases, useVendors } from "@/lib/queries";
import { supabase } from "@/integrations/supabase/client";

export const Route = createFileRoute("/_authenticated/purchases")({
  head: () => ({
    meta: [
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
      { title: "Purchases — Shop POS" },
      { name: "description", content: "Maal kharidi record karein — stock aur vendor payable auto update." },
      { property: "og:title", content: "Purchases — Shop POS" },
      { property: "og:description", content: "Maal kharidi record karein — stock aur vendor payable auto update." },
    ],
  }),
  component: PurchasesPage,
});

type Row = { product_id: string; name: string; qty: string; cost: string };

function PurchasesPage() {
  const { shop } = useShop();
  const { data: purchases, isLoading } = usePurchases(shop?.id);
  const { data: products } = useProducts(shop?.id);
  const { data: vendors } = useVendors(shop?.id);
  const invalidate = useInvalidatePos();

  const [open, setOpen] = useState(false);
  const [vendorId, setVendorId] = useState("");
  const [paid, setPaid] = useState("");
  const [rows, setRows] = useState<Row[]>([{ product_id: "", name: "", qty: "", cost: "" }]);

  const total = rows.reduce((s, r) => s + (Number(r.qty) || 0) * (Number(r.cost) || 0), 0);

  function reset() {
    setRows([{ product_id: "", name: "", qty: "", cost: "" }]);
    setPaid("");
    setVendorId("");
  }

  async function save() {
    if (!shop) return;
    const items = rows
      .filter((r) => (r.product_id || r.name.trim()) && Number(r.qty) > 0)
      .map((r) => ({
        product_id: r.product_id,
        name: r.product_id ? (products?.find((p) => p.id === r.product_id)?.name ?? r.name) : r.name.trim(),
        qty: Number(r.qty),
        cost: Number(r.cost) || 0,
      }));
    if (!items.length) {
      toast.error("Kam se kam ek item add karein");
      return;
    }
    const vendor = vendors?.find((v) => v.id === vendorId);
    const { error } = await supabase.rpc("create_purchase", {
      _shop_id: shop.id,
      _items: items,
      _paid: Number(paid) || 0,
      _vendor_id: vendorId || null,
      _vendor_name: vendor?.name ?? null,
      _note: null,
    } as never);
    if (error) {
      toast.error(error.message);
      return;
    }
    invalidate();
    setOpen(false);
    reset();
    toast.success("Purchase saved — stock updated");
  }

  return (
    <PosShell
      title="Purchases"
      headerRight={
        <Button size="sm" onClick={() => setOpen(true)}>
          <Plus className="mr-1 h-4 w-4" /> New
        </Button>
      }
    >
      <div className="h-full overflow-y-auto p-3">
        {isLoading ? (
          <p className="py-10 text-center text-sm text-muted-foreground">Loading…</p>
        ) : !purchases?.length ? (
          <p className="py-16 text-center text-sm text-muted-foreground">Abhi koi purchase nahi hai.</p>
        ) : (
          <ul className="space-y-2">
            {purchases.map((p) => (
              <li
                key={p.id}
                className="grid grid-cols-[minmax(0,1fr)_auto] items-center gap-3 rounded-2xl bg-card p-3 shadow-[var(--shadow-tile)]"
              >
                <div className="min-w-0">
                  <p className="truncate text-sm font-semibold">{p.vendor_name ?? "Vendor"}</p>
                  <p className="truncate text-xs text-muted-foreground">
                    {new Date(p.created_at).toLocaleString("en-IN")}
                    {Number(p.due) > 0 ? ` · Due Rs ${Number(p.due).toFixed(2)}` : ""}
                  </p>
                </div>
                <span className="shrink-0 font-black text-primary">Rs {Number(p.total).toFixed(2)}</span>
              </li>
            ))}
          </ul>
        )}
      </div>

      <Dialog open={open} onOpenChange={setOpen}>
        <DialogContent className="max-h-[92dvh] overflow-y-auto sm:max-w-lg">
          <DialogHeader>
            <DialogTitle>New purchase</DialogTitle>
          </DialogHeader>

          <div className="space-y-3">
            <div>
              <Label htmlFor="vend">Vendor</Label>
              <select
                id="vend"
                value={vendorId}
                onChange={(e) => setVendorId(e.target.value)}
                className="h-11 w-full rounded-md border border-input bg-background px-3 text-sm"
              >
                <option value="">— Select vendor —</option>
                {(vendors ?? []).map((v) => (
                  <option key={v.id} value={v.id}>
                    {v.name}
                  </option>
                ))}
              </select>
            </div>

            {rows.map((r, i) => (
              <div key={i} className="grid grid-cols-[minmax(0,1fr)_auto] gap-2 rounded-xl border border-border p-2">
                <div className="space-y-2">
                  <select
                    aria-label="Product"
                    value={r.product_id}
                    onChange={(e) =>
                      setRows(rows.map((x, j) => (j === i ? { ...x, product_id: e.target.value } : x)))
                    }
                    className="h-10 w-full rounded-md border border-input bg-background px-2 text-sm"
                  >
                    <option value="">— New / free item —</option>
                    {(products ?? []).map((p) => (
                      <option key={p.id} value={p.id}>
                        {p.name}
                      </option>
                    ))}
                  </select>
                  {!r.product_id && (
                    <Input
                      placeholder="Item name"
                      aria-label="Item name"
                      value={r.name}
                      onChange={(e) => setRows(rows.map((x, j) => (j === i ? { ...x, name: e.target.value } : x)))}
                    />
                  )}
                  <div className="flex gap-2">
                    <Input
                      inputMode="decimal"
                      placeholder="Qty"
                      aria-label="Quantity"
                      value={r.qty}
                      onChange={(e) => setRows(rows.map((x, j) => (j === i ? { ...x, qty: e.target.value } : x)))}
                    />
                    <Input
                      inputMode="decimal"
                      placeholder="Cost / unit"
                      aria-label="Cost per unit"
                      value={r.cost}
                      onChange={(e) => setRows(rows.map((x, j) => (j === i ? { ...x, cost: e.target.value } : x)))}
                    />
                  </div>
                </div>
                <Button
                  size="icon"
                  variant="ghost"
                  aria-label="Remove row"
                  onClick={() => setRows(rows.filter((_, j) => j !== i))}
                >
                  <Trash2 className="h-4 w-4" />
                </Button>
              </div>
            ))}

            <Button
              variant="outline"
              className="w-full"
              onClick={() => setRows([...rows, { product_id: "", name: "", qty: "", cost: "" }])}
            >
              <Plus className="mr-1 h-4 w-4" /> Add item
            </Button>

            <div className="flex items-center justify-between text-base font-black">
              <span>Total</span>
              <span className="text-primary">Rs {total.toFixed(2)}</span>
            </div>

            <div>
              <Label htmlFor="pp">Paid now</Label>
              <Input id="pp" inputMode="decimal" value={paid} onChange={(e) => setPaid(e.target.value)} />
            </div>
          </div>

          <DialogFooter>
            <Button variant="ghost" onClick={() => setOpen(false)}>
              Cancel
            </Button>
            <Button onClick={() => void save()}>Save purchase</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </PosShell>
  );
}
