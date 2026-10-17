import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { supabase } from "@/integrations/supabase/client";

export type DbProduct = {
  id: string;
  shop_id: string;
  name: string;
  category: string;
  name_en?: string | null;
  name_hi?: string | null;
  image_url?: string | null;
  sku?: string | null;
  barcode?: string | null;
  unit: "kg" | "pc";
  price: number;
  cost_price: number;
  stock: number;
  low_stock_at: number;
  is_active: boolean;
};

export type DbCustomer = {
  id: string;
  name: string;
  phone: string | null;
  address: string | null;
  balance: number;
};

export type DbVendor = {
  id: string;
  name: string;
  phone: string | null;
  address: string | null;
  payable: number;
};

export type DbSale = {
  id: string;
  bill_no: number;
  customer_name: string | null;
  customer_phone: string | null;
  sub_total: number;
  discount: number;
  total: number;
  paid: number;
  due: number;
  payment_mode: string;
  created_at: string;
};

const enabledOn = (shopId?: string | null) => ({ enabled: !!shopId });

export function useProducts(shopId?: string | null) {
  return useQuery({
    queryKey: ["products", shopId],
    ...enabledOn(shopId),
    queryFn: async () => {
      const { data, error } = await supabase
        .from("products")
        .select("*")
        .eq("shop_id", shopId!)
        .eq("is_active", true)
        .order("name");
      if (error) throw error;
      return (data ?? []) as unknown as DbProduct[];
    },
  });
}

export function useCustomers(shopId?: string | null) {
  return useQuery({
    queryKey: ["customers", shopId],
    ...enabledOn(shopId),
    queryFn: async () => {
      const { data, error } = await supabase
        .from("customers")
        .select("*")
        .eq("shop_id", shopId!)
        .order("name");
      if (error) throw error;
      return (data ?? []) as unknown as DbCustomer[];
    },
  });
}

export function useVendors(shopId?: string | null) {
  return useQuery({
    queryKey: ["vendors", shopId],
    ...enabledOn(shopId),
    queryFn: async () => {
      const { data, error } = await supabase
        .from("vendors")
        .select("*")
        .eq("shop_id", shopId!)
        .order("name");
      if (error) throw error;
      return (data ?? []) as unknown as DbVendor[];
    },
  });
}

export function useSales(shopId?: string | null) {
  return useQuery({
    queryKey: ["sales", shopId],
    ...enabledOn(shopId),
    queryFn: async () => {
      const { data, error } = await supabase
        .from("sales")
        .select("*")
        .eq("shop_id", shopId!)
        .order("created_at", { ascending: false })
        .limit(500);
      if (error) throw error;
      return (data ?? []) as unknown as DbSale[];
    },
  });
}

export function useSaleItems(saleId?: string | null) {
  return useQuery({
    queryKey: ["sale_items", saleId],
    enabled: !!saleId,
    queryFn: async () => {
      const { data, error } = await supabase
        .from("sale_items")
        .select("*")
        .eq("sale_id", saleId!)
        .order("created_at");
      if (error) throw error;
      return data ?? [];
    },
  });
}

export function useExpenses(shopId?: string | null) {
  return useQuery({
    queryKey: ["expenses", shopId],
    ...enabledOn(shopId),
    queryFn: async () => {
      const { data, error } = await supabase
        .from("expenses")
        .select("*")
        .eq("shop_id", shopId!)
        .order("spent_on", { ascending: false })
        .limit(500);
      if (error) throw error;
      return data ?? [];
    },
  });
}

export function usePurchases(shopId?: string | null) {
  return useQuery({
    queryKey: ["purchases", shopId],
    ...enabledOn(shopId),
    queryFn: async () => {
      const { data, error } = await supabase
        .from("purchases")
        .select("*")
        .eq("shop_id", shopId!)
        .order("created_at", { ascending: false })
        .limit(300);
      if (error) throw error;
      return data ?? [];
    },
  });
}

export function useSavedOrders(shopId?: string | null) {
  return useQuery({
    queryKey: ["saved_orders", shopId],
    ...enabledOn(shopId),
    queryFn: async () => {
      const { data, error } = await supabase
        .from("saved_orders")
        .select("*")
        .eq("shop_id", shopId!)
        .order("created_at", { ascending: false });
      if (error) throw error;
      return data ?? [];
    },
  });
}

export function usePayments(shopId?: string | null) {
  return useQuery({
    queryKey: ["payments", shopId],
    ...enabledOn(shopId),
    queryFn: async () => {
      const { data, error } = await supabase
        .from("payments")
        .select("*")
        .eq("shop_id", shopId!)
        .order("created_at", { ascending: false })
        .limit(500);
      if (error) throw error;
      return data ?? [];
    },
  });
}

export function useShopMembers(shopId?: string | null) {
  return useQuery({
    queryKey: ["shop_members", shopId],
    ...enabledOn(shopId),
    queryFn: async () => {
      const { data, error } = await supabase
        .from("shop_members")
        .select("id, user_id, role, created_at")
        .eq("shop_id", shopId!);
      if (error) throw error;
      return data ?? [];
    },
  });
}

/** Invalidate everything that a money/stock movement can touch. */
export function useInvalidatePos() {
  const qc = useQueryClient();
  return () => {
    [
      "products",
      "customers",
      "vendors",
      "sales",
      "expenses",
      "purchases",
      "payments",
      "saved_orders",
    ].forEach((k) => qc.invalidateQueries({ queryKey: [k] }));
  };
}

export function useTableMutation<TVars>(fn: (v: TVars) => Promise<unknown>) {
  const invalidate = useInvalidatePos();
  return useMutation({
    mutationFn: fn,
    onSuccess: () => invalidate(),
  });
}
