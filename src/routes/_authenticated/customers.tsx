import { createFileRoute } from "@tanstack/react-router";
import { useMemo, useState } from "react";
import { Plus, Search, Wallet } from "lucide-react";
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
import { useCustomers, useInvalidatePos, type DbCustomer } from "@/lib/queries";
import { supabase } from "@/integrations/supabase/client";

export const Route = createFileRoute("/_authenticated/customers")({
  head: () => ({
    meta: [
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
      { title: "Customers & Khata — Shop POS" },
      { name: "description", content: "Customer add karein, udhaar balance dekhein aur payment collect karein." },
      { property: "og:title", content: "Customers & Khata — Shop POS" },
      { property: "og:description", content: "Customer add karein, udhaar balance dekhein aur payment collect karein." },
    ],
  }),
  component: CustomersPage,
});

function CustomersPage() {
  const { shop } = useShop();
  const { data: customers, isLoading } = useCustomers(shop?.id);
  const invalidate = useInvalidatePos();
  const [q, setQ] = useState("");
  const [addOpen, setAddOpen] = useState(false);
  const [form, setForm] = useState({ name: "", phone: "", address: "" });
  const [collect, setCollect] = useState<DbCustomer | null>(null);
  const [amount, setAmount] = useState("");
  const [mode, setMode] = useState<"cash" | "online">("cash");

  const rows = useMemo(() => {
    const term = q.trim().toLowerCase();
    return (customers ?? []).filter(
      (c) => !term || c.name.toLowerCase().includes(term) || (c.phone ?? "").includes(term),
    );
  }, [customers, q]);

  const totalDue = rows.reduce((s, c) => s + Number(c.balance), 0);

  async function addCustomer() {
    if (!shop || !form.name.trim()) return;
    const { error } = await supabase.from("customers").insert({
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
    setAddOpen(false);
    setForm({ name: "", phone: "", address: "" });
    toast.success("Customer added");
  }

  async function collectDue() {
    if (!shop || !collect) return;
    const amt = Number(amount) || 0;
    if (amt <= 0) return;
    const { error } = await supabase.rpc("collect_due", {
      _shop_id: shop.id,
      _customer_id: collect.id,
      _amount: amt,
      _mode: mode,
    });
    if (error) {
      toast.error(error.message);
      return;
    }
    invalidate();
    setCollect(null);
    setAmount("");
    toast.success("Payment collected");
  }

  return (
    <PosShell
      title="Customers"
      headerRight={
        <Button size="sm" onClick={() => setAddOpen(true)}>
          <Plus className="mr-1 h-4 w-4" /> Add
        </Button>
      }
    >
      <div className="flex h-full min-h-0 flex-col gap-3 p-3">
        <div className="rounded-2xl bg-card p-3 shadow-[var(--shadow-tile)]">
          <p className="text-xs text-muted-foreground">Total outstanding</p>
          <p className="text-xl font-black text-destructive">Rs {totalDue.toFixed(2)}</p>
        </div>

        <div className="relative">
          <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
          <Input
            value={q}
            onChange={(e) => setQ(e.target.value)}
            placeholder="Name ya phone"
            aria-label="Search customers"
            className="h-11 bg-card pl-9"
          />
        </div>

        <div className="min-h-0 flex-1 overflow-y-auto">
          {isLoading ? (
            <p className="py-10 text-center text-sm text-muted-foreground">Loading…</p>
          ) : (
            <ul className="space-y-2">
              {rows.map((c) => (
                <li
                  key={c.id}
                  className="grid grid-cols-[minmax(0,1fr)_auto] items-center gap-3 rounded-2xl bg-card p-3 shadow-[var(--shadow-tile)]"
                >
                  <div className="min-w-0">
                    <p className="truncate text-sm font-semibold">{c.name}</p>
                    <p className="truncate text-xs text-muted-foreground">{c.phone ?? "—"}</p>
                  </div>
                  <div className="flex shrink-0 items-center gap-2">
                    <span
                      className={`text-sm font-bold ${Number(c.balance) > 0 ? "text-destructive" : "text-muted-foreground"}`}
                    >
                      Rs {Number(c.balance).toFixed(2)}
                    </span>
                    <Button
                      size="sm"
                      variant="outline"
                      disabled={Number(c.balance) <= 0}
                      onClick={() => {
                        setCollect(c);
                        setAmount(String(c.balance));
                      }}
                    >
                      <Wallet className="mr-1 h-4 w-4" /> Collect
                    </Button>
                  </div>
                </li>
              ))}
              {rows.length === 0 && (
                <p className="py-16 text-center text-sm text-muted-foreground">Koi customer nahi mila.</p>
              )}
            </ul>
          )}
        </div>
      </div>

      <Dialog open={addOpen} onOpenChange={setAddOpen}>
        <DialogContent className="sm:max-w-sm">
          <DialogHeader>
            <DialogTitle>Add customer</DialogTitle>
          </DialogHeader>
          <div className="space-y-3">
            <div>
              <Label htmlFor="n">Name</Label>
              <Input id="n" value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} />
            </div>
            <div>
              <Label htmlFor="p">Phone</Label>
              <Input
                id="p"
                inputMode="tel"
                value={form.phone}
                onChange={(e) => setForm({ ...form, phone: e.target.value })}
              />
            </div>
            <div>
              <Label htmlFor="a">Address</Label>
              <Input
                id="a"
                value={form.address}
                onChange={(e) => setForm({ ...form, address: e.target.value })}
              />
            </div>
          </div>
          <DialogFooter>
            <Button variant="ghost" onClick={() => setAddOpen(false)}>
              Cancel
            </Button>
            <Button onClick={() => void addCustomer()}>Save</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <Dialog open={!!collect} onOpenChange={(v) => !v && setCollect(null)}>
        <DialogContent className="sm:max-w-sm">
          <DialogHeader>
            <DialogTitle>Collect from {collect?.name}</DialogTitle>
          </DialogHeader>
          <div className="space-y-3">
            <div>
              <Label htmlFor="amt">Amount</Label>
              <Input
                id="amt"
                inputMode="decimal"
                value={amount}
                onChange={(e) => setAmount(e.target.value)}
                className="h-11"
              />
            </div>
            <div className="flex gap-2">
              {(["cash", "online"] as const).map((m) => (
                <Button
                  key={m}
                  variant={mode === m ? "default" : "outline"}
                  className="flex-1"
                  onClick={() => setMode(m)}
                >
                  {m}
                </Button>
              ))}
            </div>
          </div>
          <DialogFooter>
            <Button variant="ghost" onClick={() => setCollect(null)}>
              Cancel
            </Button>
            <Button onClick={() => void collectDue()}>Collect</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </PosShell>
  );
}
