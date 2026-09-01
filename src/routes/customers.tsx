import { createFileRoute } from "@tanstack/react-router";
import { useMemo } from "react";
import { PosShell } from "@/components/pos/PosShell";
import { usePos } from "@/lib/pos-store";
import { formatRs } from "@/lib/pos-data";

export const Route = createFileRoute("/customers")({
  head: () => ({
    meta: [
      { title: "Customers — Shop POS" },
      { name: "description", content: "Grahakon ki list, unke bills aur kul kharch ka hisaab." },
      { property: "og:title", content: "Customers — Shop POS" },
      { property: "og:description", content: "Grahakon ki list, unke bills aur kul kharch ka hisaab." },
    ],
  }),
  component: CustomersPage,
});

function CustomersPage() {
  const { bills } = usePos();

  const rows = useMemo(() => {
    const map = new Map<string, { name: string; phone: string; count: number; total: number }>();
    for (const b of bills) {
      if (!b.customer) continue;
      const key = b.customer.phone || b.customer.name;
      const prev = map.get(key) ?? { name: b.customer.name, phone: b.customer.phone, count: 0, total: 0 };
      map.set(key, { ...prev, count: prev.count + 1, total: prev.total + b.total });
    }
    return [...map.values()].sort((a, b) => b.total - a.total);
  }, [bills]);

  return (
    <PosShell title="Customer Management">
      <div className="h-full overflow-y-auto p-3">
        {rows.length === 0 ? (
          <p className="py-16 text-center text-sm text-muted-foreground">
            Abhi koi customer nahi. Bill banate waqt customer details add karein.
          </p>
        ) : (
          <ul className="space-y-2.5">
            {rows.map((c) => (
              <li
                key={c.phone || c.name}
                className="grid grid-cols-[minmax(0,1fr)_auto] items-center gap-3 rounded-2xl bg-card p-3 shadow-[var(--shadow-tile)]"
              >
                <div className="min-w-0">
                  <p className="truncate text-sm font-semibold">{c.name}</p>
                  <p className="truncate text-xs text-muted-foreground">
                    {c.phone || "—"} · {c.count} bills
                  </p>
                </div>
                <span className="shrink-0 font-black text-primary">{formatRs(c.total)}</span>
              </li>
            ))}
          </ul>
        )}
      </div>
    </PosShell>
  );
}
