import { useState } from "react";
import { toast } from "sonner";
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
import { useCart } from "@/lib/cart";

/** Database me jo item nahi hai, use seedha qty + rate daal kar bill me add karo. */
export function QuickSellDialog({
  open,
  onOpenChange,
}: {
  open: boolean;
  onOpenChange: (v: boolean) => void;
}) {
  const { addLine } = useCart();
  const [name, setName] = useState("");
  const [qty, setQty] = useState("1");
  const [rate, setRate] = useState("");
  const [unit, setUnit] = useState<"kg" | "pc">("kg");

  function add() {
    const q = Number(qty);
    const r = Number(rate);
    if (!name.trim() || !q || !r) {
      toast.error("Naam, quantity aur rate dalein");
      return;
    }
    addLine({ product_id: null, name: name.trim(), price: r, unit, qty: q });
    toast.success(`${name.trim()} bill me add ho gaya`);
    setName("");
    setQty("1");
    setRate("");
    onOpenChange(false);
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-sm">
        <DialogHeader>
          <DialogTitle>Quick Sell</DialogTitle>
        </DialogHeader>
        <div className="space-y-3">
          <div>
            <Label htmlFor="qs-name">Item name</Label>
            <Input
              id="qs-name"
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="Jaise: Special order"
              className="h-11"
            />
          </div>
          <div className="grid grid-cols-2 gap-3">
            <div>
              <Label htmlFor="qs-qty">Quantity</Label>
              <Input
                id="qs-qty"
                inputMode="decimal"
                value={qty}
                onChange={(e) => setQty(e.target.value)}
                className="h-11"
              />
            </div>
            <div>
              <Label htmlFor="qs-rate">Rate</Label>
              <Input
                id="qs-rate"
                inputMode="decimal"
                value={rate}
                onChange={(e) => setRate(e.target.value)}
                className="h-11"
              />
            </div>
          </div>
          <div className="grid grid-cols-2 gap-2">
            {(["kg", "pc"] as const).map((u) => (
              <button
                key={u}
                type="button"
                onClick={() => setUnit(u)}
                className={`rounded-xl border py-2.5 text-sm font-semibold ${
                  unit === u ? "border-primary bg-primary text-primary-foreground" : "border-border bg-card"
                }`}
              >
                {u === "kg" ? "Kg" : "Piece"}
              </button>
            ))}
          </div>
          <p className="text-xs text-muted-foreground">
            Amount: Rs {((Number(qty) || 0) * (Number(rate) || 0)).toFixed(2)}
          </p>
        </div>
        <DialogFooter>
          <Button className="h-11 w-full" onClick={add}>
            Add to bill
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
