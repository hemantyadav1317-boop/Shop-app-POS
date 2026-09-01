import { createFileRoute } from "@tanstack/react-router";
import { PosShell } from "@/components/pos/PosShell";
import { usePos } from "@/lib/pos-store";
import { formatRs } from "@/lib/pos-data";

export const Route = createFileRoute("/bills")({
  head: () => ({
    meta: [
      { title: "Bill History — Shop POS" },
      { name: "description", content: "Sabhi purane bills, amount aur payment mode ek jagah dekhein." },
      { property: "og:title", content: "Bill History — Shop POS" },
      { property: "og:description", content: "Sabhi purane bills, amount aur payment mode ek jagah dekhein." },
    ],
  }),
  component: BillsPage,
});

function BillsPage() {
  const { bills } = usePos();

  return (
    <PosShell title="Bill History">
      <div className="h-full overflow-y-auto p-3">
        {bills.length === 0 ? (
          <p className="py-16 text-center text-sm text-muted-foreground">Abhi koi bill nahi bana.</p>
        ) : (
          <ul className="space-y-2.5">
            {bills.map((b) => (
              <li key={b.id} className="rounded-2xl bg-card p-3 shadow-[var(--shadow-tile)]">
                <div className="grid grid-cols-[minmax(0,1fr)_auto] items-center gap-3">
                  <div className="min-w-0">
                    <p className="truncate text-sm font-semibold">
                      Bill #{b.no} · {b.customer?.name ?? "Walk-in"}
                    </p>
                    <p className="truncate text-xs text-muted-foreground">
                      {new Date(b.createdAt).toLocaleString("en-IN")} · {b.lines.length} items · {b.payment}
                    </p>
                  </div>
                  <span className="shrink-0 text-base font-black text-primary">{formatRs(b.total)}</span>
                </div>
              </li>
            ))}
          </ul>
        )}
      </div>
    </PosShell>
  );
}
