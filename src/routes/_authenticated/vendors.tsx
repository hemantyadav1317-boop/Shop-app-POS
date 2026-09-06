import { createFileRoute } from "@tanstack/react-router";
import { useMemo, useState } from "react";
import { Plus, Search } from "lucide-react";
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
import { useInvalidatePos, useVendors } from "@/lib/queries";
import { supabase } from "@/integrations/supabase/client";

export const Route = createFileRoute("/_authenticated/vendors")({
  head: () => ({
    meta: [
      { title: "Vendors — Shop POS" },
      { name: "description", content: "Supplier list aur unka baaki payable amount manage karein." },
      { property: "og:title", content: "Vendors — Shop POS" },
      { property: "og:description", content: "Supplier list aur unka baaki payable amount manage karein." },
    ],
  }),
  component: VendorsPage,
});

function VendorsPage() {
  const { shop } = useShop();
  const { data: vendors, isLoading } = useVendors(shop?.id);
  const invalidate = useInvalidatePos();
  const [q, setQ] = useState("");
  const [open, setOpen] = useState(false);
  const [form, setForm] = useState({ name: "", phone: "", address: "" });

  const rows = useMemo(() => {
    const term = q.trim().toLowerCase();
    return (vendors ?? []).filter(
      (v) => !term || v.name.toLowerCase().includes(term) || (v.phone ?? "").includes(term),
    );
  }, [vendors, q]);

  const payable = rows.reduce((s, v) => s + Number(v.payable), 0);

  async function addVendor() {
    if (!shop || !form.name.trim()) return;
    const { error } = await supabase.from("vendors").insert({
      shop_id: shop.id,
      name: form.name.trim(),
      phone: form.phone.trim() || null,
      address: form.address.trim() || null,
    });
    if (error) {
      toast.error(error.message);
      return;
    }
    invalidate();
    setOpen(false);
    setForm({ name: "", phone: "", address: "" });
    toast.success("Vendor added");
  }

  return (
    <PosShell
      title="Vendors"
      headerRight={
        <Button size="sm" onClick={() => setOpen(true)}>
          <Plus className="mr-1 h-4 w-4" /> Add
        </Button>
      }
    >
      <div className="flex h-full min-h-0 flex-col gap-3 p-3">
        <div className="rounded-2xl bg-card p-3 shadow-[var(--shadow-tile)]">
          <p className="text-xs text-muted-foreground">Total payable</p>
          <p className="text-xl font-black text-destructive">Rs {payable.toFixed(2)}</p>
        </div>

        <div className="relative">
          <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
          <Input
            value={q}
            onChange={(e) => setQ(e.target.value)}
            placeholder="Vendor name ya phone"
            aria-label="Search vendors"
            className="h-11 bg-card pl-9"
          />
        </div>

        <div className="min-h-0 flex-1 overflow-y-auto">
          {isLoading ? (
            <p className="py-10 text-center text-sm text-muted-foreground">Loading…</p>
          ) : (
            <ul className="space-y-2">
              {rows.map((v) => (
                <li
                  key={v.id}
                  className="grid grid-cols-[minmax(0,1fr)_auto] items-center gap-3 rounded-2xl bg-card p-3 shadow-[var(--shadow-tile)]"
                >
                  <div className="min-w-0">
                    <p className="truncate text-sm font-semibold">{v.name}</p>
                    <p className="truncate text-xs text-muted-foreground">{v.phone ?? "—"}</p>
                  </div>
                  <span
                    className={`shrink-0 text-sm font-bold ${Number(v.payable) > 0 ? "text-destructive" : "text-muted-foreground"}`}
                  >
                    Rs {Number(v.payable).toFixed(2)}
                  </span>
                </li>
              ))}
              {rows.length === 0 && (
                <p className="py-16 text-center text-sm text-muted-foreground">Koi vendor nahi mila.</p>
              )}
            </ul>
          )}
        </div>
      </div>

      <Dialog open={open} onOpenChange={setOpen}>
        <DialogContent className="sm:max-w-sm">
          <DialogHeader>
            <DialogTitle>Add vendor</DialogTitle>
          </DialogHeader>
          <div className="space-y-3">
            <div>
              <Label htmlFor="vn">Name</Label>
              <Input id="vn" value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} />
            </div>
            <div>
              <Label htmlFor="vp">Phone</Label>
              <Input
                id="vp"
                inputMode="tel"
                value={form.phone}
                onChange={(e) => setForm({ ...form, phone: e.target.value })}
              />
            </div>
            <div>
              <Label htmlFor="va">Address</Label>
              <Input
                id="va"
                value={form.address}
                onChange={(e) => setForm({ ...form, address: e.target.value })}
              />
            </div>
          </div>
          <DialogFooter>
            <Button variant="ghost" onClick={() => setOpen(false)}>
              Cancel
            </Button>
            <Button onClick={() => void addVendor()}>Save</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </PosShell>
  );
}
