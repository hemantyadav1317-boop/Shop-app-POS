import QRCode from "qrcode";
import type { ReceiptData } from "@/lib/receipt";

/** Standard UPI deep link. Amount = remaining payable for THIS bill. */
export function upiUri(d: ReceiptData): string | null {
  if (!d.upiId || d.due <= 0) return null;
  const amt = d.due.toFixed(2);
  const p = new URLSearchParams({
    pa: d.upiId.trim(),
    pn: (d.upiName || d.shopName).trim(),
    am: amt,
    mam: amt, // minimum amount = amount (where apps support it)
    cu: "INR",
    tn: `Bill ${d.billNo}`,
    tr: `BILL${d.billNo}`,
  });
  return `upi://pay?${p.toString().replace(/\+/g, "%20")}`;
}

export function paymentStatus(d: ReceiptData) {
  if (d.due <= 0) return "PAID";
  if (d.paymentMode === "credit") return "CREDIT (DUE)";
  return d.paid > 0 ? "PARTLY PAID — PENDING" : "PAYMENT PENDING";
}

export async function upiQrDataUrl(d: ReceiptData, size = 320) {
  const uri = upiUri(d);
  if (!uri) return null;
  return QRCode.toDataURL(uri, { width: size, margin: 1, errorCorrectionLevel: "M" });
}

type Row = { text: string; size: number; align: "l" | "c"; bold?: boolean; right?: string };

/**
 * Bill ko canvas par draw karta hai. width = logical px (384 = 58mm printer),
 * scale = sharpness multiplier (share image ke liye 3).
 */
export async function renderBillCanvas(d: ReceiptData, width = 384, scale = 1) {
  const pad = 10;
  const lh = 24;
  const rows: Row[] = [];
  const line = { text: "-".repeat(40), size: 14, align: "c" as const };

  rows.push({ text: d.shopName, size: 24, align: "c", bold: true });
  if (d.shopAddress) rows.push({ text: d.shopAddress, size: 15, align: "c" });
  if (d.shopPhone) rows.push({ text: d.shopPhone, size: 15, align: "c" });
  rows.push({ text: "INVOICE", size: 17, align: "c", bold: true });
  rows.push(line);
  rows.push({ text: `Bill #${d.billNo}`, size: 16, align: "l", right: d.date });
  if (d.customerName) rows.push({ text: d.customerName, size: 16, align: "l", right: d.customerPhone ?? "" });
  rows.push(line);
  for (const l of d.lines) {
    rows.push({ text: l.name, size: 17, align: "l" });
    rows.push({ text: `  ${l.qty} ${l.unit} x ${l.price}`, size: 16, align: "l", right: (l.qty * l.price).toFixed(2) });
  }
  rows.push(line);
  rows.push({ text: "Sub Total", size: 16, align: "l", right: d.subTotal.toFixed(2) });
  if (d.discount > 0) rows.push({ text: "Discount", size: 16, align: "l", right: `-${d.discount.toFixed(2)}` });
  rows.push({ text: "Tax", size: 16, align: "l", right: "0.00" });
  rows.push({ text: "TOTAL", size: 22, align: "l", bold: true, right: `Rs ${d.total.toFixed(2)}` });
  rows.push({ text: `Mode: ${d.paymentMode.replace("_", " ")}`, size: 16, align: "l", right: `Paid ${d.paid.toFixed(2)}` });
  if (d.due > 0) rows.push({ text: "Due", size: 17, align: "l", bold: true, right: d.due.toFixed(2) });
  rows.push({ text: paymentStatus(d), size: 17, align: "c", bold: true });

  const qrUrl = await upiQrDataUrl(d, 600);
  const qrSize = Math.round(width * 0.62);
  const tail: Row[] = [];
  if (qrUrl) {
    tail.push({ text: "SCAN TO PAY", size: 18, align: "c", bold: true });
  }
  const after: Row[] = [];
  if (qrUrl) {
    after.push({ text: `Rs ${d.due.toFixed(2)}`, size: 18, align: "c", bold: true });
    after.push({ text: `UPI: ${d.upiId}`, size: 14, align: "c" });
    if (d.upiName) after.push({ text: d.upiName, size: 14, align: "c" });
  }
  after.push({ text: "Thank you! Visit again", size: 16, align: "c" });
  after.push({ text: " ", size: 14, align: "c" });

  const height = pad * 2 + (rows.length + tail.length + after.length) * lh + (qrUrl ? qrSize + 8 : 0);
  const canvas = document.createElement("canvas");
  canvas.width = width * scale;
  canvas.height = Math.ceil(height * scale);
  // printer raster needs width multiple of 8
  if (scale === 1) canvas.width = Math.ceil(width / 8) * 8;
  const ctx = canvas.getContext("2d")!;
  ctx.scale(scale, scale);
  ctx.fillStyle = "#fff";
  ctx.fillRect(0, 0, width, height);
  ctx.fillStyle = "#000";
  ctx.textBaseline = "middle";

  let y = pad;
  const draw = (r: Row) => {
    const cy = y + lh / 2;
    ctx.font = `${r.bold ? "bold " : ""}${r.size}px "Noto Sans Devanagari", system-ui, sans-serif`;
    if (r.align === "c") {
      ctx.textAlign = "center";
      ctx.fillText(r.text, width / 2, cy, width - pad * 2);
    } else {
      ctx.textAlign = "left";
      ctx.fillText(r.text, pad, cy, width - pad * 2 - 120);
    }
    if (r.right) {
      ctx.textAlign = "right";
      ctx.fillText(r.right, width - pad, cy);
    }
    y += lh;
  };
  rows.forEach(draw);
  tail.forEach(draw);
  if (qrUrl) {
    const img = new Image();
    img.src = qrUrl;
    await img.decode();
    ctx.imageSmoothingEnabled = false;
    ctx.drawImage(img, (width - qrSize) / 2, y + 4, qrSize, qrSize);
    y += qrSize + 8;
  }
  after.forEach(draw);
  return canvas;
}

/** Bill PNG banake share sheet kholta hai (WhatsApp etc.), warna download. */
export async function shareBillImage(d: ReceiptData) {
  const canvas = await renderBillCanvas(d, 420, 3);
  const blob: Blob = await new Promise((res, rej) =>
    canvas.toBlob((b) => (b ? res(b) : rej(new Error("Image nahi ban paayi"))), "image/png"),
  );
  const file = new File([blob], `bill-${d.billNo}.png`, { type: "image/png" });
  const nav = navigator as Navigator & { canShare?: (x: unknown) => boolean };
  if (nav.share && nav.canShare?.({ files: [file] })) {
    try {
      await nav.share({ files: [file], title: `Bill #${d.billNo}` });
      return "shared" as const;
    } catch (e) {
      if (e instanceof Error && e.name === "AbortError") return "cancelled" as const;
    }
  }
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = file.name;
  a.click();
  setTimeout(() => URL.revokeObjectURL(url), 2000);
  return "downloaded" as const;
}
