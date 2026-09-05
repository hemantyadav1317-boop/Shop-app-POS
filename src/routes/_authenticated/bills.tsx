import { createFileRoute } from "@tanstack/react-router";
import { useMemo, useState } from "react";
import { Download, Printer, Search, Share2 } from "lucide-react";
import { PosShell } from "@/components/pos/PosShell";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { useShop } from "@/lib/shop";
import { useSales } from "@/lib/queries";
import { supabase } from "@/integrations/supabase/client";
import { downloadBill, downloadCsv, printReceipt, shareReceipt, type ReceiptData } from "@/lib/receipt";

export const Route = createFileRoute("/_authenticated/bills")({
  head: () => ({
    meta: [
      { title: "Bill History — Shop POS" },
      { name: "description", content: "Purane bills, payment mode, due aur print/share ek jagah." },
      { property: "og:title", content: "Bill History — Shop POS" },
      { property: "og:description", content: "Purane bills, payment mode, due aur print/share ek jagah." },
    ],
  }),
  component: BillsPage,
});

function BillsPage() {
  const { shop } = useShop();
  const { data: sales, isLoading } = useSales(shop?.id);
  const [q, setQ] = useState("");

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
    const { data: items } = await supabase
      .from("sale_items")
      .select("name, qty, unit, price")
      .eq("sale_id", saleId);
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
    };
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
                <li key={b.id} className="rounded-2xl bg-card p-3 shadow-[var(--shadow-tile)]">
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
                    <Button
                      size="sm"
                      variant="outline"
                      onClick={async () => printReceipt(await buildReceipt(b.id, b))}
                    >
                      <Printer className="mr-1 h-4 w-4" /> Print
                    </Button>
                    <Button
                      size="sm"
                      variant="outline"
                      onClick={async () => void shareReceipt(await buildReceipt(b.id, b))}
                    >
                      <Share2 className="mr-1 h-4 w-4" /> Share
                    </Button>
                    <Button
                      size="sm"
                      variant="outline"
                      onClick={async () => downloadBill(await buildReceipt(b.id, b))}
                    >
                      <Download className="mr-1 h-4 w-4" /> Save
                    </Button>
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
