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
import { useExpenses, useInvalidatePos } from "@/lib/queries";
import { supabase } from "@/integrations/supabase/client";

export const Route = createFileRoute("/_authenticated/expenses")({
  head: () => ({
    meta: [
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
      { title: "Expenses — Shop POS" },
      { name: "description", content: "Dukaan ke kharche record karein — reports aur profit me shamil." },
      { property: "og:title", content: "Expenses — Shop POS" },
      { property: "og:description", content: "Dukaan ke kharche record karein — reports aur profit me shamil." },
    ],
  }),
  component: ExpensesPage,
});

function ExpensesPage() {
  const { shop } = useShop();
  const { data: expenses, isLoading } = useExpenses(shop?.id);
  const invalidate = useInvalidatePos();
  const [open, setOpen] = useState(false);
  const [form, setForm] = useState({
    category: "General",
    amount: "",
    note: "",
    spent_on: new Date().toISOString().slice(0, 10),
  });

  const total = (expenses ?? []).reduce((s, e) => s + Number(e.amount), 0);

  async function save() {
    if (!shop || !(Number(form.amount) > 0)) return;
    const { error } = await supabase.from("expenses").insert({
      shop_id: shop.id,
      category: form.category.trim() || "General",
      amount: Number(form.amount),
      note: form.note.trim() || null,
      spent_on: form.spent_on,
    });
    if (error) {
      toast.error(error.message);
      return;
    }
    invalidate();
    setOpen(false);
    setForm({ ...form, amount: "", note: "" });
    toast.success("Expense added");
  }

  async function remove(id: string) {
    const { error } = await supabase.from("expenses").delete().eq("id", id);
    if (error) toast.error(error.message);
    else {
      invalidate();
      toast.success("Deleted");
    }
  }

  return (
    <PosShell
      title="Expenses"
      headerRight={
        <Button size="sm" onClick={() => setOpen(true)}>
          <Plus className="mr-1 h-4 w-4" /> Add
        </Button>
      }
    >
      <div className="flex h-full min-h-0 flex-col gap-3 p-3">
        <div className="rounded-2xl bg-card p-3 shadow-[var(--shadow-tile)]">
          <p className="text-xs text-muted-foreground">Total expenses</p>
          <p className="text-xl font-black">Rs {total.toFixed(2)}</p>
        </div>

        <div className="min-h-0 flex-1 overflow-y-auto">
          {isLoading ? (
            <p className="py-10 text-center text-sm text-muted-foreground">Loading…</p>
          ) : !expenses?.length ? (
            <p className="py-16 text-center text-sm text-muted-foreground">Koi kharcha record nahi hua.</p>
          ) : (
            <ul className="space-y-2">
              {expenses.map((e) => (
                <li
                  key={e.id}
                  className="grid grid-cols-[minmax(0,1fr)_auto_auto] items-center gap-2 rounded-2xl bg-card p-3 shadow-[var(--shadow-tile)]"
                >
                  <div className="min-w-0">
                    <p className="truncate text-sm font-semibold">{e.category}</p>
                    <p className="truncate text-xs text-muted-foreground">
                      {e.spent_on} {e.note ? `· ${e.note}` : ""}
                    </p>
                  </div>
                  <span className="shrink-0 font-bold">Rs {Number(e.amount).toFixed(2)}</span>
                  <Button
                    size="icon"
                    variant="ghost"
                    aria-label="Delete expense"
                    onClick={() => void remove(e.id)}
                  >
                    <Trash2 className="h-4 w-4" />
                  </Button>
                </li>
              ))}
            </ul>
          )}
        </div>
      </div>

      <Dialog open={open} onOpenChange={setOpen}>
        <DialogContent className="sm:max-w-sm">
          <DialogHeader>
            <DialogTitle>Add expense</DialogTitle>
          </DialogHeader>
          <div className="space-y-3">
            <div>
              <Label htmlFor="ec">Category</Label>
              <Input
                id="ec"
                value={form.category}
                onChange={(e) => setForm({ ...form, category: e.target.value })}
              />
            </div>
            <div>
              <Label htmlFor="ea">Amount</Label>
              <Input
                id="ea"
                inputMode="decimal"
                value={form.amount}
                onChange={(e) => setForm({ ...form, amount: e.target.value })}
              />
            </div>
            <div>
              <Label htmlFor="ed">Date</Label>
              <Input
                id="ed"
                type="date"
                value={form.spent_on}
                onChange={(e) => setForm({ ...form, spent_on: e.target.value })}
              />
            </div>
            <div>
              <Label htmlFor="en">Note</Label>
              <Input id="en" value={form.note} onChange={(e) => setForm({ ...form, note: e.target.value })} />
            </div>
          </div>
          <DialogFooter>
            <Button variant="ghost" onClick={() => setOpen(false)}>
              Cancel
            </Button>
            <Button onClick={() => void save()}>Save</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </PosShell>
  );
}
