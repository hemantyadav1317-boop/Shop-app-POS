import { createContext, useContext, type ReactNode } from "react";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { supabase } from "@/integrations/supabase/client";
import { useAuth } from "./auth";
import { CATALOG } from "./catalog";

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
  upi_id?: string | null;
  upi_payee_name?: string | null;
};

type Ctx = {
  shop: Shop | null;
  role: ShopRole | null;
  loading: boolean;
  refresh: () => void;
};

const ShopContext = createContext<Ctx>({ shop: null, role: null, loading: true, refresh: () => {} });

async function seedCatalogue(shopId: string) {
  const { count } = await supabase
    .from("products")
    .select("id", { count: "exact", head: true })
    .eq("shop_id", shopId);
  if (count && count > 0) return;

  const rows = CATALOG.map((p) => ({
    shop_id: shopId,
    name: p.name,
    category: p.category,
    unit: p.unit,
    price: p.price,
    stock: 0,
    low_stock_at: 5,
  }));
  const { error } = await supabase.from("products").insert(rows);
  if (error) console.error("catalogue seed failed", error);
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
    const shop = existing.shops as unknown as Shop;
    await seedCatalogue(shop.id);
    return { shop, role: existing.role as ShopRole };
  }


  // The shop row is only readable once a membership row exists, so we generate
  // the id up front and insert without asking for the row back.
  const shopId = crypto.randomUUID();
  const { error: shopErr } = await supabase
    .from("shops")
    .insert({ id: shopId, owner_id: userId, name: email ? `${email.split("@")[0]}'s Shop` : "My Shop" });
  if (shopErr) throw shopErr;

  const { error: memErr } = await supabase
    .from("shop_members")
    .insert({ shop_id: shopId, user_id: userId, role: "owner" });
  if (memErr) throw memErr;

  const { data: shop, error: readErr } = await supabase
    .from("shops")
    .select("*")
    .eq("id", shopId)
    .single();
  if (readErr) throw readErr;

  await seedCatalogue(shopId);
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
