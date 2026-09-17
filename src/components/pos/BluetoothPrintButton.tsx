import { useState } from "react";
import { Bluetooth } from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { bluetoothPrintSupported, printViaBluetooth } from "@/lib/bt-print";
import { printReceipt, type ReceiptData } from "@/lib/receipt";

export function BluetoothPrintButton({
  receipt,
  className,
  tile,
}: {
  receipt: ReceiptData | (() => Promise<ReceiptData>);
  className?: string;
  /** Big icon-over-label tile used on the checkout screen */
  tile?: boolean;
}) {
  const [busy, setBusy] = useState(false);

  async function run() {
    setBusy(true);
    try {
      const d = typeof receipt === "function" ? await receipt() : receipt;
      if (!bluetoothPrintSupported()) {
        printReceipt(d);
        toast.message("Bluetooth print is browser me nahi chalta — normal print khol diya.");
        return;
      }
      await printViaBluetooth(d);
      toast.success("Bill printer par bhej diya");
    } catch (e) {
      const msg = e instanceof Error ? e.message : "Print failed";
      if (!/cancel/i.test(msg)) toast.error(msg);
    } finally {
      setBusy(false);
    }
  }

  if (tile) {
    return (
      <Button
        type="button"
        variant="outline"
        disabled={busy}
        onClick={() => void run()}
        className={`h-auto flex-col gap-1.5 px-2 py-3 text-xs font-semibold ${className ?? ""}`}
      >
        <Bluetooth className="h-6 w-6 text-primary" />
        {busy ? "…" : "Print Bill"}
      </Button>
    );
  }

  return (
    <Button variant="outline" className={className} disabled={busy} onClick={() => void run()}>
      <Bluetooth className="mr-1 h-4 w-4" /> {busy ? "…" : "Print"}
    </Button>
  );
}
