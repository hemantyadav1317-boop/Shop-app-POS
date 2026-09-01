import { useMemo, useState } from "react";
import { Search } from "lucide-react";
import { CATEGORIES, PRODUCTS } from "@/lib/pos-data";
import { usePos } from "@/lib/pos-store";
import { Input } from "@/components/ui/input";

export function ProductGrid() {
  const { add, cart } = usePos();
  const [cat, setCat] = useState<string>("All");
  const [q, setQ] = useState("");

  const items = useMemo(() => {
    const term = q.trim().toLowerCase();
    return PRODUCTS.filter(
      (p) => (cat === "All" || p.category === cat) && (!term || p.name.toLowerCase().includes(term)),
    );
  }, [cat, q]);

  const qtyOf = (id: string) => cart.find((l) => l.id === id)?.qty ?? 0;

  return (
    <div className="flex h-full min-h-0 flex-col gap-3 p-3">
      <div className="-mx-3 flex gap-2 overflow-x-auto px-3 pb-1 [scrollbar-width:none]">
        {CATEGORIES.map((c) => (
          <button
            key={c}
            type="button"
            onClick={() => setCat(c)}
            className={`shrink-0 rounded-xl border px-4 py-2.5 text-xs font-semibold uppercase tracking-wide transition-colors ${
              cat === c
                ? "border-primary bg-accent text-accent-foreground"
                : "border-border bg-card text-muted-foreground"
            }`}
          >
            {c}
          </button>
        ))}
      </div>

      <div className="relative">
        <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
        <Input
          value={q}
          onChange={(e) => setQ(e.target.value)}
          placeholder="Search product"
          aria-label="Search product"
          className="h-11 bg-card pl-9"
        />
      </div>

      <div className="min-h-0 flex-1 overflow-y-auto pb-2">
        <div className="grid grid-cols-2 gap-2.5 sm:grid-cols-3 xl:grid-cols-4">
          {items.map((p) => {
            const qty = qtyOf(p.id);
            return (
              <button
                key={p.id}
                type="button"
                onClick={() => add(p)}
                className={`flex min-w-0 flex-col items-center gap-1 rounded-2xl border p-3 text-center shadow-[var(--shadow-tile)] transition-transform active:scale-[0.97] ${
                  qty > 0 ? "border-primary bg-accent" : "border-transparent bg-tile"
                }`}
              >
                <span className="line-clamp-2 min-h-[2.5rem] text-sm font-medium text-tile-foreground">
                  {p.name}
                </span>
                <span className="text-base font-black text-primary">Rs {p.price}</span>
                <span className="text-xs text-muted-foreground">
                  {qty > 0 ? `${qty} ${p.unit}` : `0 ${p.unit}`}
                </span>
              </button>
            );
          })}
          {items.length === 0 && (
            <p className="col-span-full py-10 text-center text-sm text-muted-foreground">
              Koi product nahi mila.
            </p>
          )}
        </div>
      </div>
    </div>
  );
}
