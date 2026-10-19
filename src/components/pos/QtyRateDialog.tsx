import { useEffect, useState } from "react";
import { Minus, Plus } from "lucide-react";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
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

  useEffect(() => {
    if (target) {
      setQty(String(target.inCartQty && target.inCartQty > 0 ? target.inCartQty : target.unit === "kg" ? 1 : 1));
      setRate(String(target.price));
    }
  }, [target]);

  if (!target) return null;

  const q = Number(qty) || 0;
  const r = Number(rate) || 0;
  const valid = Number.isFinite(r) && r >= 0 && (target.stock === undefined ? q > 0 : canSellStock(target.stock, q, shop?.allow_negative_stock));
  const steps = target.unit === "kg" ? KG_STEPS : PC_STEPS;
  const bump = (d: number) => setQty(String(Math.max(0, +(q + d).toFixed(3))));

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
      <DialogContent className="sm:max-w-sm">
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
              <Input
                id="qr-qty"
                inputMode="decimal"
                value={qty}
                onFocus={(e) => e.target.select()}
                onChange={(e) => setQty(e.target.value)}
                className="h-12 text-center text-lg font-bold"
              />
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
                  onClick={() => setQty(String(s))}
                  className="rounded-lg border border-border bg-card px-3 py-1.5 text-sm font-semibold"
                >
                  {s} {target.unit}
                </Button>
              ))}
            </div>
          </div>

          <div>
            <Label htmlFor="qr-rate">Rate (Rs per {target.unit})</Label>
            <Input
              id="qr-rate"
              inputMode="decimal"
              value={rate}
              onFocus={(e) => e.target.select()}
              onChange={(e) => setRate(e.target.value)}
              className="mt-1 h-12 text-lg font-bold"
            />
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
