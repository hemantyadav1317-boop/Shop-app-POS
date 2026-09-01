import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from "react";
import type { Product } from "./pos-data";

export type CartLine = {
  id: string;
  name: string;
  price: number;
  unit: "kg" | "pc";
  qty: number;
};

export type Customer = { name: string; phone: string } | null;

export type Bill = {
  id: string;
  no: number;
  createdAt: string;
  lines: CartLine[];
  subTotal: number;
  discount: number;
  total: number;
  payment: string;
  customer: Customer;
};

export type SavedOrder = {
  id: string;
  createdAt: string;
  lines: CartLine[];
  customer: Customer;
};

type Ctx = {
  cart: CartLine[];
  add: (p: Product) => void;
  setQty: (id: string, qty: number) => void;
  remove: (id: string) => void;
  clear: () => void;
  customer: Customer;
  setCustomer: (c: Customer) => void;
  discount: number;
  setDiscount: (n: number) => void;
  subTotal: number;
  total: number;
  itemCount: number;
  bills: Bill[];
  checkout: (payment: string) => Bill;
  savedOrders: SavedOrder[];
  saveOrder: () => void;
  resumeOrder: (id: string) => void;
  deleteSavedOrder: (id: string) => void;
};

const PosContext = createContext<Ctx | null>(null);

function useLocal<T>(key: string, initial: T) {
  const [value, setValue] = useState<T>(initial);
  const [ready, setReady] = useState(false);

  useEffect(() => {
    try {
      const raw = localStorage.getItem(key);
      if (raw) setValue(JSON.parse(raw) as T);
    } catch {
      /* ignore */
    }
    setReady(true);
  }, [key]);

  useEffect(() => {
    if (!ready) return;
    try {
      localStorage.setItem(key, JSON.stringify(value));
    } catch {
      /* ignore */
    }
  }, [key, value, ready]);

  return [value, setValue] as const;
}

export function PosProvider({ children }: { children: ReactNode }) {
  const [cart, setCart] = useLocal<CartLine[]>("pos.cart", []);
  const [bills, setBills] = useLocal<Bill[]>("pos.bills", []);
  const [savedOrders, setSavedOrders] = useLocal<SavedOrder[]>("pos.saved", []);
  const [customer, setCustomer] = useLocal<Customer>("pos.customer", null);
  const [discount, setDiscount] = useState(0);

  const add = useCallback(
    (p: Product) => {
      setCart((prev) => {
        const found = prev.find((l) => l.id === p.id);
        if (found) {
          return prev.map((l) => (l.id === p.id ? { ...l, qty: +(l.qty + 1).toFixed(2) } : l));
        }
        return [...prev, { id: p.id, name: p.name, price: p.price, unit: p.unit, qty: 1 }];
      });
    },
    [setCart],
  );

  const setQty = useCallback(
    (id: string, qty: number) => {
      setCart((prev) =>
        qty <= 0
          ? prev.filter((l) => l.id !== id)
          : prev.map((l) => (l.id === id ? { ...l, qty: +qty.toFixed(3) } : l)),
      );
    },
    [setCart],
  );

  const remove = useCallback((id: string) => setCart((p) => p.filter((l) => l.id !== id)), [setCart]);

  const clear = useCallback(() => {
    setCart([]);
    setDiscount(0);
    setCustomer(null);
  }, [setCart, setCustomer]);

  const subTotal = useMemo(() => cart.reduce((s, l) => s + l.price * l.qty, 0), [cart]);
  const total = Math.max(0, subTotal - discount);
  const itemCount = cart.length;

  const checkout = useCallback(
    (payment: string) => {
      const bill: Bill = {
        id: crypto.randomUUID(),
        no: bills.length + 1,
        createdAt: new Date().toISOString(),
        lines: cart,
        subTotal,
        discount,
        total,
        payment,
        customer,
      };
      setBills((prev) => [bill, ...prev]);
      setCart([]);
      setDiscount(0);
      setCustomer(null);
      return bill;
    },
    [bills.length, cart, subTotal, discount, total, customer, setBills, setCart, setCustomer],
  );

  const saveOrder = useCallback(() => {
    if (!cart.length) return;
    setSavedOrders((prev) => [
      { id: crypto.randomUUID(), createdAt: new Date().toISOString(), lines: cart, customer },
      ...prev,
    ]);
    setCart([]);
    setCustomer(null);
  }, [cart, customer, setSavedOrders, setCart, setCustomer]);

  const resumeOrder = useCallback(
    (id: string) => {
      const order = savedOrders.find((o) => o.id === id);
      if (!order) return;
      setCart(order.lines);
      setCustomer(order.customer);
      setSavedOrders((prev) => prev.filter((o) => o.id !== id));
    },
    [savedOrders, setCart, setCustomer, setSavedOrders],
  );

  const deleteSavedOrder = useCallback(
    (id: string) => setSavedOrders((prev) => prev.filter((o) => o.id !== id)),
    [setSavedOrders],
  );

  const value: Ctx = {
    cart,
    add,
    setQty,
    remove,
    clear,
    customer,
    setCustomer,
    discount,
    setDiscount,
    subTotal,
    total,
    itemCount,
    bills,
    checkout,
    savedOrders,
    saveOrder,
    resumeOrder,
    deleteSavedOrder,
  };

  return <PosContext.Provider value={value}>{children}</PosContext.Provider>;
}

export function usePos() {
  const ctx = useContext(PosContext);
  if (!ctx) throw new Error("usePos must be used inside PosProvider");
  return ctx;
}
