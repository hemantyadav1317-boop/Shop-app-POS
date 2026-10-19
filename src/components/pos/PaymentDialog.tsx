import { playSound } from "@/lib/sound";
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
import { paymentAmount } from "@/lib/checkout-rules";

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
  const [confirming, setConfirming] = useState(false);
  const [receipt, setReceipt] = useState<ReceiptData | null>(null);
  const [received, setReceived] = useState(false);
  const [qr, setQr] = useState<string | null>(null);
  const lock = useRef(false);
  const refKey = useRef<string>("");
  const opened = useRef(false);
  const paymentLock = useRef(false);

  useEffect(() => {
    if (!receipt) return setQr(null);
    let active = true;
    void upiQrDataUrl(receipt, 360).then((url) => { if (active) setQr(url); }).catch(() => { if (active) setQr(null); });
    return () => { active = false; };
  }, [receipt]);

  useEffect(() => {
    if (open && !opened.current) {
      setMode("cash");
      setPaid(cart.total);
      setReceipt(null);
      setReceived(false);
      refKey.current = crypto.randomUUID();
      lock.current = false;
    }
    opened.current = open;
  }, [open, cart.total]);

  useEffect(() => {
    if (receipt) return;
    if (mode === "cash") setPaid(cart.total);
    if (mode === "online") setPaid(received ? cart.total : 0);
    if (mode === "credit") setPaid(0);
  }, [mode, cart.total, received, receipt]);

  async function completeSale() {
    if (!shop || !cart.lines.length || lock.current) return;
    if (mode === "credit" && !cart.customer) {
      toast.error("Credit sale ke liye customer select karein");
      return;
    }
    lock.current = true;
    setBusy(true);
    try {
      const amount = paymentAmount(paid, cart.total);
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
        _paid: amount,
        _customer_id: cart.customer?.id ?? null,
        _customer_name: cart.customer?.name ?? null,
        _customer_phone: cart.customer?.phone ?? null,
        _note: null,
      } as never);

      if (error) throw error;

      if (typeof saleId !== "string") throw new Error("Saved bill could not be identified. Retry to retrieve it.");
      const { data: sale, error: saleError } = await supabase
        .from("sales")
        .select("*")
        .eq("id", saleId)
        .single();
      if (saleError || !sale) throw new Error("Bill saved, but could not be loaded. Retry with the same order.");
      const { data: items, error: itemsError } = await supabase.from("sale_items").select("name, qty, unit, price").eq("sale_id", saleId).eq("shop_id", shop.id);
      if (itemsError || !items?.length) throw new Error("Bill saved, but its items could not be loaded. Retry with the same order.");

      const data: ReceiptData = {
        shopName: shop.name,
        shopPhone: shop.phone,
        shopAddress: shop.address,
        billNo: sale.bill_no,
        date: new Date(sale.created_at).toLocaleString("en-IN"),
        customerName: sale.customer_name,
        customerPhone: sale.customer_phone,
        lines: items.map((l) => ({
          name: l.name,
          qty: Number(l.qty),
          unit: l.unit,
          price: Number(l.price),
        })),
        subTotal: Number(sale.sub_total),
        discount: Number(sale.discount),
        total: Number(sale.total),
        paid: Number(sale.paid),
        due: Number(sale.due),
        paymentMode: sale.payment_mode,
        saleId,
        upiId: shop.upi_id ?? null,
        upiName: shop.upi_payee_name ?? null,
      };

      setReceipt(data);
      cart.clear();
      invalidate();
      playSound("sale"); toast("Sale completed successfully");
    } catch (e) {
      toast.error(e instanceof Error ? e.message : typeof e === "object" && e && "message" in e ? String(e.message) : "Sale failed");
      lock.current = false;
    } finally {
      setBusy(false);
    }
  }

  const due = Math.max(0, cart.total - paid);

  async function markPaid() {
    if (!receipt?.saleId || paymentLock.current) return;
    if (!window.confirm(`Confirm Rs ${receipt.due.toFixed(2)} has actually been received online?`)) return;
    paymentLock.current = true;
    setConfirming(true);
    try {
    const { error } = await supabase.rpc("confirm_sale_payment", {
      _sale_id: receipt.saleId,
      _amount: receipt.due,
      _mode: "online",
    });
    if (error) return void toast.error(error.message);
    const { data: saved, error: readError } = await supabase.from("sales").select("paid, due").eq("id", receipt.saleId).single();
    if (readError || !saved) return void toast.error("Payment recorded. Reopen this bill to refresh its status.");
    setReceipt({ ...receipt, paid: Number(saved.paid), due: Number(saved.due) });
    invalidate();
    toast.success("Payment received — bill paid");
    } finally { paymentLock.current = false; setConfirming(false); }
  }

  return (
    <Dialog open={open} onOpenChange={(value) => { if (!busy && !confirming) onOpenChange(value); }}>
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
                  <Button size="sm" className="mt-2" disabled={confirming} onClick={() => void markPaid()}>
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
                data-sound="share" onClick={() => void shareBillImage(receipt).then((r) => r === "downloaded" && toast.success("Bill image download ho gayi")).catch(() => toast.error("Bill image could not be shared. Please retry."))}
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
                <Button variant="outline"
                  key={m.value}
                  type="button"
                  onClick={() => { setMode(m.value); setReceived(false); }}
                  aria-pressed={mode === m.value}
                  className={`h-12 rounded-lg border px-2 py-3 text-sm font-semibold transition-colors ${
                    mode === m.value
                      ? "border-primary bg-primary text-primary-foreground"
                      : "border-border bg-card"
                  }`}
                >
                  {m.label}
                </Button>
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
