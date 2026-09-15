import { useEffect, useState } from "react";
import { Check, Download, Home, Share2 } from "lucide-react";
import { toast } from "sonner";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { supabase } from "@/integrations/supabase/client";
import { useCart } from "@/lib/cart";
import { useShop } from "@/lib/shop";
import { useInvalidatePos } from "@/lib/queries";
import { downloadBill, shareReceipt, type ReceiptData } from "@/lib/receipt";
import { BluetoothPrintButton } from "./BluetoothPrintButton";
import { BillReceipt } from "./BillReceipt";
import { useAuth } from "@/lib/auth";

type Mode = "cash" | "online" | "credit" | "split" | "set_later";

const MODES: { value: Mode; label: string }[] = [
  { value: "cash", label: "Cash" },
  { value: "online", label: "Online" },
  { value: "credit", label: "Credit" },
  { value: "split", label: "Split" },
  { value: "set_later", label: "Set Later" },
];

export function PaymentDialog({
  open,
  onOpenChange,
  onCompleted,
}: {
  open: boolean;
  onOpenChange: (v: boolean) => void;
  onCompleted?: () => void;
}) {
  const { shop } = useShop();
  const { user } = useAuth();
  const cart = useCart();
  const invalidate = useInvalidatePos();

  const [mode, setMode] = useState<Mode>("cash");
  const [paid, setPaid] = useState<number>(0);
  const [busy, setBusy] = useState(false);
  const [receipt, setReceipt] = useState<ReceiptData | null>(null);

  useEffect(() => {
    if (open) {
      setMode("cash");
      setPaid(cart.total);
      setReceipt(null);
    }
  }, [open, cart.total]);

  useEffect(() => {
    if (mode === "cash" || mode === "online") setPaid(cart.total);
    if (mode === "credit" || mode === "set_later") setPaid(0);
  }, [mode, cart.total]);

  async function completeSale() {
    if (!shop || !cart.lines.length) return;
    setBusy(true);
    try {
      const { data: saleId, error } = await supabase.rpc("create_sale", {
        _shop_id: shop.id,
        _items: cart.lines.map((l) => ({
          product_id: l.product_id ?? "",
          name: l.name,
          unit: l.unit,
          price: l.price,
          qty: l.qty,
        })),
        _discount: cart.discount,
        _payment_mode: mode,
        _paid: Math.min(paid, cart.total),
        _customer_id: cart.customer?.id ?? null,
        _customer_name: cart.customer?.name ?? null,
        _customer_phone: cart.customer?.phone ?? null,
        _note: null,
      } as never);

      if (error) throw error;

      const { data: sale } = await supabase
        .from("sales")
        .select("bill_no, created_at")
        .eq("id", saleId as unknown as string)
        .single();

      const data: ReceiptData = {
        shopName: shop.name,
        shopPhone: shop.phone,
        shopAddress: shop.address,
        billNo: sale?.bill_no ?? 0,
        date: new Date(sale?.created_at ?? Date.now()).toLocaleString("en-IN"),
        customerName: cart.customer?.name ?? null,
        customerPhone: cart.customer?.phone ?? null,
        lines: cart.lines.map((l) => ({
          name: l.name,
          qty: l.qty,
          unit: l.unit,
          price: l.price,
        })),
        subTotal: cart.subTotal,
        discount: cart.discount,
        total: cart.total,
        paid: Math.min(paid, cart.total),
        due: Math.max(0, cart.total - Math.min(paid, cart.total)),
        paymentMode: mode,
      };

      setReceipt(data);
      cart.clear();
      invalidate();
      toast.success("Sale completed successfully");
    } catch (e) {
      toast.error(e instanceof Error ? e.message : "Sale failed");
    } finally {
      setBusy(false);
    }
  }

  const due = Math.max(0, cart.total - paid);

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-h-[92dvh] overflow-y-auto sm:max-w-md">
        <DialogHeader>
          <DialogTitle>{receipt ? `Bill #${receipt.billNo}` : "Payment"}</DialogTitle>
        </DialogHeader>

        {receipt ? (
          <div className="space-y-3">
            <div className="flex items-center gap-2 rounded-xl bg-accent p-2.5 text-accent-foreground">
              <Check className="h-4 w-4" />
              <span className="text-sm font-semibold">Sale completed successfully</span>
            </div>

            <BillReceipt d={receipt} email={user?.email ?? null} />

            <div className="grid grid-cols-3 gap-2">
              <button
                type="button"
                onClick={() => {
                  onOpenChange(false);
                  onCompleted?.();
                }}
                className="flex flex-col items-center gap-1.5 rounded-xl border border-border bg-card px-2 py-3 text-xs font-semibold"
              >
                <Home className="h-6 w-6 text-primary" />
                New Sale
              </button>
              <button
                type="button"
                onClick={() => void shareReceipt(receipt)}
                className="flex flex-col items-center gap-1.5 rounded-xl border border-border bg-card px-2 py-3 text-xs font-semibold"
              >
                <Share2 className="h-6 w-6 text-primary" />
                Share Bill
              </button>
              <BluetoothPrintButton receipt={receipt} tile />
            </div>

            <Button variant="ghost" className="h-10 w-full" onClick={() => downloadBill(receipt)}>
              <Download className="mr-1 h-4 w-4" /> Save bill
            </Button>
          </div>
        ) : (
          <div className="space-y-4">
            <div className="rounded-xl bg-muted p-3">
              <div className="flex justify-between text-sm">
                <span className="text-muted-foreground">{cart.lines.length} items</span>
                <span>Rs {cart.subTotal.toFixed(2)}</span>
              </div>
              <div className="flex justify-between text-base font-black">
                <span>Total</span>
                <span className="text-primary">Rs {cart.total.toFixed(2)}</span>
              </div>
            </div>

            <div className="grid grid-cols-3 gap-2">
              {MODES.map((m) => (
                <button
                  key={m.value}
                  type="button"
                  onClick={() => setMode(m.value)}
                  className={`rounded-xl border px-2 py-3 text-sm font-semibold transition-colors ${
                    mode === m.value
                      ? "border-primary bg-primary text-primary-foreground"
                      : "border-border bg-card"
                  }`}
                >
                  {m.label}
                </button>
              ))}
            </div>

            <div>
              <Label htmlFor="paid">Paid amount</Label>
              <Input
                id="paid"
                inputMode="decimal"
                value={paid}
                onChange={(e) => setPaid(Number(e.target.value) || 0)}
                className="h-11"
              />
              {due > 0 && (
                <p className="mt-1 text-xs text-destructive">
                  Due Rs {due.toFixed(2)}
                  {cart.customer ? " — customer khate me jud jayega" : " — customer select karein"}
                </p>
              )}
            </div>

            <Button
              className="h-12 w-full text-base font-bold"
              disabled={busy}
              onClick={() => void completeSale()}
            >
              {busy ? "Saving…" : `Complete Rs ${cart.total.toFixed(2)}`}
            </Button>
          </div>
        )}
      </DialogContent>
    </Dialog>
  );
}
