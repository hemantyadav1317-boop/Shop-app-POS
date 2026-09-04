import { useMemo, useState } from "react";
import { Search } from "lucide-react";
import { Input } from "@/components/ui/input";
import { useShop } from "@/lib/shop";
import { useProducts } from "@/lib/queries";
import { useCart } from "@/lib/cart";
import { Skeleton } from "@/components/ui/skeleton";

export function ProductGrid() {
  const { shop } = useShop();
  const { data: products, isLoading } = useProducts(shop?.id);
  const { addLine, lines } = useCart();
  const [cat, setCat] = useState("All");
  const [q, setQ] = useState("");

  const categories = useMemo(
    () => ["All", ...Array.from(new Set((products ?? []).map((p) => p.category)))],
    [products],
  );

  const items = useMemo(() => {
    const term = q.trim().toLowerCase();
    return (products ?? []).filter(
      (p) => (cat === "All" || p.category === cat) && (!term || p.name.toLowerCase().includes(term)),
    );
  }, [products, cat, q]);

  const qtyOf = (id: string) => lines.find((l) => l.product_id === id)?.qty ?? 0;

  return (
    <div className="flex h-full min-h-0 flex-col gap-3 p-3">
      <div className="-mx-3 flex gap-2 overflow-x-auto px-3 pb-1 [scrollbar-width:none]">
        {categories.map((c) => (
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
        {isLoading ? (
          <div className="grid grid-cols-2 gap-2.5 sm:grid-cols-3 xl:grid-cols-4">
            {Array.from({ length: 8 }).map((_, i) => (
              <Skeleton key={i} className="h-24 rounded-2xl" />
            ))}
          </div>
        ) : (
          <div className="grid grid-cols-2 gap-2.5 sm:grid-cols-3 xl:grid-cols-4">
            {items.map((p) => {
              const qty = qtyOf(p.id);
              const low = p.stock <= p.low_stock_at;
              return (
                <button
                  key={p.id}
                  type="button"
                  onClick={() =>
                    addLine({ product_id: p.id, name: p.name, price: Number(p.price), unit: p.unit })
                  }
                  className={`flex min-w-0 flex-col items-center gap-1 rounded-2xl border p-3 text-center shadow-[var(--shadow-tile)] transition-transform active:scale-[0.97] ${
                    qty > 0 ? "border-primary bg-accent" : "border-transparent bg-tile"
                  }`}
                >
                  <span className="line-clamp-2 min-h-[2.5rem] text-sm font-medium text-tile-foreground">
                    {p.name}
                  </span>
                  <span className="text-base font-black text-primary">Rs {Number(p.price)}</span>
                  <span className={`text-xs ${low ? "text-destructive" : "text-muted-foreground"}`}>
                    {qty > 0 ? `${qty} ${p.unit} in cart` : `Stock ${Number(p.stock)} ${p.unit}`}
                  </span>
                </button>
              );
            })}
            {items.length === 0 && (
              <p className="col-span-full py-10 text-center text-sm text-muted-foreground">
                Koi product nahi mila. Inventory me product add karein.
              </p>
            )}
          </div>
        )}
      </div>
    </div>
  );
}
