import { createFileRoute } from "@tanstack/react-router";
import { useMemo, useState } from "react";
import { Download } from "lucide-react";
import { PosShell } from "@/components/pos/PosShell";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { useShop } from "@/lib/shop";
import { useCustomers, useExpenses, useProducts, usePurchases, useSales } from "@/lib/queries";
import { downloadCsv } from "@/lib/receipt";

export const Route = createFileRoute("/_authenticated/reports")({
  head: () => ({
    meta: [
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
      { title: "Reports — Shop POS" },
      { name: "description", content: "Sale, purchase, kharcha aur profit ka summary report — CSV export ke saath." },
      { property: "og:title", content: "Reports — Shop POS" },
      { property: "og:description", content: "Sale, purchase, kharcha aur profit ka summary report — CSV export ke saath." },
    ],
  }),
  component: ReportsPage,
});

function ReportsPage() {
  const { shop } = useShop();
  const today = new Date().toISOString().slice(0, 10);
  const monthStart = `${today.slice(0, 7)}-01`;
  const [from, setFrom] = useState(monthStart);
  const [to, setTo] = useState(today);

  const { data: sales } = useSales(shop?.id);
  const { data: purchases } = usePurchases(shop?.id);
  const { data: expenses } = useExpenses(shop?.id);
  const { data: products } = useProducts(shop?.id);
  const { data: customers } = useCustomers(shop?.id);

  const inRange = (d: string) => d >= from && d <= to;

  const s = useMemo(() => (sales ?? []).filter((x) => inRange(x.created_at.slice(0, 10))), [sales, from, to]);
  const p = useMemo(
    () => (purchases ?? []).filter((x) => inRange(x.created_at.slice(0, 10))),
    [purchases, from, to],
  );
  const e = useMemo(() => (expenses ?? []).filter((x) => inRange(x.spent_on)), [expenses, from, to]);

  const salesTotal = s.reduce((a, x) => a + Number(x.total), 0);
  const collected = s.reduce((a, x) => a + Number(x.paid), 0);
  const dueTotal = s.reduce((a, x) => a + Number(x.due), 0);
  const purchaseTotal = p.reduce((a, x) => a + Number(x.total), 0);
  const expenseTotal = e.reduce((a, x) => a + Number(x.amount), 0);
  const netCash = collected - p.reduce((a, x) => a + Number(x.paid), 0) - expenseTotal;

  const stockValue = (products ?? []).reduce((a, x) => a + Number(x.stock) * Number(x.cost_price), 0);
  const outstanding = (customers ?? []).reduce((a, x) => a + Number(x.balance), 0);

  function exportCsv() {
    const rows: Record<string, unknown>[] = [
      { Metric: "From", Value: from },
      { Metric: "To", Value: to },
      { Metric: "Bills", Value: s.length },
      { Metric: "Sales total", Value: salesTotal.toFixed(2) },
      { Metric: "Collected", Value: collected.toFixed(2) },
      { Metric: "Credit (due)", Value: dueTotal.toFixed(2) },
      { Metric: "Purchases", Value: purchaseTotal.toFixed(2) },
      { Metric: "Expenses", Value: expenseTotal.toFixed(2) },
      { Metric: "Net cash", Value: netCash.toFixed(2) },
      { Metric: "Stock value", Value: stockValue.toFixed(2) },
      { Metric: "Customer outstanding", Value: outstanding.toFixed(2) },
    ];
    downloadCsv(`report-${from}-to-${to}.csv`, rows);
  }

  const topProducts = useMemo(() => {
    const map = new Map<string, number>();
    (products ?? []).forEach((pr) => map.set(pr.name, Number(pr.stock)));
    return [...map.entries()].sort((a, b) => a[1] - b[1]).slice(0, 5);
  }, [products]);

  return (
    <PosShell
      title="Reports"
      headerRight={
        <Button size="sm" variant="outline" onClick={exportCsv}>
          <Download className="mr-1 h-4 w-4" /> CSV
        </Button>
      }
    >
      <div className="h-full overflow-y-auto p-3">
        <div className="grid grid-cols-2 gap-2">
          <div>
            <Label htmlFor="from">From</Label>
            <Input id="from" type="date" value={from} onChange={(ev) => setFrom(ev.target.value)} className="h-11 bg-card" />
          </div>
          <div>
            <Label htmlFor="to">To</Label>
            <Input id="to" type="date" value={to} onChange={(ev) => setTo(ev.target.value)} className="h-11 bg-card" />
          </div>
        </div>

        <div className="mt-3 grid grid-cols-2 gap-2 sm:grid-cols-3 xl:grid-cols-4">
          <Stat label="Bills" value={String(s.length)} />
          <Stat label="Sales" value={`Rs ${salesTotal.toFixed(2)}`} />
          <Stat label="Collected" value={`Rs ${collected.toFixed(2)}`} />
          <Stat label="Credit due" value={`Rs ${dueTotal.toFixed(2)}`} tone="bad" />
          <Stat label="Purchases" value={`Rs ${purchaseTotal.toFixed(2)}`} />
          <Stat label="Expenses" value={`Rs ${expenseTotal.toFixed(2)}`} />
          <Stat label="Net cash" value={`Rs ${netCash.toFixed(2)}`} tone={netCash >= 0 ? "good" : "bad"} />
          <Stat label="Stock value" value={`Rs ${stockValue.toFixed(2)}`} />
          <Stat label="Customer outstanding" value={`Rs ${outstanding.toFixed(2)}`} tone="bad" />
        </div>

        <h2 className="mt-5 text-sm font-bold">Lowest stock</h2>
        <ul className="mt-2 space-y-2">
          {topProducts.map(([name, qty]) => (
            <li
              key={name}
              className="grid grid-cols-[minmax(0,1fr)_auto] items-center gap-3 rounded-2xl bg-card p-3 shadow-[var(--shadow-tile)]"
            >
              <span className="truncate text-sm">{name}</span>
              <span className="shrink-0 text-sm font-bold">{qty}</span>
            </li>
          ))}
          {topProducts.length === 0 && (
            <p className="py-10 text-center text-sm text-muted-foreground">Abhi koi product nahi hai.</p>
          )}
        </ul>
      </div>
    </PosShell>
  );
}

function Stat({ label, value, tone }: { label: string; value: string; tone?: "good" | "bad" }) {
  return (
    <div className="rounded-2xl bg-card p-3 shadow-[var(--shadow-tile)]">
      <p className="truncate text-xs text-muted-foreground">{label}</p>
      <p
        className={`truncate text-lg font-black ${tone === "bad" ? "text-destructive" : tone === "good" ? "text-primary" : ""}`}
      >
        {value}
      </p>
    </div>
  );
}
