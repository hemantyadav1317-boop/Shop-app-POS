import type { ReceiptData } from "@/lib/receipt";

const Dashed = () => <div className="my-2 border-t border-dashed border-foreground/40" />;

/** Thermal-bill style invoice preview (matches printed receipt layout). */
export function BillReceipt({ d, email }: { d: ReceiptData; email?: string | null }) {
  const totalQty = d.lines.reduce((s, l) => s + l.qty, 0);

  return (
    <div className="rounded-2xl bg-muted/60 p-4 text-foreground shadow-[var(--shadow-tile)]">
      <div className="text-center">
        <h2 className="text-xl font-bold leading-tight">{d.shopName}</h2>
        {d.shopAddress && <p className="text-sm">{d.shopAddress}</p>}
        {d.shopPhone && <p className="text-sm">{d.shopPhone}</p>}
        {email && <p className="text-sm break-all">{email}</p>}
        <p className="mt-2 text-base font-bold tracking-wide">INVOICE</p>
      </div>

      <div className="mt-3 flex flex-wrap justify-between gap-2 text-sm">
        <span>{d.date}</span>
        <span>Invoice : {d.billNo}</span>
      </div>

      <Dashed />
      <div className="grid grid-cols-[minmax(0,1fr)_auto_auto_auto] gap-x-3 text-xs font-semibold text-muted-foreground">
        <span>Item</span>
        <span className="text-right">Qty</span>
        <span className="text-right">Rate</span>
        <span className="text-right">Total</span>
      </div>
      <Dashed />

      <div className="grid grid-cols-[minmax(0,1fr)_auto_auto_auto] gap-x-3 gap-y-2 text-sm">
        {d.lines.map((l) => (
          <div key={l.name} className="contents">
            <span className="min-w-0 truncate">{l.name}</span>
            <span className="text-right tabular-nums">
              {l.qty}
              {l.unit}
            </span>
            <span className="text-right tabular-nums">{l.price}</span>
            <span className="text-right tabular-nums">{(l.qty * l.price).toFixed(2)}</span>
          </div>
        ))}
      </div>

      <Dashed />
      <div className="flex items-start justify-between text-sm">
        <div>
          <p>Items : {d.lines.length}</p>
          <p className="text-xs text-muted-foreground">
            Total Qty : {totalQty.toFixed(2)}
          </p>
        </div>
        <div className="text-right">
          <p>
            Sub Total <span className="font-semibold">Rs {d.subTotal.toFixed(2)}</span>
          </p>
          {d.discount > 0 && <p>Discount − Rs {d.discount.toFixed(2)}</p>}
        </div>
      </div>

      <Dashed />
      <p className="text-center text-2xl font-black">Total : {d.total.toFixed(2)}</p>
      <Dashed />

      <div className="text-center text-sm">
        <p className="font-semibold">Payment Mode</p>
        <p className="capitalize">
          {d.paymentMode.replace("_", " ")} : {d.paid.toFixed(2)}
        </p>
        {d.due > 0 && <p className="text-destructive">Due : {d.due.toFixed(2)}</p>}
      </div>

      <p className="mt-3 text-center text-xs text-muted-foreground">
        Thank you! Visit again 🙏
      </p>
    </div>
  );
}
