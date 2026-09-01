import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { PosShell } from "@/components/pos/PosShell";
import { usePos } from "@/lib/pos-store";
import { formatRs } from "@/lib/pos-data";
import { Button } from "@/components/ui/button";

export const Route = createFileRoute("/saved")({
  head: () => ({
    meta: [
      { title: "Saved Orders — Shop POS" },
      { name: "description", content: "Rukavat wale orders ko save karke baad me continue karein." },
      { property: "og:title", content: "Saved Orders — Shop POS" },
      { property: "og:description", content: "Rukavat wale orders ko save karke baad me continue karein." },
    ],
  }),
  component: SavedPage,
});

function SavedPage() {
  const { savedOrders, resumeOrder, deleteSavedOrder } = usePos();
  const navigate = useNavigate();

  return (
    <PosShell title="Saved Orders">
      <div className="h-full overflow-y-auto p-3">
        {savedOrders.length === 0 ? (
          <p className="py-16 text-center text-sm text-muted-foreground">Koi saved order nahi.</p>
        ) : (
          <ul className="space-y-2.5">
            {savedOrders.map((o) => {
              const total = o.lines.reduce((s, l) => s + l.price * l.qty, 0);
              return (
                <li key={o.id} className="rounded-2xl bg-card p-3 shadow-[var(--shadow-tile)]">
                  <div className="grid grid-cols-[minmax(0,1fr)_auto] items-center gap-3">
                    <div className="min-w-0">
                      <p className="truncate text-sm font-semibold">{o.customer?.name ?? "Walk-in"}</p>
                      <p className="truncate text-xs text-muted-foreground">
                        {new Date(o.createdAt).toLocaleString("en-IN")} · {o.lines.length} items
                      </p>
                    </div>
                    <span className="shrink-0 font-black text-primary">{formatRs(total)}</span>
                  </div>
                  <div className="mt-2 grid grid-cols-2 gap-2">
                    <Button
                      size="sm"
                      onClick={() => {
                        resumeOrder(o.id);
                        navigate({ to: "/" });
                      }}
                    >
                      Continue
                    </Button>
                    <Button size="sm" variant="outline" className="text-destructive" onClick={() => deleteSavedOrder(o.id)}>
                      Delete
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
