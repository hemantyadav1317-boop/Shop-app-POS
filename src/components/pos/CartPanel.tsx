import { useState } from "react";
import { Minus, Plus, Printer, Save, Trash2, UserPlus, X } from "lucide-react";
import { usePos } from "@/lib/pos-store";
import { formatRs } from "@/lib/pos-data";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Dialog,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import { PaymentDialog } from "./PaymentDialog";

function CustomerDialog() {
  const { customer, setCustomer } = usePos();
  const [open, setOpen] = useState(false);
  const [name, setName] = useState(customer?.name ?? "");
  const [phone, setPhone] = useState(customer?.phone ?? "");

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button variant="outline" size="sm" className="min-w-0 gap-2">
          <UserPlus className="h-4 w-4 shrink-0" />
          <span className="truncate">{customer ? customer.name : "Add Customer"}</span>
        </Button>
      </DialogTrigger>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Customer Details</DialogTitle>
        </DialogHeader>
        <div className="space-y-3">
          <div className="space-y-1.5">
            <Label htmlFor="cname">Name</Label>
            <Input id="cname" value={name} onChange={(e) => setName(e.target.value)} placeholder="Grahak ka naam" />
          </div>
          <div className="space-y-1.5">
            <Label htmlFor="cphone">Mobile</Label>
            <Input
              id="cphone"
              inputMode="tel"
              value={phone}
              onChange={(e) => setPhone(e.target.value)}
              placeholder="98765 43210"
            />
          </div>
        </div>
        <DialogFooter>
          <Button
            onClick={() => {
              setCustomer(name.trim() ? { name: name.trim(), phone: phone.trim() } : null);
              setOpen(false);
            }}
          >
            Save
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

export function CartPanel({ onDone }: { onDone?: () => void }) {
  const { cart, setQty, remove, clear, subTotal, total, itemCount, saveOrder } = usePos();

  return (
    <div className="flex h-full min-h-0 flex-col gap-3 bg-background p-3">
      <div className="grid grid-cols-[minmax(0,1fr)_auto] items-center gap-3">
        <h2 className="truncate text-lg font-bold">Orders</h2>
        <CustomerDialog />
      </div>

      <div className="min-h-0 flex-1 overflow-y-auto rounded-2xl bg-card p-2 shadow-[var(--shadow-tile)]">
        {cart.length === 0 ? (
          <p className="grid h-full place-items-center px-6 text-center text-sm text-muted-foreground">
            Koi item nahi. Product par tap karke order banaiye.
          </p>
        ) : (
          <ul className="divide-y divide-border">
            {cart.map((line) => (
              <li key={line.id} className="py-2.5">
                <div className="grid grid-cols-[minmax(0,1fr)_auto] items-start gap-2">
                  <p className="min-w-0 truncate text-sm font-medium">{line.name}</p>
                  <span className="shrink-0 text-sm font-bold text-success">
                    +{(line.price * line.qty).toFixed(2)}
                  </span>
                </div>
                <div className="mt-1.5 grid grid-cols-[minmax(0,1fr)_auto] items-center gap-2">
                  <span className="truncate text-xs text-muted-foreground">
                    {line.price.toFixed(2)} / {line.unit}
                  </span>
                  <div className="flex shrink-0 items-center gap-1">
                    <Button
                      variant="secondary"
                      size="icon"
                      className="h-8 w-8"
                      aria-label="Kam karein"
                      onClick={() => setQty(line.id, +(line.qty - (line.unit === "kg" ? 0.25 : 1)).toFixed(3))}
                    >
                      <Minus className="h-4 w-4" />
                    </Button>
                    <Input
                      value={line.qty}
                      inputMode="decimal"
                      aria-label="Quantity"
                      onChange={(e) => setQty(line.id, Number(e.target.value) || 0)}
                      className="h-8 w-16 text-center text-sm"
                    />
                    <Button
                      variant="default"
                      size="icon"
                      className="h-8 w-8"
                      aria-label="Zyada karein"
                      onClick={() => setQty(line.id, +(line.qty + (line.unit === "kg" ? 0.25 : 1)).toFixed(3))}
                    >
                      <Plus className="h-4 w-4" />
                    </Button>
                    <Button
                      variant="ghost"
                      size="icon"
                      className="h-8 w-8 text-destructive"
                      aria-label="Hataayein"
                      onClick={() => remove(line.id)}
                    >
                      <X className="h-4 w-4" />
                    </Button>
                  </div>
                </div>
              </li>
            ))}
          </ul>
        )}
      </div>

      <div className="rounded-2xl bg-card p-3 shadow-[var(--shadow-tile)]">
        <dl className="space-y-1.5 text-sm">
          <div className="flex justify-between">
            <dt className="text-muted-foreground">Items</dt>
            <dd className="font-semibold">{itemCount}</dd>
          </div>
          <div className="flex justify-between">
            <dt className="text-muted-foreground">Sub Total</dt>
            <dd className="font-semibold">{formatRs(subTotal)}</dd>
          </div>
          <div className="flex justify-between">
            <dt className="text-muted-foreground">Tax</dt>
            <dd className="font-semibold">Rs 0.00</dd>
          </div>
        </dl>

        <div className="mt-3 grid grid-cols-2 gap-2">
          <Button variant="outline" className="gap-2 text-destructive" onClick={clear} disabled={!cart.length}>
            <Trash2 className="h-4 w-4" /> Clear
          </Button>
          <Button variant="outline" className="gap-2" onClick={saveOrder} disabled={!cart.length}>
            <Save className="h-4 w-4" /> Save
          </Button>
        </div>

        <div className="mt-2 grid grid-cols-[auto_minmax(0,1fr)] gap-2">
          <Button variant="secondary" size="icon" className="h-12 w-12" aria-label="Print" disabled={!cart.length}>
            <Printer className="h-5 w-5" />
          </Button>
          <PaymentDialog onDone={onDone}>
            <Button className="h-12 w-full justify-between px-4 text-base font-bold" disabled={!cart.length}>
              <span className="truncate">{formatRs(total)}</span>
              <span>Bill</span>
            </Button>
          </PaymentDialog>
        </div>
      </div>
    </div>
  );
}
