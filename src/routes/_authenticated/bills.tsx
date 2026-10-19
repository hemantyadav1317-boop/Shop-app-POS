import { createFileRoute } from "@tanstack/react-router";
import { useMemo, useRef, useState } from "react";
import { CheckCircle2, Download, Search, Share2 } from "lucide-react";
import { toast } from "sonner";
import { shareBillImage } from "@/lib/bill-image";
import { useInvalidatePos } from "@/lib/queries";
import { PosShell } from "@/components/pos/PosShell";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { useShop } from "@/lib/shop";
import { useSales } from "@/lib/queries";
import { supabase } from "@/integrations/supabase/client";
import { downloadBill, downloadCsv, type ReceiptData } from "@/lib/receipt";
import { BluetoothPrintButton } from "@/components/pos/BluetoothPrintButton";

export const Route = createFileRoute("/_authenticated/bills")({
  head: () => ({
    meta: [
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
      { title: "Bill History — Shop POS" },
      { name: "description", content: "Purane bills, payment mode, due aur print/share ek jagah." },
      { property: "og:title", content: "Bill History — Shop POS" },
      { property: "og:description", content: "Purane bills, payment mode, due aur print/share ek jagah." },
    ],
  }),
  component: BillsPage,
});

function BillsPage() {
  const invalidate = useInvalidatePos();
  const { shop } = useShop();
  const { data: sales, isLoading } = useSales(shop?.id);
  const [q, setQ] = useState("");
  const [paying, setPaying] = useState<string | null>(null);
  const paymentLock = useRef(false);

  const rows = useMemo(() => {
    const term = q.trim().toLowerCase();
    return (sales ?? []).filter(
      (s) =>
        !term ||
        String(s.bill_no).includes(term) ||
        (s.customer_name ?? "").toLowerCase().includes(term) ||
        (s.customer_phone ?? "").includes(term),
    );
  }, [sales, q]);

  async function buildReceipt(saleId: string, bill: (typeof rows)[number]): Promise<ReceiptData> {
    const { data: items, error } = await supabase
      .from("sale_items")
      .select("name, qty, unit, price")
      .eq("sale_id", saleId);
    if (error || !items?.length) throw new Error("Saved bill items could not be loaded. Please retry.");
    return {
      shopName: shop?.name ?? "Shop",
      shopPhone: shop?.phone ?? null,
      shopAddress: shop?.address ?? null,
      billNo: bill.bill_no,
      date: new Date(bill.created_at).toLocaleString("en-IN"),
      customerName: bill.customer_name,
      customerPhone: bill.customer_phone,
      lines: (items ?? []).map((i) => ({
        name: i.name,
        qty: Number(i.qty),
        unit: i.unit,
        price: Number(i.price),
      })),
      subTotal: Number(bill.sub_total),
      discount: Number(bill.discount),
      total: Number(bill.total),
      paid: Number(bill.paid),
      due: Number(bill.due),
      paymentMode: bill.payment_mode,
      saleId: bill.id,
      upiId: shop?.upi_id ?? null,
      upiName: shop?.upi_payee_name ?? null,
    };
  }

  async function confirmPayment(bill: (typeof rows)[number]) {
    if (paymentLock.current || !window.confirm(`Confirm Rs ${Number(bill.due).toFixed(2)} has actually been received online for Bill #${bill.bill_no}?`)) return;
    paymentLock.current = true;
    setPaying(bill.id);
    try {
      const { error } = await supabase.rpc("confirm_sale_payment", { _sale_id: bill.id, _amount: Number(bill.due), _mode: "online" });
      if (error) return void toast.error(error.message);
      invalidate();
      toast.success(`Bill #${bill.bill_no} payment recorded`);
    } finally { paymentLock.current = false; setPaying(null); }
  }

  return (
    <PosShell
      title="Bill History"
      headerRight={
        <Button
          variant="outline"
          size="sm"
          onClick={() =>
            downloadCsv(
              "bills.csv",
              rows.map((r) => ({
                bill_no: r.bill_no,
                date: r.created_at,
                customer: r.customer_name ?? "Walk-in",
                total: r.total,
                paid: r.paid,
                due: r.due,
                mode: r.payment_mode,
              })),
            )
          }
        >
          <Download className="mr-1 h-4 w-4" /> Export
        </Button>
      }
    >
      <div className="flex h-full min-h-0 flex-col gap-3 p-3">
        <div className="relative">
          <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
          <Input
            value={q}
            onChange={(e) => setQ(e.target.value)}
            placeholder="Bill no, customer ya phone"
            aria-label="Search bills"
            className="h-11 bg-card pl-9"
          />
        </div>

        <div className="min-h-0 flex-1 overflow-y-auto">
          {isLoading ? (
            <p className="py-10 text-center text-sm text-muted-foreground">Loading…</p>
          ) : rows.length === 0 ? (
            <p className="py-16 text-center text-sm text-muted-foreground">Abhi koi bill nahi bana.</p>
          ) : (
            <ul className="space-y-2.5">
              {rows.map((b) => (
                <li key={b.id} className="rounded-lg border border-border bg-card p-3">
                  <div className="grid grid-cols-[minmax(0,1fr)_auto] items-start gap-3">
                    <div className="min-w-0">
                      <p className="truncate text-sm font-semibold">
                        Bill #{b.bill_no} · {b.customer_name ?? "Walk-in"}
                      </p>
                      <p className="truncate text-xs text-muted-foreground">
                        {new Date(b.created_at).toLocaleString("en-IN")} · {b.payment_mode}
                        {Number(b.due) > 0 ? ` · Due Rs ${Number(b.due).toFixed(2)}` : ""}
                      </p>
                    </div>
                    <span className="shrink-0 text-base font-black text-primary">
                      Rs {Number(b.total).toFixed(2)}
                    </span>
                  </div>
                  <div className="mt-2 flex flex-wrap gap-2">
                    <BluetoothPrintButton receipt={() => buildReceipt(b.id, b)} />
                    <Button
                      size="sm"
                      variant="outline"
                      onClick={() => void buildReceipt(b.id, b).then(shareBillImage).then((result) => { if (result === "downloaded") toast.success("Bill image downloaded"); }).catch(() => toast.error("Bill image could not be shared. Please retry."))}
                    >
                      <Share2 className="mr-1 h-4 w-4" /> Share
                    </Button>
                    <Button
                      size="sm"
                      variant="outline"
                      onClick={() => void buildReceipt(b.id, b).then(downloadBill).catch(() => toast.error("Bill could not be downloaded. Please retry."))}
                    >
                      <Download className="mr-1 h-4 w-4" /> Save
                    </Button>
                    {Number(b.due) > 0 && (
                      <Button
                        size="sm"
                        disabled={paying !== null}
                        onClick={() => void confirmPayment(b)}
                      >
                        <CheckCircle2 className="mr-1 h-4 w-4" /> Mark paid
                      </Button>
                    )}
                  </div>
                </li>
              ))}
            </ul>
          )}
        </div>
      </div>
    </PosShell>
  );
}
