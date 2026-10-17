import { useMemo, useState } from "react";
import { Search } from "lucide-react";
import { Input } from "@/components/ui/input";
import { useShop } from "@/lib/shop";
import { useProducts } from "@/lib/queries";
import { useCart } from "@/lib/cart";
import { Skeleton } from "@/components/ui/skeleton";
import { productIcon } from "@/lib/catalog";
import { QtyRateDialog, type QtyRateTarget } from "./QtyRateDialog";
import { Button } from "@/components/ui/button";
import { matchesProduct } from "@/lib/product-search";

export function ProductGrid() {
  const { shop } = useShop();
  const { data: products, isLoading, isError, refetch } = useProducts(shop?.id);
  const { lines } = useCart();
  const [target, setTarget] = useState<QtyRateTarget | null>(null);
  const [cat, setCat] = useState("All");
  const [q, setQ] = useState("");

  const categories = useMemo(
    () => ["All", ...Array.from(new Set((products ?? []).map((p) => p.category)))],
    [products],
  );

  const items = useMemo(() => {
    return (products ?? []).filter(
      (p) => (cat === "All" || p.category === cat) && matchesProduct(p, q),
    );
  }, [products, cat, q]);

  const qtyOf = (id: string) => lines.find((l) => l.product_id === id)?.qty ?? 0;

  return (
    <div className="flex h-full min-h-0 flex-col gap-3 p-3">
      <div className="-mx-3 flex gap-2 overflow-x-auto px-3 pb-1 [scrollbar-width:none]">
        {categories.map((c) => (
          <Button variant="outline"
            key={c}
            type="button"
            onClick={() => setCat(c)}
            aria-pressed={cat === c}
            className={`h-11 shrink-0 rounded-lg border px-4 text-sm font-medium ${
              cat === c
                ? "border-primary bg-accent text-accent-foreground"
                : "border-border bg-card text-muted-foreground"
            }`}
          >
            {c}
          </Button>
        ))}
      </div>

      <div className="relative">
        <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
        <Input
          value={q}
          onChange={(e) => setQ(e.target.value)}
          placeholder="Search name, SKU or barcode"
          aria-label="Search product"
          className="h-11 bg-card pl-9"
        />
      </div>

      <div className="min-h-0 flex-1 overflow-y-auto pb-2">
        {isError ? <div className="py-10 text-center"><p className="mb-3 text-sm text-destructive">Products could not be loaded</p><Button variant="outline" onClick={() => void refetch()}>Retry</Button></div> : isLoading ? (
          <div className="product-grid">
            {Array.from({ length: 8 }).map((_, i) => (
              <Skeleton key={i} className="h-48 rounded-lg" />
            ))}
          </div>
        ) : (
          <div className="product-grid">
            {items.map((p) => {
              const qty = qtyOf(p.id);
              const low = p.stock <= p.low_stock_at;
              return (
                <Button variant="ghost"
                  key={p.id}
                  type="button"
                  onClick={() =>
                    setTarget({
                      product_id: p.id,
                      name: p.name,
                      price: Number(p.price),
                      unit: p.unit,
                      category: p.category,
                      inCartQty: qty,
                      stock: Number(p.stock),
                    })
                  }
                  aria-label={`${p.name}, Rs ${Number(p.price)} per ${p.unit}`}
                  className={`relative flex h-auto min-h-48 min-w-0 flex-col items-stretch gap-1.5 whitespace-normal rounded-lg border p-3 text-left shadow-[var(--shadow-tile)] ${
                    qty > 0 ? "border-primary bg-accent hover:bg-accent" : "border-border bg-tile hover:bg-muted"
                  }`}
                >
                  {p.image_url ? <img src={p.image_url} alt={p.name} loading="lazy" className="h-16 w-full object-contain" /> : <span aria-hidden className="grid h-16 place-items-center text-4xl">{productIcon(p.name, p.category)}</span>}
                  <span className="line-clamp-2 min-h-10 text-sm font-semibold leading-5 text-tile-foreground">
                    {p.name}
                  </span>
                  {p.name_en && <span className="truncate text-xs text-muted-foreground">{p.name_en}</span>}
                  <span className="text-base font-bold tabular-nums text-foreground">Rs {Number(p.price)}<span className="text-xs font-normal text-muted-foreground"> / {p.unit}</span></span>
                  <span className={`text-xs ${low ? "text-destructive" : "text-muted-foreground"}`}>
                    {low ? "Low · " : ""}Stock {Number(p.stock)} {p.unit}
                  </span>
                  {qty > 0 && <span className="absolute right-2 top-2 rounded bg-primary px-1.5 py-0.5 text-xs font-semibold text-primary-foreground">{qty} {p.unit}</span>}
                </Button>
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

      <QtyRateDialog target={target} onClose={() => setTarget(null)} />
    </div>
  );
}
