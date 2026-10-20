export type StockRow = { name: string; quantity: number; category?: string | undefined; unit?: "kg" | "pc" | undefined; price?: number | undefined; cost_price?: number | undefined };

function splitLine(line: string): string[] {
  const out: string[] = []; let cur = ""; let q = false;
  for (const ch of line) {
    if (ch === '"') q = !q;
    else if (ch === "," && !q) { out.push(cur.trim()); cur = ""; }
    else cur += ch;
  }
  out.push(cur.trim());
  return out;
}

const num = (v?: string) => { if (v === undefined || v === "") return undefined; const n = Number(v); return Number.isFinite(n) ? n : undefined; };

/** Parses CSV with header: name, quantity (or stock/qty), optional category, unit, price, cost_price. */
export function parseStockCsv(text: string): StockRow[] {
  const lines = text.replace(/^\uFEFF/, "").split(/\r?\n/).filter((l) => l.trim());
  if (lines.length < 2) return [];
  const head = splitLine(lines[0] ?? "").map((h) => h.toLowerCase().replace(/\s+/g, "_"));
  const idx = (...names: string[]) => head.findIndex((h) => names.includes(h));
  const iName = idx("name", "product", "item"), iQty = idx("quantity", "qty", "stock");
  if (iName < 0 || iQty < 0) return [];
  const iCat = idx("category"), iUnit = idx("unit"), iPrice = idx("price", "sale_price", "rate"), iCost = idx("cost_price", "cost");
  const rows: StockRow[] = [];
  for (const line of lines.slice(1)) {
    const c = splitLine(line);
    const name = c[iName]?.trim(); const quantity = num(c[iQty]);
    if (!name || quantity === undefined) continue;
    const u = iUnit >= 0 ? c[iUnit]?.toLowerCase() : undefined;
    rows.push({ name, quantity, category: iCat >= 0 ? c[iCat] || undefined : undefined, unit: u === "pc" || u === "kg" ? u : undefined, price: iPrice >= 0 ? num(c[iPrice]) : undefined, cost_price: iCost >= 0 ? num(c[iCost]) : undefined });
  }
  return rows;
}
