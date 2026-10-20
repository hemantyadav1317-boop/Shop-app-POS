import type { ReceiptData } from "@/lib/receipt";
import { renderBillCanvas } from "@/lib/bill-image";

/**
 * Bluetooth thermal printer (ESC/POS) support.
 * Receipt ko canvas par render karke raster image ke roop me bheja jata hai,
 * taaki Hindi naam bhi sahi print ho (thermal font me Devanagari nahi hota).
 */

const PRINTER_SERVICES = [
  "000018f0-0000-1000-8000-00805f9b34fb",
  "0000ff00-0000-1000-8000-00805f9b34fb",
  "0000ffe0-0000-1000-8000-00805f9b34fb",
  "e7810a71-73ae-499d-8c15-faa9aef0c3f2",
  "49535343-fe7d-4ae5-8fa9-9fafd205e455",
];

const DOTS = 384; // 58mm printer = 384 dots per line
const KEY = "pos.printer.name";

type BtChar = { writeValueWithoutResponse?: (b: BufferSource) => Promise<void>; writeValue: (b: BufferSource) => Promise<void> };
type BtDevice = { name?: string; gatt?: { connected: boolean; connect: () => Promise<BtServer> } };
type BtServer = { getPrimaryServices: () => Promise<Array<{ getCharacteristics: () => Promise<Array<BtChar & { properties: { write: boolean; writeWithoutResponse: boolean } }>> }>> };

let device: BtDevice | null = null;
let chara: BtChar | null = null;

export function bluetoothPrintSupported() {
  return typeof navigator !== "undefined" && "bluetooth" in navigator;
}

export function savedPrinterName() {
  try {
    return localStorage.getItem(KEY);
  } catch {
    return null;
  }
}

async function getCharacteristic(): Promise<BtChar> {
  if (chara && device?.gatt?.connected) return chara;

  if (!bluetoothPrintSupported()) throw new Error("Is browser me Bluetooth print support nahi hai. Chrome/Android use karein.");

  const nav = navigator as unknown as {
    bluetooth: { requestDevice: (o: unknown) => Promise<BtDevice> };
  };

  if (!device) {
    device = await nav.bluetooth.requestDevice({
      acceptAllDevices: true,
      optionalServices: PRINTER_SERVICES,
    });
  }

  const server = await device.gatt!.connect();
  const services = await server.getPrimaryServices();
  for (const s of services) {
    const chars = await s.getCharacteristics();
    const w = chars.find((c) => c.properties.write || c.properties.writeWithoutResponse);
    if (w) {
      chara = w;
      try {
        if (device.name) localStorage.setItem(KEY, device.name);
      } catch {
        /* ignore */
      }
      return w;
    }
  }
  throw new Error("Printer me writable channel nahi mila.");
}

async function send(bytes: Uint8Array) {
  const c = await getCharacteristic();
  const chunk = 180;
  for (let i = 0; i < bytes.length; i += chunk) {
    const part = bytes.slice(i, i + chunk);
    if (c.writeValueWithoutResponse) await c.writeValueWithoutResponse(part);
    else await c.writeValue(part);
    await new Promise((r) => setTimeout(r, 18));
  }
}

/** Canvas ko ESC/POS raster (GS v 0) bytes me badalta hai. */
function canvasToEscPos(canvas: HTMLCanvasElement) {
  const ctx = canvas.getContext("2d")!;
  const { width, height } = canvas;
  const img = ctx.getImageData(0, 0, width, height).data;
  const bytesPerRow = width / 8;
  const raster = new Uint8Array(bytesPerRow * height);

  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const i = (y * width + x) * 4;
      const lum = (img[i]! * 0.299 + img[i + 1]! * 0.587 + img[i + 2]! * 0.114) / 255;
      if (lum < 0.6) raster[y * bytesPerRow + (x >> 3)]! |= 0x80 >> (x & 7);
    }
  }

  const header = new Uint8Array([
    0x1b, 0x40, // init
    0x1d, 0x76, 0x30, 0x00,
    bytesPerRow & 0xff, (bytesPerRow >> 8) & 0xff,
    height & 0xff, (height >> 8) & 0xff,
  ]);
  const footer = new Uint8Array([0x0a, 0x0a, 0x0a, 0x1d, 0x56, 0x42, 0x00]); // feed + cut

  const out = new Uint8Array(header.length + raster.length + footer.length);
  out.set(header, 0);
  out.set(raster, header.length);
  out.set(footer, header.length + raster.length);
  return out;
}

/** Bill ko Bluetooth thermal printer par print karta hai. */
export async function printViaBluetooth(d: ReceiptData) {
  // Narrower logical layout scaled up to full printer width = bigger, readable text.
  const scale = PRINT_SCALES[printSize()];
  const canvas = await renderBillCanvas(d, Math.round(DOTS / scale), scale);
  const bytes = canvasToEscPos(fitWidth(canvas));
  await send(bytes);
}

export type PrintSize = "normal" | "large" | "xl";
const PRINT_SCALES: Record<PrintSize, number> = { normal: 1, large: 1.4, xl: 1.75 };
const SIZE_KEY = "pos.printer.size";
export function printSize(): PrintSize {
  try { const v = localStorage.getItem(SIZE_KEY); return v === "normal" || v === "xl" ? v : "large"; } catch { return "large"; }
}
export function setPrintSize(v: PrintSize) { try { localStorage.setItem(SIZE_KEY, v); } catch { /* ignore */ } }

/** Raster width must be exactly the printer width (multiple of 8). */
function fitWidth(src: HTMLCanvasElement) {
  if (src.width === DOTS) return src;
  const c = document.createElement("canvas");
  c.width = DOTS; c.height = Math.ceil(src.height * DOTS / src.width);
  const ctx = c.getContext("2d")!;
  ctx.fillStyle = "#fff"; ctx.fillRect(0, 0, c.width, c.height);
  ctx.drawImage(src, 0, 0, c.width, c.height);
  return c;
}

/** Printer pehle se pair hai ya nahi — UI label ke liye. */
export async function pairPrinter() {
  await getCharacteristic();
  return device?.name ?? "Printer";
}

export function forgetPrinter() {
  device = null;
  chara = null;
  try {
    localStorage.removeItem(KEY);
  } catch {
    /* ignore */
  }
}
