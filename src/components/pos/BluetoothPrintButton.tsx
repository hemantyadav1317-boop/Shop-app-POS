import { useState } from "react";
import { Bluetooth } from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { bluetoothPrintSupported, printViaBluetooth } from "@/lib/bt-print";
import { printReceipt, type ReceiptData } from "@/lib/receipt";

export function BluetoothPrintButton({
  receipt,
  className,
}: {
  receipt: ReceiptData | (() => Promise<ReceiptData>);
  className?: string;
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

  return (
    <Button variant="outline" className={className} disabled={busy} onClick={() => void run()}>
      <Bluetooth className="mr-1 h-4 w-4" /> {busy ? "…" : "Print"}
    </Button>
  );
}
