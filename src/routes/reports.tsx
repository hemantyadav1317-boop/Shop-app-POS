import { createFileRoute } from "@tanstack/react-router";
import { useMemo } from "react";
import { PosShell } from "@/components/pos/PosShell";
import { usePos } from "@/lib/pos-store";
import { formatRs } from "@/lib/pos-data";

export const Route = createFileRoute("/reports")({
  head: () => ({
    meta: [
      { title: "Sales Report — Shop POS" },
      { name: "description", content: "Aaj ki sale, kul bills aur top selling items ka summary." },
      { property: "og:title", content: "Sales Report — Shop POS" },
      { property: "og:description", content: "Aaj ki sale, kul bills aur top selling items ka summary." },
    ],
  }),
  component: ReportsPage,
});

function ReportsPage() {
  const { bills } = usePos();

  const stats = useMemo(() => {
    const today = new Date().toDateString();
    const todays = bills.filter((b) => new Date(b.createdAt).toDateString() === today);
    const totals = new Map<string, number>();
    for (const b of bills) {
      for (const l of b.lines) totals.set(l.name, (totals.get(l.name) ?? 0) + l.price * l.qty);
    }
    return {
      todaySale: todays.reduce((s, b) => s + b.total, 0),
      todayBills: todays.length,
      allSale: bills.reduce((s, b) => s + b.total, 0),
      top: [...totals.entries()].sort((a, b) => b[1] - a[1]).slice(0, 8),
    };
  }, [bills]);

  return (
    <PosShell title="Report">
      <div className="h-full overflow-y-auto p-3">
        <div className="grid grid-cols-2 gap-2.5 sm:grid-cols-3">
          {[
            { label: "Aaj ki Sale", value: formatRs(stats.todaySale) },
            { label: "Aaj ke Bills", value: String(stats.todayBills) },
            { label: "Total Sale", value: formatRs(stats.allSale) },
          ].map((s) => (
            <div key={s.label} className="rounded-2xl bg-card p-3 shadow-[var(--shadow-tile)]">
              <p className="truncate text-xs text-muted-foreground">{s.label}</p>
              <p className="mt-1 truncate text-lg font-black text-primary">{s.value}</p>
            </div>
          ))}
        </div>

        <h2 className="mt-5 text-sm font-bold">Top Items</h2>
        {stats.top.length === 0 ? (
          <p className="py-10 text-center text-sm text-muted-foreground">Data ke liye pehla bill banaiye.</p>
        ) : (
          <ul className="mt-2 space-y-2">
            {stats.top.map(([name, amount]) => (
              <li
                key={name}
                className="grid grid-cols-[minmax(0,1fr)_auto] gap-3 rounded-2xl bg-card p-3 text-sm shadow-[var(--shadow-tile)]"
              >
                <span className="truncate">{name}</span>
                <span className="shrink-0 font-bold">{formatRs(amount)}</span>
              </li>
            ))}
          </ul>
        )}
      </div>
    </PosShell>
  );
}
