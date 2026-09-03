import { createContext, useContext, type ReactNode } from "react";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { supabase } from "@/integrations/supabase/client";
import { useAuth } from "./auth";
import { PRODUCTS } from "./pos-data";

export type ShopRole = "owner" | "manager" | "cashier";

export type Shop = {
  id: string;
  owner_id: string;
  name: string;
  phone: string | null;
  address: string | null;
  currency: string;
  gst_number: string | null;
  bill_prefix: string;
};

type Ctx = {
  shop: Shop | null;
  role: ShopRole | null;
  loading: boolean;
  refresh: () => void;
};

const ShopContext = createContext<Ctx>({ shop: null, role: null, loading: true, refresh: () => {} });

async function seedCatalogue(shopId: string) {
  const rows = PRODUCTS.map((p) => ({
    shop_id: shopId,
    name: p.name,
    category: p.category,
    unit: p.unit,
    price: p.price,
    stock: p.stock,
    low_stock_at: 5,
  }));
  await supabase.from("products").insert(rows);
}

async function loadOrCreateShop(userId: string, email: string | undefined) {
  const { data: members, error } = await supabase
    .from("shop_members")
    .select("role, shop_id, shops(*)")
    .eq("user_id", userId)
    .limit(1);
  if (error) throw error;

  const existing = members?.[0];
  if (existing?.shops) {
    return { shop: existing.shops as unknown as Shop, role: existing.role as ShopRole };
  }

  const { data: shop, error: shopErr } = await supabase
    .from("shops")
    .insert({ owner_id: userId, name: email ? `${email.split("@")[0]}'s Shop` : "My Shop" })
    .select()
    .single();
  if (shopErr) throw shopErr;

  const { error: memErr } = await supabase
    .from("shop_members")
    .insert({ shop_id: shop.id, user_id: userId, role: "owner" });
  if (memErr) throw memErr;

  await seedCatalogue(shop.id);
  return { shop: shop as unknown as Shop, role: "owner" as ShopRole };
}

export function ShopProvider({ children }: { children: ReactNode }) {
  const { user, loading: authLoading } = useAuth();
  const qc = useQueryClient();

  const { data, isLoading } = useQuery({
    queryKey: ["shop", user?.id],
    enabled: !!user,
    queryFn: () => loadOrCreateShop(user!.id, user!.email ?? undefined),
    staleTime: 60_000,
  });

  return (
    <ShopContext.Provider
      value={{
        shop: data?.shop ?? null,
        role: data?.role ?? null,
        loading: authLoading || isLoading,
        refresh: () => qc.invalidateQueries({ queryKey: ["shop"] }),
      }}
    >
      {children}
    </ShopContext.Provider>
  );
}

export function useShop() {
  return useContext(ShopContext);
}
