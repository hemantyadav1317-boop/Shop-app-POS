import { createFileRoute } from "@tanstack/react-router";
import { useMemo, useState } from "react";
import { PosShell } from "@/components/pos/PosShell";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { useShop } from "@/lib/shop";
import { useExpenses, usePayments, usePurchases, useSales } from "@/lib/queries";

export const Route = createFileRoute("/_authenticated/daybook")({
  head: () => ({
    meta: [
      { title: "DayBook — Shop POS" },
      { name: "description", content: "Ek din ki sale, payment, purchase aur kharche ka pura hisaab." },
      { property: "og:title", content: "DayBook — Shop POS" },
      { property: "og:description", content: "Ek din ki sale, payment, purchase aur kharche ka pura hisaab." },
    ],
  }),
  component: DayBookPage,
});

type Entry = { id: string; time: string; label: string; kind: "in" | "out"; amount: number };

function DayBookPage() {
  const { shop } = useShop();
  const [day, setDay] = useState(new Date().toISOString().slice(0, 10));
  const { data: sales } = useSales(shop?.id);
  const { data: payments } = usePayments(shop?.id);
  const { data: purchases } = usePurchases(shop?.id);
  const { data: expenses } = useExpenses(shop?.id);

  const sameDay = (iso: string) => iso.slice(0, 10) === day;

  const entries = useMemo<Entry[]>(() => {
    const list: Entry[] = [];
    (payments ?? [])
      .filter((p) => sameDay(p.created_at))
      .forEach((p) =>
        list.push({
          id: `pay-${p.id}`,
          time: p.created_at,
          label: `Payment received (${p.mode})`,
          kind: "in",
          amount: Number(p.amount),
        }),
      );
    (purchases ?? [])
      .filter((p) => sameDay(p.created_at))
      .forEach((p) =>
        list.push({
          id: `pur-${p.id}`,
          time: p.created_at,
          label: `Purchase — ${p.vendor_name ?? "Vendor"}`,
          kind: "out",
          amount: Number(p.paid),
        }),
      );
    (expenses ?? [])
      .filter((e) => e.spent_on === day)
      .forEach((e) =>
        list.push({
          id: `exp-${e.id}`,
          time: e.created_at,
          label: `Expense — ${e.category}`,
          kind: "out",
          amount: Number(e.amount),
        }),
      );
    return list.sort((a, b) => (a.time < b.time ? 1 : -1));
  }, [payments, purchases, expenses, day]);

  const daySales = (sales ?? []).filter((s) => sameDay(s.created_at));
  const salesTotal = daySales.reduce((s, x) => s + Number(x.total), 0);
  const cashIn = entries.filter((e) => e.kind === "in").reduce((s, e) => s + e.amount, 0);
  const cashOut = entries.filter((e) => e.kind === "out").reduce((s, e) => s + e.amount, 0);

  return (
    <PosShell title="DayBook">
      <div className="flex h-full min-h-0 flex-col gap-3 p-3">
        <div>
          <Label htmlFor="day">Date</Label>
          <Input
            id="day"
            type="date"
            value={day}
            onChange={(e) => setDay(e.target.value)}
            className="h-11 bg-card"
          />
        </div>

        <div className="grid grid-cols-2 gap-2 sm:grid-cols-4">
          <Stat label="Bills" value={String(daySales.length)} />
          <Stat label="Sales" value={`Rs ${salesTotal.toFixed(2)}`} />
          <Stat label="Cash in" value={`Rs ${cashIn.toFixed(2)}`} />
          <Stat label="Cash out" value={`Rs ${cashOut.toFixed(2)}`} />
        </div>

        <div className="min-h-0 flex-1 overflow-y-auto">
          {entries.length === 0 ? (
            <p className="py-16 text-center text-sm text-muted-foreground">Is din ka koi entry nahi hai.</p>
          ) : (
            <ul className="space-y-2">
              {entries.map((e) => (
                <li
                  key={e.id}
                  className="grid grid-cols-[minmax(0,1fr)_auto] items-center gap-3 rounded-2xl bg-card p-3 shadow-[var(--shadow-tile)]"
                >
                  <div className="min-w-0">
                    <p className="truncate text-sm font-semibold">{e.label}</p>
                    <p className="truncate text-xs text-muted-foreground">
                      {new Date(e.time).toLocaleTimeString("en-IN")}
                    </p>
                  </div>
                  <span
                    className={`shrink-0 font-bold ${e.kind === "in" ? "text-primary" : "text-destructive"}`}
                  >
                    {e.kind === "in" ? "+" : "−"} Rs {e.amount.toFixed(2)}
                  </span>
                </li>
              ))}
            </ul>
          )}
        </div>
      </div>
    </PosShell>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-2xl bg-card p-3 shadow-[var(--shadow-tile)]">
      <p className="truncate text-xs text-muted-foreground">{label}</p>
      <p className="truncate text-lg font-black">{value}</p>
    </div>
  );
}
