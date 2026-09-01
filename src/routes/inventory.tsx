import { createFileRoute } from "@tanstack/react-router";
import { useState } from "react";
import { PosShell } from "@/components/pos/PosShell";
import { PRODUCTS } from "@/lib/pos-data";
import { Input } from "@/components/ui/input";

export const Route = createFileRoute("/inventory")({
  head: () => ({
    meta: [
      { title: "Inventory & Stock — Shop POS" },
      { name: "description", content: "Product ke rate aur stock ki poori list ek screen par." },
      { property: "og:title", content: "Inventory & Stock — Shop POS" },
      { property: "og:description", content: "Product ke rate aur stock ki poori list ek screen par." },
    ],
  }),
  component: InventoryPage,
});

function InventoryPage() {
  const [q, setQ] = useState("");
  const items = PRODUCTS.filter((p) => p.name.toLowerCase().includes(q.trim().toLowerCase()));

  return (
    <PosShell title="Inventory / Stock">
      <div className="flex h-full min-h-0 flex-col gap-3 p-3">
        <Input
          value={q}
          onChange={(e) => setQ(e.target.value)}
          placeholder="Search product"
          aria-label="Search product"
          className="h-11 bg-card"
        />
        <ul className="min-h-0 flex-1 space-y-2 overflow-y-auto">
          {items.map((p) => (
            <li
              key={p.id}
              className="grid grid-cols-[minmax(0,1fr)_auto] items-center gap-3 rounded-2xl bg-card p-3 shadow-[var(--shadow-tile)]"
            >
              <div className="min-w-0">
                <p className="truncate text-sm font-medium">{p.name}</p>
                <p className="truncate text-xs text-muted-foreground">{p.category}</p>
              </div>
              <div className="shrink-0 text-right">
                <p className="font-bold text-primary">Rs {p.price}</p>
                <p className={`text-xs ${p.stock < 10 ? "text-destructive" : "text-muted-foreground"}`}>
                  {p.stock} {p.unit} stock
                </p>
              </div>
            </li>
          ))}
        </ul>
      </div>
    </PosShell>
  );
}
