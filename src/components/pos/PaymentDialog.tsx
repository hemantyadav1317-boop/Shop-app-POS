import { useEffect, useRef, useState } from "react";
import { Check, Home, Share2 } from "lucide-react";
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
import { type ReceiptData } from "@/lib/receipt";
import { shareBillImage, upiQrDataUrl, paymentStatus } from "@/lib/bill-image";
import { BluetoothPrintButton } from "./BluetoothPrintButton";
import { BillReceipt } from "./BillReceipt";
import { useAuth } from "@/lib/auth";

type Mode = "cash" | "online" | "credit" | "split";

const MODES: { value: Mode; label: string }[] = [
  { value: "cash", label: "Cash" },
  { value: "online", label: "Online" },
  { value: "credit", label: "Credit" },
  { value: "split", label: "Split" },
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
  const [received, setReceived] = useState(false);
  const [qr, setQr] = useState<string | null>(null);
  const lock = useRef(false);
  const refKey = useRef<string>("");

  useEffect(() => {
    if (!receipt) return setQr(null);
    void upiQrDataUrl(receipt, 360).then(setQr);
  }, [receipt]);

  useEffect(() => {
    if (open) {
      setMode("cash");
      setPaid(cart.total);
      setReceipt(null);
      setReceived(false);
      refKey.current = crypto.randomUUID();
    }
  }, [open, cart.total]);

  useEffect(() => {
    if (mode === "cash") setPaid(cart.total);
    if (mode === "online") setPaid(received ? cart.total : 0);
    if (mode === "credit") setPaid(0);
  }, [mode, cart.total, received]);

  async function completeSale() {
    if (!shop || !cart.lines.length || lock.current) return;
    if (mode === "credit" && !cart.customer) {
      toast.error("Credit sale ke liye customer select karein");
      return;
    }
    lock.current = true;
    setBusy(true);
    try {
      const { data: saleId, error } = await supabase.rpc("create_sale_once", {
        _client_ref: refKey.current,
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
        saleId: saleId as unknown as string,
        upiId: shop.upi_id ?? null,
        upiName: shop.upi_payee_name ?? null,
      };

      setReceipt(data);
      cart.clear();
      invalidate();
      toast.success("Sale completed successfully");
    } catch (e) {
      toast.error(e instanceof Error ? e.message : "Sale failed");
      lock.current = false;
    } finally {
      setBusy(false);
    }
  }

  const due = Math.max(0, cart.total - paid);

  async function markPaid() {
    if (!receipt?.saleId) return;
    const { error } = await supabase.rpc("confirm_sale_payment", {
      _sale_id: receipt.saleId,
      _amount: receipt.due,
      _mode: "online",
    });
    if (error) return void toast.error(error.message);
    setReceipt({ ...receipt, paid: receipt.paid + receipt.due, due: 0 });
    invalidate();
    toast.success("Payment received — bill paid");
  }

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

            <div className="rounded-2xl border border-border bg-card p-3 text-center">
              <p className={`text-sm font-black ${receipt.due > 0 ? "text-destructive" : "text-primary"}`}>
                {paymentStatus(receipt)}
              </p>
              {qr ? (
                <>
                  <p className="mt-2 text-xs font-bold tracking-widest">SCAN TO PAY</p>
                  <img src={qr} alt={`UPI QR for Rs ${receipt.due.toFixed(2)}`} className="mx-auto mt-1 w-48 rounded-lg bg-background p-1" />
                  <p className="text-lg font-black">Rs {receipt.due.toFixed(2)}</p>
                  <p className="text-xs text-muted-foreground">UPI: {receipt.upiId}</p>
                  <Button size="sm" className="mt-2" onClick={() => void markPaid()}>
                    <Check className="mr-1 h-4 w-4" /> Payment mil gaya — Mark paid
                  </Button>
                </>
              ) : receipt.due > 0 && !receipt.upiId ? (
                <p className="mt-1 text-xs text-muted-foreground">QR ke liye Settings me UPI ID daalein.</p>
              ) : null}
            </div>

            <div className="grid grid-cols-3 gap-2">
              <Button
                type="button"
                variant="outline"
                onClick={() => {
                  onOpenChange(false);
                  onCompleted?.();
                }}
                className="h-auto flex-col gap-1.5 px-2 py-3 text-xs font-semibold"
              >
                <Home className="h-6 w-6 text-primary" />
                New Sale
              </Button>
              <Button
                type="button"
                variant="outline"
                onClick={() => void shareBillImage(receipt).then((r) => r === "downloaded" && toast.success("Bill image download ho gayi"))}
                className="h-auto flex-col gap-1.5 px-2 py-3 text-xs font-semibold"
              >
                <Share2 className="h-6 w-6 text-primary" />
                Share Bill
              </Button>
              <BluetoothPrintButton receipt={receipt} tile />
            </div>
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

            <div className="grid grid-cols-4 gap-2">
              {MODES.map((m) => (
                <button
                  key={m.value}
                  type="button"
                  onClick={() => { setMode(m.value); setReceived(false); }}
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

            {mode === "online" && (
              <label className="flex items-center gap-2 rounded-xl border border-border p-3 text-sm">
                <input type="checkbox" className="h-5 w-5" checked={received} onChange={(e) => setReceived(e.target.checked)} />
                Payment pehle hi mil gaya (verified)
                <span className="ml-auto text-xs text-muted-foreground">{received ? "Paid" : "QR · Pending"}</span>
              </label>
            )}
            {mode === "split" && (
              <p className="text-xs text-muted-foreground">Cash amount daalein — baaki rakam ka UPI QR bill par aayega.</p>
            )}
            <div>
              <Label htmlFor="paid">{mode === "split" ? "Cash received" : "Paid amount"}</Label>
              <Input
                id="paid"
                inputMode="decimal"
                value={paid}
                readOnly={mode !== "split" && mode !== "cash"}
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
              {busy ? "Saving…" : `Bill · Rs ${cart.total.toFixed(2)}`}
            </Button>
          </div>
        )}
      </DialogContent>
    </Dialog>
  );
}
