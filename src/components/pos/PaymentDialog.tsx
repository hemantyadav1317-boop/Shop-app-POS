import { useState, type ReactNode } from "react";
import { Banknote, CreditCard, Clock, Split, UserCheck, CheckCircle2 } from "lucide-react";
import { usePos, type Bill } from "@/lib/pos-store";
import { formatRs } from "@/lib/pos-data";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { toast } from "sonner";

const MODES = [
  { id: "Cash", icon: Banknote },
  { id: "Online", icon: CreditCard },
  { id: "Set Later", icon: Clock },
  { id: "Split", icon: Split },
  { id: "Credit", icon: UserCheck },
] as const;

export function PaymentDialog({ children, onDone }: { children: ReactNode; onDone?: (() => void) | undefined }) {
  const { cart, subTotal, total, discount, setDiscount, checkout } = usePos();
  const [open, setOpen] = useState(false);
  const [mode, setMode] = useState<string>("Cash");
  const [done, setDone] = useState<Bill | null>(null);

  const finish = () => {
    const bill = checkout(mode);
    setDone(bill);
    toast.success("Sale completed successfully");
  };

  const close = (v: boolean) => {
    setOpen(v);
    if (!v) {
      setDone(null);
      onDone?.();
    }
  };

  return (
    <Dialog open={open} onOpenChange={close}>
      <DialogTrigger asChild>{children}</DialogTrigger>
      <DialogContent className="max-h-[90dvh] overflow-y-auto sm:max-w-lg">
        {done ? (
          <>
            <DialogHeader>
              <DialogTitle className="flex items-center gap-2">
                <CheckCircle2 className="h-5 w-5 text-success" /> Sale completed
              </DialogTitle>
            </DialogHeader>
            <div className="rounded-xl border border-dashed border-border p-3 text-sm">
              <p className="text-xs text-muted-foreground">Bill #{done.no}</p>
              <ul className="mt-2 space-y-1">
                {done.lines.map((l) => (
                  <li key={l.id} className="grid grid-cols-[minmax(0,1fr)_auto_auto] gap-2">
                    <span className="truncate">{l.name}</span>
                    <span className="text-muted-foreground">
                      {l.qty}
                      {l.unit === "kg" ? "kg" : ""}
                    </span>
                    <span className="w-16 text-right font-medium">{(l.price * l.qty).toFixed(2)}</span>
                  </li>
                ))}
              </ul>
              <div className="mt-3 border-t border-dashed border-border pt-2 text-base font-bold">
                Total : {formatRs(done.total)}
              </div>
              <p className="mt-1 text-xs text-muted-foreground">Payment: {done.payment}</p>
            </div>
            <Button onClick={() => close(false)} className="h-11">
              New Sale
            </Button>
          </>
        ) : (
          <>
            <DialogHeader>
              <DialogTitle>Payment</DialogTitle>
            </DialogHeader>
            <div className="rounded-xl bg-muted p-3 text-sm">
              <div className="flex justify-between">
                <span className="text-muted-foreground">Total items</span>
                <span className="font-semibold">{cart.length}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-muted-foreground">Sub Total</span>
                <span className="font-semibold">{formatRs(subTotal)}</span>
              </div>
              <div className="mt-2 flex items-center justify-between gap-3">
                <Label htmlFor="disc" className="text-muted-foreground">
                  Discount
                </Label>
                <Input
                  id="disc"
                  inputMode="decimal"
                  className="h-9 w-28 bg-card text-right"
                  value={discount || ""}
                  placeholder="0"
                  onChange={(e) => setDiscount(Number(e.target.value) || 0)}
                />
              </div>
              <div className="mt-3 flex items-baseline justify-between border-t border-border pt-2">
                <span className="font-semibold">Total Amount</span>
                <span className="text-xl font-black">{formatRs(total)}</span>
              </div>
            </div>

            <p className="text-center text-sm text-muted-foreground">Mode of payment</p>
            <div className="grid grid-cols-3 gap-2 sm:grid-cols-5">
              {MODES.map((m) => (
                <button
                  key={m.id}
                  type="button"
                  onClick={() => setMode(m.id)}
                  className={`flex flex-col items-center gap-1 rounded-xl border p-2.5 text-xs transition-colors ${
                    mode === m.id
                      ? "border-primary bg-accent text-accent-foreground font-semibold"
                      : "border-border bg-card text-muted-foreground"
                  }`}
                >
                  <m.icon className="h-5 w-5" />
                  <span className="truncate">{m.id}</span>
                </button>
              ))}
            </div>

            <Button className="h-12 text-base font-bold" onClick={finish}>
              Complete Sale · {formatRs(total)}
            </Button>
          </>
        )}
      </DialogContent>
    </Dialog>
  );
}
