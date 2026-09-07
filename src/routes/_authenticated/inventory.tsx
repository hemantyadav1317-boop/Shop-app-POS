import { createFileRoute } from "@tanstack/react-router";
import { useMemo, useState } from "react";
import { ChevronDown, Download, FolderPlus, Pencil, Plus, Search, Trash2 } from "lucide-react";
import { toast } from "sonner";
import { PosShell } from "@/components/pos/PosShell";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Dialog,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { useShop } from "@/lib/shop";
import { useInvalidatePos, useProducts, type DbProduct } from "@/lib/queries";
import { supabase } from "@/integrations/supabase/client";
import { downloadCsv } from "@/lib/receipt";
import { CATALOG, normalizeName } from "@/lib/catalog";

export const Route = createFileRoute("/_authenticated/inventory")({
  head: () => ({
    meta: [
      { title: "Inventory / Stock — Shop POS" },
      { name: "description", content: "Product aur category add/edit karein, stock aur low-stock alert dekhein." },
      { property: "og:title", content: "Inventory / Stock — Shop POS" },
      { property: "og:description", content: "Product aur category add/edit karein, stock aur low-stock alert dekhein." },
    ],
  }),
  component: InventoryPage,
});

type Draft = {
  id?: string;
  name: string;
  category: string;
  unit: "kg" | "pc";
  price: string;
  cost_price: string;
  stock: string;
  low_stock_at: string;
};

const empty: Draft = {
  name: "",
  category: "General",
  unit: "kg",
  price: "",
  cost_price: "",
  stock: "",
  low_stock_at: "5",
};

function toDraft(p: DbProduct): Draft {
  return {
    id: p.id,
    name: p.name,
    category: p.category,
    unit: p.unit,
    price: String(p.price),
    cost_price: String(p.cost_price),
    stock: String(p.stock),
    low_stock_at: String(p.low_stock_at),
  };
}

function InventoryPage() {
  const { shop } = useShop();
  const { data: products, isLoading } = useProducts(shop?.id);
  const invalidate = useInvalidatePos();
  const [tab, setTab] = useState<"products" | "categories">("products");
  const [q, setQ] = useState("");
  const [lowOnly, setLowOnly] = useState(false);
  const [draft, setDraft] = useState<Draft | null>(null);
  const [catEdit, setCatEdit] = useState<{ from: string; to: string } | null>(null);
  const [openCat, setOpenCat] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const rows = useMemo(() => {
    const term = q.trim().toLowerCase();
    return (products ?? []).filter(
      (p) =>
        (!term || p.name.toLowerCase().includes(term) || p.category.toLowerCase().includes(term)) &&
        (!lowOnly || Number(p.stock) <= Number(p.low_stock_at)),
    );
  }, [products, q, lowOnly]);

  const categories = useMemo(() => {
    const map = new Map<string, DbProduct[]>();
    for (const p of products ?? []) {
      const list = map.get(p.category) ?? [];
      list.push(p);
      map.set(p.category, list);
    }
    return Array.from(map.entries()).sort((a, b) => a[0].localeCompare(b[0]));
  }, [products]);

  async function save() {
    if (!shop || !draft?.name.trim()) return;
    const name = draft.name.trim();
    const clash = (products ?? []).find(
      (p) => p.id !== draft.id && normalizeName(p.name) === normalizeName(name),
    );
    if (clash) {
      toast.error(`"${clash.name}" pehle se hai — double product add nahi hoga.`);
      return;
    }
    const payload = {
      shop_id: shop.id,
      name,
      category: draft.category.trim() || "General",
      unit: draft.unit,
      price: Number(draft.price) || 0,
      cost_price: Number(draft.cost_price) || 0,
      stock: Number(draft.stock) || 0,
      low_stock_at: Number(draft.low_stock_at) || 0,
    };
    const { error } = draft.id
      ? await supabase.from("products").update(payload).eq("id", draft.id)
      : await supabase.from("products").insert(payload);
    if (error) {
      toast.error(error.message);
      return;
    }
    invalidate();
    setDraft(null);
    toast.success(draft.id ? "Product updated" : "Product added");
  }

  async function archive(id: string) {
    const { error } = await supabase.from("products").update({ is_active: false }).eq("id", id);
    if (error) toast.error(error.message);
    else {
      invalidate();
      toast.success("Product removed");
    }
  }

  async function renameCategory() {
    if (!shop || !catEdit) return;
    const to = catEdit.to.trim();
    if (!to || to === catEdit.from) return setCatEdit(null);
    const { error } = await supabase
      .from("products")
      .update({ category: to })
      .eq("shop_id", shop.id)
      .eq("category", catEdit.from);
    if (error) toast.error(error.message);
    else {
      invalidate();
      toast.success("Category updated");
    }
    setCatEdit(null);
  }

  /** Catalogue ke wo hi product add karta hai jo abhi list me nahi hain. */
  async function importCatalogue() {
    if (!shop) return;
    setBusy(true);
    const have = new Set((products ?? []).map((p) => normalizeName(p.name)));
    const missing = CATALOG.filter((c) => !have.has(normalizeName(c.name)));
    if (missing.length === 0) {
      setBusy(false);
      toast.info("Sab product pehle se list me hain.");
      return;
    }
    const { error } = await supabase.from("products").insert(
      missing.map((c) => ({
        shop_id: shop.id,
        name: c.name,
        category: c.category,
        unit: c.unit,
        price: c.price,
        stock: 0,
        low_stock_at: 5,
      })),
    );
    setBusy(false);
    if (error) toast.error(error.message);
    else {
      invalidate();
      toast.success(`${missing.length} naye product add hue`);
    }
  }

  /** Ek hi naam ke duplicate product hata deta hai (pehla rakhta hai). */
  async function removeDuplicates() {
    if (!shop) return;
    setBusy(true);
    const seen = new Set<string>();
    const dupes: string[] = [];
    for (const p of products ?? []) {
      const key = normalizeName(p.name);
      if (seen.has(key)) dupes.push(p.id);
      else seen.add(key);
    }
    if (dupes.length === 0) {
      setBusy(false);
      toast.info("Koi duplicate product nahi mila.");
      return;
    }
    const { error } = await supabase.from("products").update({ is_active: false }).in("id", dupes);
    setBusy(false);
    if (error) toast.error(error.message);
    else {
      invalidate();
      toast.success(`${dupes.length} duplicate hataye gaye`);
    }
  }

  return (
    <PosShell
      title="Inventory / Stock"
      headerRight={
        <div className="flex gap-2">
          <Button
            variant="outline"
            size="sm"
            aria-label="Export CSV"
            onClick={() =>
              downloadCsv(
                "inventory.csv",
                rows.map((p) => ({
                  name: p.name,
                  category: p.category,
                  unit: p.unit,
                  price: p.price,
                  cost: p.cost_price,
                  stock: p.stock,
                })),
              )
            }
          >
            <Download className="h-4 w-4" />
          </Button>
          <Button size="sm" onClick={() => setDraft(empty)}>
            <Plus className="mr-1 h-4 w-4" /> Add
          </Button>
        </div>
      }
    >
      <div className="flex h-full min-h-0 flex-col gap-3 p-3">
        <div className="grid grid-cols-2 gap-1 rounded-2xl bg-muted p-1">
          <button
            type="button"
            onClick={() => setTab("products")}
            className={`rounded-xl py-2 text-sm font-semibold transition-colors ${
              tab === "products" ? "bg-card text-foreground shadow-[var(--shadow-tile)]" : "text-muted-foreground"
            }`}
          >
            Products ({(products ?? []).length})
          </button>
          <button
            type="button"
            onClick={() => setTab("categories")}
            className={`rounded-xl py-2 text-sm font-semibold transition-colors ${
              tab === "categories" ? "bg-card text-foreground shadow-[var(--shadow-tile)]" : "text-muted-foreground"
            }`}
          >
            Category ({categories.length})
          </button>
        </div>

        {tab === "products" ? (
          <>
            <div className="flex gap-2">
              <div className="relative flex-1">
                <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
                <Input
                  value={q}
                  onChange={(e) => setQ(e.target.value)}
                  placeholder="Search product"
                  aria-label="Search product"
                  className="h-11 bg-card pl-9"
                />
              </div>
              <Button
                variant={lowOnly ? "default" : "outline"}
                className="h-11 shrink-0"
                onClick={() => setLowOnly((v) => !v)}
              >
                Low stock
              </Button>
            </div>

            <div className="flex gap-2">
              <Button variant="outline" size="sm" disabled={busy} onClick={() => void importCatalogue()}>
                Catalogue import
              </Button>
              <Button variant="outline" size="sm" disabled={busy} onClick={() => void removeDuplicates()}>
                Remove duplicates
              </Button>
            </div>

            <div className="min-h-0 flex-1 overflow-y-auto">
              {isLoading ? (
                <p className="py-10 text-center text-sm text-muted-foreground">Loading…</p>
              ) : (
                <ul className="space-y-2">
                  {rows.map((p) => {
                    const low = Number(p.stock) <= Number(p.low_stock_at);
                    return (
                      <li
                        key={p.id}
                        className="grid grid-cols-[minmax(0,1fr)_auto] items-center gap-3 rounded-2xl bg-card p-3 shadow-[var(--shadow-tile)]"
                      >
                        <div className="min-w-0">
                          <p className="truncate text-sm font-semibold">{p.name}</p>
                          <p className="truncate text-xs text-muted-foreground">
                            {p.category} · Rs {Number(p.price)}/{p.unit} ·{" "}
                            <span className={low ? "font-semibold text-destructive" : ""}>
                              Stock {Number(p.stock)}
                            </span>
                          </p>
                        </div>
                        <div className="flex shrink-0 gap-1">
                          <Button
                            size="icon"
                            variant="ghost"
                            aria-label={`Edit ${p.name}`}
                            onClick={() => setDraft(toDraft(p))}
                          >
                            <Pencil className="h-4 w-4" />
                          </Button>
                          <Button
                            size="icon"
                            variant="ghost"
                            aria-label={`Delete ${p.name}`}
                            onClick={() => void archive(p.id)}
                          >
                            <Trash2 className="h-4 w-4" />
                          </Button>
                        </div>
                      </li>
                    );
                  })}
                  {rows.length === 0 && (
                    <p className="py-16 text-center text-sm text-muted-foreground">Koi product nahi mila.</p>
                  )}
                </ul>
              )}
            </div>
          </>
        ) : (
          <>
            <Button
              variant="outline"
              className="h-11 justify-start"
              onClick={() => setDraft({ ...empty, category: "" })}
            >
              <FolderPlus className="mr-2 h-4 w-4" /> Nayi category banayein
            </Button>

            <div className="min-h-0 flex-1 space-y-2 overflow-y-auto">
              {categories.map(([name, list]) => {
                const open = openCat === name;
                return (
                  <div key={name} className="rounded-2xl bg-card shadow-[var(--shadow-tile)]">
                    <div className="flex items-center gap-2 p-3">
                      <button
                        type="button"
                        className="min-w-0 flex-1 text-left"
                        onClick={() => setOpenCat(open ? null : name)}
                      >
                        <p className="truncate text-sm font-bold uppercase tracking-wide">{name}</p>
                        <p className="text-xs text-muted-foreground">{list.length} products</p>
                      </button>
                      <Button
                        size="sm"
                        variant="ghost"
                        aria-label={`Edit category ${name}`}
                        onClick={() => setCatEdit({ from: name, to: name })}
                      >
                        <Pencil className="mr-1 h-4 w-4" /> Edit
                      </Button>
                      <Button
                        size="sm"
                        variant="ghost"
                        aria-label={`Add product in ${name}`}
                        onClick={() => setDraft({ ...empty, category: name })}
                      >
                        <Plus className="h-4 w-4" />
                      </Button>
                      <ChevronDown
                        className={`h-4 w-4 shrink-0 text-muted-foreground transition-transform ${open ? "rotate-180" : ""}`}
                      />
                    </div>
                    {open && (
                      <ul className="border-t border-border p-2">
                        {list.map((p) => (
                          <li
                            key={p.id}
                            className="grid grid-cols-[minmax(0,1fr)_auto] items-center gap-2 rounded-xl px-2 py-2"
                          >
                            <div className="min-w-0">
                              <p className="truncate text-sm font-medium">{p.name}</p>
                              <p className="text-xs text-muted-foreground">
                                Rs {Number(p.price)}/{p.unit} · Stock {Number(p.stock)}
                              </p>
                            </div>
                            <Button
                              size="icon"
                              variant="ghost"
                              aria-label={`Edit ${p.name}`}
                              onClick={() => setDraft(toDraft(p))}
                            >
                              <Pencil className="h-4 w-4" />
                            </Button>
                          </li>
                        ))}
                      </ul>
                    )}
                  </div>
                );
              })}
              {categories.length === 0 && (
                <p className="py-16 text-center text-sm text-muted-foreground">Abhi koi category nahi hai.</p>
              )}
            </div>
          </>
        )}
      </div>

      <Dialog open={!!catEdit} onOpenChange={(v) => !v && setCatEdit(null)}>
        <DialogContent className="sm:max-w-sm">
          <DialogHeader>
            <DialogTitle>Category ka naam badlein</DialogTitle>
          </DialogHeader>
          {catEdit && (
            <div>
              <Label htmlFor="cat-name">Category name</Label>
              <Input
                id="cat-name"
                value={catEdit.to}
                onChange={(e) => setCatEdit({ ...catEdit, to: e.target.value })}
              />
            </div>
          )}
          <DialogFooter>
            <Button variant="ghost" onClick={() => setCatEdit(null)}>
              Cancel
            </Button>
            <Button onClick={() => void renameCategory()}>Save</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <Dialog open={!!draft} onOpenChange={(v) => !v && setDraft(null)}>
        <DialogContent className="max-h-[90dvh] overflow-y-auto sm:max-w-md">
          <DialogHeader>
            <DialogTitle>{draft?.id ? "Edit product" : "Add product"}</DialogTitle>
          </DialogHeader>
          {draft && (
            <div className="grid gap-3 sm:grid-cols-2">
              <div className="sm:col-span-2">
                <Label htmlFor="p-name">Name</Label>
                <Input
                  id="p-name"
                  value={draft.name}
                  onChange={(e) => setDraft({ ...draft, name: e.target.value })}
                />
              </div>
              <div className="sm:col-span-2">
                <Label htmlFor="p-cat">Category</Label>
                <Input
                  id="p-cat"
                  list="category-list"
                  value={draft.category}
                  onChange={(e) => setDraft({ ...draft, category: e.target.value })}
                />
                <datalist id="category-list">
                  {categories.map(([c]) => (
                    <option key={c} value={c} />
                  ))}
                </datalist>
              </div>
              <div>
                <Label htmlFor="p-unit">Unit</Label>
                <div className="flex gap-2">
                  {(["kg", "pc"] as const).map((u) => (
                    <Button
                      key={u}
                      type="button"
                      variant={draft.unit === u ? "default" : "outline"}
                      className="flex-1"
                      onClick={() => setDraft({ ...draft, unit: u })}
                    >
                      {u}
                    </Button>
                  ))}
                </div>
              </div>
              <div>
                <Label htmlFor="p-price">Sale price</Label>
                <Input
                  id="p-price"
                  inputMode="decimal"
                  value={draft.price}
                  onChange={(e) => setDraft({ ...draft, price: e.target.value })}
                />
              </div>
              <div>
                <Label htmlFor="p-cost">Cost price</Label>
                <Input
                  id="p-cost"
                  inputMode="decimal"
                  value={draft.cost_price}
                  onChange={(e) => setDraft({ ...draft, cost_price: e.target.value })}
                />
              </div>
              <div>
                <Label htmlFor="p-stock">Stock</Label>
                <Input
                  id="p-stock"
                  inputMode="decimal"
                  value={draft.stock}
                  onChange={(e) => setDraft({ ...draft, stock: e.target.value })}
                />
              </div>
              <div>
                <Label htmlFor="p-low">Low stock alert</Label>
                <Input
                  id="p-low"
                  inputMode="decimal"
                  value={draft.low_stock_at}
                  onChange={(e) => setDraft({ ...draft, low_stock_at: e.target.value })}
                />
              </div>
            </div>
          )}
          <DialogFooter>
            <Button variant="ghost" onClick={() => setDraft(null)}>
              Cancel
            </Button>
            <Button onClick={() => void save()}>Save</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </PosShell>
  );
}
