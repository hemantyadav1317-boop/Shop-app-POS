import { playSound } from "@/lib/sound";
import { useEffect, useState } from "react";
import { Minus, Plus } from "lucide-react";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { useCart } from "@/lib/cart";
import { productIcon } from "@/lib/catalog";
import { useShop } from "@/lib/shop";
import { canSellStock } from "@/lib/stock-rules";

export type QtyRateTarget = {
  product_id: string | null;
  name: string;
  unit: "kg" | "pc";
  price: number;
  category?: string | null;
  inCartQty?: number;
  stock?: number;
};

const KG_STEPS = [0.25, 0.5, 1, 2, 5];
const PC_STEPS = [1, 2, 5, 10, 12];

export function QtyRateDialog({
  target,
  onClose,
}: {
  target: QtyRateTarget | null;
  onClose: () => void;
}) {
  const cart = useCart();
  const { shop } = useShop();
  const [qty, setQty] = useState("1");
  const [rate, setRate] = useState("0");
  const [field, setField] = useState<"qty" | "rate">("qty");
  const [fresh, setFresh] = useState(true);

  useEffect(() => {
    if (target) {
      setQty(String(target.inCartQty && target.inCartQty > 0 ? target.inCartQty : target.unit === "kg" ? 1 : 1));
      setRate(String(target.price));
      setField("qty");
      setFresh(true);
    }
  }, [target]);

  if (!target) return null;

  const q = Number(qty) || 0;
  const r = Number(rate) || 0;
  const valid = Number.isFinite(r) && r >= 0 && (target.stock === undefined ? q > 0 : canSellStock(target.stock, q, shop?.allow_negative_stock));
  const steps = target.unit === "kg" ? KG_STEPS : PC_STEPS;
  const bump = (d: number) => setQty(String(Math.max(0, +(q + d).toFixed(3))));

  function pick(f: "qty" | "rate") { setField(f); setFresh(true); }
  function press(k: string) {
    const set = field === "qty" ? setQty : setRate;
    const cur = field === "qty" ? qty : rate;
    if (k === "C") { set("0"); setFresh(true); return; }
    if (k === "⌫") { set(fresh ? "0" : cur.slice(0, -1) || "0"); setFresh(false); return; }
    let base = fresh ? "" : cur === "0" ? "" : cur;
    if (k === "." && base.includes(".")) return;
    if (k === "." && !base) base = "0";
    const next = base + k;
    if (next.length > 9) return;
    set(next);
    setFresh(false);
  }

  function save() {
    if (!target) return;
    if (!valid) return;
    cart.removeLine(target.product_id, target.name);
    cart.addLine({
      product_id: target.product_id,
      name: target.name,
      unit: target.unit,
      price: r,
      qty: q,
    });
    playSound("add");
    onClose();
  }

  return (
    <Dialog open onOpenChange={(v) => !v && onClose()}>
      <DialogContent className="max-h-[95dvh] overflow-y-auto sm:max-w-sm" onOpenAutoFocus={(e) => e.preventDefault()}>
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2 text-left">
            <span aria-hidden className="text-2xl">
              {productIcon(target.name, target.category ?? undefined)}
            </span>
            <span className="min-w-0 truncate">{target.name}</span>
          </DialogTitle>
        </DialogHeader>

        <div className="space-y-4">
          <div>
            <Label htmlFor="qr-qty">Quantity ({target.unit})</Label>
            <div className="mt-1 flex items-center gap-2">
              <Button
                type="button"
                variant="outline"
                size="icon"
                className="h-12 w-12 shrink-0"
                aria-label="Decrease quantity"
                onClick={() => bump(target.unit === "kg" ? -0.25 : -1)}
              >
                <Minus className="h-5 w-5" />
              </Button>
              <button
                type="button"
                id="qr-qty"
                data-sound="none"
                onClick={() => pick("qty")}
                className={`flex h-12 w-full items-center justify-center rounded-md border-2 bg-background text-lg font-bold ${field === "qty" ? "border-primary ring-2 ring-primary/30" : "border-input"}`}
              >
                {qty}{field === "qty" && <span aria-hidden className="ml-0.5 animate-pulse text-primary">|</span>}
              </button>
              <Button
                type="button"
                variant="outline"
                size="icon"
                className="h-12 w-12 shrink-0"
                aria-label="Increase quantity"
                onClick={() => bump(target.unit === "kg" ? 0.25 : 1)}
              >
                <Plus className="h-5 w-5" />
              </Button>
            </div>
            <div className="mt-2 flex flex-wrap gap-2">
              {steps.map((s) => (
                <Button variant="outline"
                  key={s}
                  type="button"
                  onClick={() => { setQty(String(s)); setField("qty"); setFresh(true); }}
                  className="rounded-lg border border-border bg-card px-3 py-1.5 text-sm font-semibold"
                >
                  {s} {target.unit}
                </Button>
              ))}
            </div>
          </div>

          <div>
            <Label htmlFor="qr-rate">Rate (Rs per {target.unit})</Label>
            <div className="mt-1"><button
                type="button"
                id="qr-rate"
                data-sound="none"
                onClick={() => pick("rate")}
                className={`flex h-12 w-full items-center justify-center rounded-md border-2 bg-background text-lg font-bold ${field === "rate" ? "border-primary ring-2 ring-primary/30" : "border-input"}`}
              >
                {rate}{field === "rate" && <span aria-hidden className="ml-0.5 animate-pulse text-primary">|</span>}
              </button></div>
          </div>

          <div className="grid grid-cols-4 gap-2" aria-label="Number keypad">
            {["7", "8", "9", "⌫", "4", "5", "6", "C", "1", "2", "3", ".", "0", "00"].map((k) => (
              <Button key={k} type="button" variant={k === "⌫" || k === "C" ? "secondary" : "outline"} data-sound="tap"
                className={`h-14 text-xl font-bold ${k === "0" ? "col-span-2" : ""} ${k === "00" ? "col-span-2" : ""}`}
                aria-label={k === "⌫" ? "Backspace" : k === "C" ? "Clear" : k}
                onClick={() => (k === "00" ? (press("0"), press("0")) : press(k))}>{k}</Button>
            ))}
          </div>

          <div className="flex items-center justify-between rounded-xl bg-muted p-3">
            <span className="text-sm text-muted-foreground">Amount</span>
            <span className="text-xl font-black text-primary">Rs {(q * r).toFixed(2)}</span>
          </div>

          {!valid && q > 0 && <p role="alert" className="text-sm text-destructive">{r < 0 ? "Rate must be zero or greater" : `Available stock: ${target.stock} ${target.unit}`}</p>}
          <Button className="h-12 w-full text-base font-bold" disabled={!valid} onClick={save}>
            Add to bill
          </Button>
        </div>
      </DialogContent>
    </Dialog>
  );
}
