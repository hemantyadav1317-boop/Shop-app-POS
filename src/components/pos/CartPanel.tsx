import { useState } from "react";
import { Minus, Plus, Save, Trash2, UserPlus, X } from "lucide-react";
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
import { useShop } from "@/lib/shop";
import { useCustomers, useInvalidatePos } from "@/lib/queries";
import { supabase } from "@/integrations/supabase/client";
import { PaymentDialog } from "./PaymentDialog";

const rs = (n: number) => `Rs ${n.toFixed(2)}`;

export function CartPanel({ onDone }: { onDone?: () => void }) {
  const { shop } = useShop();
  const cart = useCart();
  const { data: customers } = useCustomers(shop?.id);
  const invalidate = useInvalidatePos();

  const [custOpen, setCustOpen] = useState(false);
  const [payOpen, setPayOpen] = useState(false);
  const [name, setName] = useState("");
  const [phone, setPhone] = useState("");

  const step = (unit: string) => (unit === "kg" ? 0.25 : 1);

  async function saveCustomer() {
    if (!shop || !name.trim()) return;
    const existing = customers?.find(
      (c) => c.phone && phone && c.phone === phone.trim(),
    );
    if (existing) {
      cart.setCustomer({ id: existing.id, name: existing.name, phone: existing.phone ?? "" });
    } else {
      const { data, error } = await supabase
        .from("customers")
        .insert({ shop_id: shop.id, name: name.trim(), phone: phone.trim() || null })
        .select()
        .single();
      if (error) {
        toast.error(error.message);
        return;
      }
      cart.setCustomer({ id: data.id, name: data.name, phone: data.phone ?? "" });
      invalidate();
    }
    setCustOpen(false);
    setName("");
    setPhone("");
    toast.success("Customer added");
  }

  async function saveOrder() {
    if (!shop || !cart.lines.length) return;
    const { error } = await supabase.from("saved_orders").insert({
      shop_id: shop.id,
      lines: cart.lines,
      customer_name: cart.customer?.name ?? null,
      customer_phone: cart.customer?.phone ?? null,
    });
    if (error) {
      toast.error(error.message);
      return;
    }
    cart.clear();
    invalidate();
    toast.success("Order saved");
    onDone?.();
  }

  return (
    <div className="flex h-full min-h-0 flex-col bg-card">
      <div className="flex items-center justify-between gap-2 border-b border-border px-3 py-3">
        <div className="min-w-0">
          <p className="text-sm font-bold">Order</p>
          <p className="truncate text-xs text-muted-foreground">
            {cart.customer ? `${cart.customer.name} · ${cart.customer.phone}` : "Walk-in customer"}
          </p>
        </div>
        <Button variant="outline" size="sm" onClick={() => setCustOpen(true)}>
          <UserPlus className="mr-1 h-4 w-4" /> Customer
        </Button>
      </div>

      <div className="min-h-0 flex-1 overflow-y-auto p-3">
        {cart.lines.length === 0 ? (
          <p className="py-10 text-center text-sm text-muted-foreground">
            Cart khali hai — product tap karke add karein.
          </p>
        ) : (
          <ul className="space-y-2">
            {cart.lines.map((l) => (
              <li
                key={`${l.product_id ?? l.name}`}
                className="rounded-xl border border-border bg-background p-2.5"
              >
                <div className="flex items-start justify-between gap-2">
                  <div className="min-w-0">
                    <p className="truncate text-sm font-medium">{l.name}</p>
                    <p className="text-xs text-muted-foreground">
                      {rs(l.price)} / {l.unit}
                    </p>
                  </div>
                  <button
                    type="button"
                    aria-label={`Remove ${l.name}`}
                    onClick={() => cart.removeLine(l.product_id, l.name)}
                    className="rounded-lg p-1 text-muted-foreground hover:bg-muted"
                  >
                    <X className="h-4 w-4" />
                  </button>
                </div>
                <div className="mt-2 flex items-center justify-between gap-2">
                  <div className="flex items-center gap-1.5">
                    <Button
                      variant="outline"
                      size="icon"
                      className="h-9 w-9"
                      aria-label="Decrease"
                      onClick={() => cart.setQty(l.product_id, l.name, l.qty - step(l.unit))}
                    >
                      <Minus className="h-4 w-4" />
                    </Button>
                    <Input
                      value={l.qty}
                      inputMode="decimal"
                      aria-label={`Quantity for ${l.name}`}
                      onChange={(e) =>
                        cart.setQty(l.product_id, l.name, Number(e.target.value) || 0)
                      }
                      className="h-9 w-20 text-center"
                    />
                    <Button
                      variant="outline"
                      size="icon"
                      className="h-9 w-9"
                      aria-label="Increase"
                      onClick={() => cart.setQty(l.product_id, l.name, l.qty + step(l.unit))}
                    >
                      <Plus className="h-4 w-4" />
                    </Button>
                  </div>
                  <span className="text-sm font-bold">{rs(l.price * l.qty)}</span>
                </div>
              </li>
            ))}
          </ul>
        )}
      </div>

      <div className="space-y-2 border-t border-border p-3">
        <div className="flex items-center justify-between text-sm">
          <span className="text-muted-foreground">Sub Total</span>
          <span className="font-medium">{rs(cart.subTotal)}</span>
        </div>
        <div className="flex items-center justify-between gap-2 text-sm">
          <Label htmlFor="discount" className="text-muted-foreground">
            Discount
          </Label>
          <Input
            id="discount"
            inputMode="decimal"
            value={cart.discount}
            onChange={(e) => cart.setDiscount(Number(e.target.value) || 0)}
            className="h-9 w-28 text-right"
          />
        </div>
        <div className="flex items-center justify-between text-base font-black">
          <span>Total</span>
          <span className="text-primary">{rs(cart.total)}</span>
        </div>

        <div className="grid grid-cols-2 gap-2 pt-1">
          <Button variant="outline" onClick={cart.clear} disabled={!cart.lines.length}>
            <Trash2 className="mr-1 h-4 w-4" /> Clear
          </Button>
          <Button variant="outline" onClick={() => void saveOrder()} disabled={!cart.lines.length}>
            <Save className="mr-1 h-4 w-4" /> Save
          </Button>
        </div>
        <Button
          className="h-12 w-full text-base font-bold"
          disabled={!cart.lines.length}
          onClick={() => setPayOpen(true)}
        >
          Bill · {rs(cart.total)}
        </Button>
      </div>

      <Dialog open={custOpen} onOpenChange={setCustOpen}>
        <DialogContent className="sm:max-w-sm">
          <DialogHeader>
            <DialogTitle>Customer details</DialogTitle>
          </DialogHeader>
          <div className="space-y-3">
            <div>
              <Label htmlFor="cname">Name</Label>
              <Input id="cname" value={name} onChange={(e) => setName(e.target.value)} />
            </div>
            <div>
              <Label htmlFor="cphone">Phone</Label>
              <Input
                id="cphone"
                inputMode="tel"
                value={phone}
                onChange={(e) => setPhone(e.target.value)}
              />
            </div>
            {!!customers?.length && (
              <div className="max-h-40 overflow-y-auto rounded-xl border border-border">
                {customers.map((c) => (
                  <button
                    key={c.id}
                    type="button"
                    onClick={() => {
                      cart.setCustomer({ id: c.id, name: c.name, phone: c.phone ?? "" });
                      setCustOpen(false);
                    }}
                    className="flex w-full items-center justify-between px-3 py-2 text-left text-sm hover:bg-muted"
                  >
                    <span className="truncate">{c.name}</span>
                    <span className="text-xs text-muted-foreground">{c.phone}</span>
                  </button>
                ))}
              </div>
            )}
          </div>
          <DialogFooter>
            <Button
              variant="ghost"
              onClick={() => {
                cart.setCustomer(null);
                setCustOpen(false);
              }}
            >
              Walk-in
            </Button>
            <Button onClick={() => void saveCustomer()}>Save</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <PaymentDialog open={payOpen} onOpenChange={setPayOpen} onCompleted={() => onDone?.()} />
    </div>
  );
}
