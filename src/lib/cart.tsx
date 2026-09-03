import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from "react";

export type CartLine = {
  product_id: string | null;
  name: string;
  price: number;
  unit: "kg" | "pc";
  qty: number;
};

export type CartCustomer = { id: string | null; name: string; phone: string } | null;

type Ctx = {
  lines: CartLine[];
  addLine: (l: Omit<CartLine, "qty"> & { qty?: number }) => void;
  setQty: (productId: string | null, name: string, qty: number) => void;
  removeLine: (productId: string | null, name: string) => void;
  clear: () => void;
  loadLines: (lines: CartLine[], customer?: CartCustomer) => void;
  customer: CartCustomer;
  setCustomer: (c: CartCustomer) => void;
  discount: number;
  setDiscount: (n: number) => void;
  subTotal: number;
  total: number;
};

const CartContext = createContext<Ctx | null>(null);
const KEY = "pos.cart.v2";

const same = (l: CartLine, id: string | null, name: string) =>
  (l.product_id ?? `n:${l.name}`) === (id ?? `n:${name}`);

export function CartProvider({ children }: { children: ReactNode }) {
  const [lines, setLines] = useState<CartLine[]>([]);
  const [customer, setCustomer] = useState<CartCustomer>(null);
  const [discount, setDiscount] = useState(0);
  const [ready, setReady] = useState(false);

  useEffect(() => {
    try {
      const raw = localStorage.getItem(KEY);
      if (raw) {
        const parsed = JSON.parse(raw) as { lines: CartLine[]; customer: CartCustomer };
        setLines(parsed.lines ?? []);
        setCustomer(parsed.customer ?? null);
      }
    } catch {
      /* ignore */
    }
    setReady(true);
  }, []);

  useEffect(() => {
    if (!ready) return;
    try {
      localStorage.setItem(KEY, JSON.stringify({ lines, customer }));
    } catch {
      /* ignore */
    }
  }, [lines, customer, ready]);

  const addLine = useCallback((l: Omit<CartLine, "qty"> & { qty?: number }) => {
    setLines((prev) => {
      const idx = prev.findIndex((x) => same(x, l.product_id, l.name));
      const found = prev[idx];
      if (idx >= 0 && found) {
        const next = [...prev];
        next[idx] = { ...found, qty: +(found.qty + (l.qty ?? 1)).toFixed(3) };
        return next;
      }
      return [...prev, { ...l, qty: l.qty ?? 1 }];
    });
  }, []);

  const setQty = useCallback((productId: string | null, name: string, qty: number) => {
    setLines((prev) =>
      qty <= 0
        ? prev.filter((l) => !same(l, productId, name))
        : prev.map((l) => (same(l, productId, name) ? { ...l, qty: +qty.toFixed(3) } : l)),
    );
  }, []);

  const removeLine = useCallback(
    (productId: string | null, name: string) =>
      setLines((prev) => prev.filter((l) => !same(l, productId, name))),
    [],
  );

  const clear = useCallback(() => {
    setLines([]);
    setDiscount(0);
    setCustomer(null);
  }, []);

  const loadLines = useCallback((next: CartLine[], c?: CartCustomer) => {
    setLines(next);
    if (c !== undefined) setCustomer(c);
  }, []);

  const subTotal = useMemo(() => lines.reduce((s, l) => s + l.price * l.qty, 0), [lines]);
  const total = Math.max(0, +(subTotal - discount).toFixed(2));

  const value: Ctx = {
    lines,
    addLine,
    setQty,
    removeLine,
    clear,
    loadLines,
    customer,
    setCustomer,
    discount,
    setDiscount,
    subTotal,
    total,
  };

  return <CartContext.Provider value={value}>{children}</CartContext.Provider>;
}

export function useCart() {
  const ctx = useContext(CartContext);
  if (!ctx) throw new Error("useCart must be used inside CartProvider");
  return ctx;
}
