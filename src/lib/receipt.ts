export type ReceiptLine = { name: string; qty: number; unit: string; price: number };

export type ReceiptData = {
  shopName: string;
  shopPhone?: string | null;
  shopAddress?: string | null;
  billNo: number;
  date: string;
  customerName?: string | null;
  customerPhone?: string | null;
  lines: ReceiptLine[];
  subTotal: number;
  discount: number;
  total: number;
  paid: number;
  due: number;
  paymentMode: string;
  saleId?: string;
  upiId?: string | null;
  upiName?: string | null;
};

export function receiptHtml(d: ReceiptData, qr?: string | null, status?: string) {
  const rows = d.lines
    .map(
      (l) =>
        `<tr><td>${escapeHtml(l.name)}</td><td class="r">${l.qty} ${l.unit}</td><td class="r">${l.price.toFixed(
          2,
        )}</td><td class="r">${(l.qty * l.price).toFixed(2)}</td></tr>`,
    )
    .join("");

  return `<!doctype html><html><head><meta charset="utf-8"><title>Bill #${d.billNo}</title>
<style>
  *{font-family:ui-monospace,Menlo,Consolas,monospace;box-sizing:border-box}
  body{margin:0;padding:12px;color:#000;background:#fff;font-size:12px}
  h1{font-size:16px;margin:0 0 2px;text-align:center}
  .c{text-align:center}.r{text-align:right}
  table{width:100%;border-collapse:collapse;margin-top:8px}
  td,th{padding:2px 0}
  thead th{border-bottom:1px dashed #000;text-align:left;font-size:11px}
  .tot{border-top:1px dashed #000;margin-top:8px;padding-top:6px}
  .row{display:flex;justify-content:space-between}
  .big{font-size:14px;font-weight:700}
  @media print{@page{margin:4mm}}
</style></head><body>
<h1>${escapeHtml(d.shopName)}</h1>
<div class="c">${escapeHtml(d.shopAddress ?? "")}</div>
<div class="c">${escapeHtml(d.shopPhone ?? "")}</div>
<div class="tot"></div>
<div class="row"><span>Bill #${d.billNo}</span><span>${escapeHtml(d.date)}</span></div>
${d.customerName ? `<div class="row"><span>${escapeHtml(d.customerName)}</span><span>${escapeHtml(d.customerPhone ?? "")}</span></div>` : ""}
<table><thead><tr><th>Item</th><th class="r">Qty</th><th class="r">Rate</th><th class="r">Amt</th></tr></thead><tbody>${rows}</tbody></table>
<div class="tot">
  <div class="row"><span>Sub Total</span><span>${d.subTotal.toFixed(2)}</span></div>
  <div class="row"><span>Discount</span><span>-${d.discount.toFixed(2)}</span></div>
  <div class="row"><span>Tax</span><span>0.00</span></div>
  <div class="row big"><span>Total</span><span>Rs ${d.total.toFixed(2)}</span></div>
  <div class="row"><span>Paid (${escapeHtml(d.paymentMode)})</span><span>${d.paid.toFixed(2)}</span></div>
  ${d.due > 0 ? `<div class="row"><span>Due</span><span>${d.due.toFixed(2)}</span></div>` : ""}
</div>
<p class="c big">${escapeHtml(status ?? "")}</p>
${qr ? `<div class="c"><p class="big">SCAN TO PAY</p><img src="${qr}" style="width:60%;image-rendering:pixelated"/><p class="big">Rs ${d.due.toFixed(2)}</p><p>UPI: ${escapeHtml(d.upiId ?? "")}<br/>${escapeHtml(d.upiName ?? "")}</p></div>` : ""}
<p class="c">Thank you! Visit again 🙏</p>
</body></html>`;
}

function escapeHtml(s: string) {
  return s.replace(/[&<>"']/g, (c) =>
    ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c] ?? c,
  );
}

export async function printReceipt(d: ReceiptData) {
  const w = window.open("", "_blank", "width=420,height=640");
  if (!w) return false;
  const { upiQrDataUrl, paymentStatus } = await import("@/lib/bill-image");
  const qr = await upiQrDataUrl(d, 360);
  w.document.write(receiptHtml(d, qr, paymentStatus(d)));
  w.document.close();
  w.focus();
  setTimeout(() => w.print(), 300);
  return true;
}

export function receiptText(d: ReceiptData) {
  const lines = d.lines
    .map((l) => `${l.name} — ${l.qty}${l.unit} x ${l.price} = ${(l.qty * l.price).toFixed(2)}`)
    .join("\n");
  return `${d.shopName}\nBill #${d.billNo} · ${d.date}\n\n${lines}\n\nSub Total: ${d.subTotal.toFixed(
    2,
  )}\nDiscount: ${d.discount.toFixed(2)}\nTotal: Rs ${d.total.toFixed(2)}\nPaid: ${d.paid.toFixed(
    2,
  )} (${d.paymentMode})${d.due > 0 ? `\nDue: ${d.due.toFixed(2)}` : ""}\n\nThank you!`;
}

export async function shareReceipt(d: ReceiptData) {
  const text = receiptText(d);
  if (navigator.share) {
    try {
      await navigator.share({ title: `Bill #${d.billNo}`, text });
      return "shared" as const;
    } catch {
      return "cancelled" as const;
    }
  }
  await navigator.clipboard.writeText(text);
  return "copied" as const;
}

export function downloadBill(d: ReceiptData) {
  const blob = new Blob([receiptHtml(d)], { type: "text/html" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = `bill-${d.billNo}.html`;
  a.click();
  URL.revokeObjectURL(url);
}

export function downloadCsv(filename: string, rows: Record<string, unknown>[]) {
  if (!rows.length) return false;
  const headers = Object.keys(rows[0]!);
  const body = rows
    .map((r) =>
      headers
        .map((h) => {
          const v = r[h] ?? "";
          return `"${String(v).replace(/"/g, '""')}"`;
        })
        .join(","),
    )
    .join("\n");
  const blob = new Blob([`${headers.join(",")}\n${body}`], { type: "text/csv" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  a.click();
  URL.revokeObjectURL(url);
  return true;
}
