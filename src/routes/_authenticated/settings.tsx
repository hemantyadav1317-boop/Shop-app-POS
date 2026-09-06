import { createFileRoute } from "@tanstack/react-router";
import { useEffect, useState } from "react";
import { LogOut } from "lucide-react";
import { toast } from "sonner";
import { PosShell } from "@/components/pos/PosShell";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { ThemeToggle } from "@/components/pos/ThemeToggle";
import { useShop } from "@/lib/shop";
import { useAuth } from "@/lib/auth";
import { useShopMembers } from "@/lib/queries";
import { supabase } from "@/integrations/supabase/client";
import { signOutAndRedirect } from "@/lib/signout";

export const Route = createFileRoute("/_authenticated/settings")({
  head: () => ({
    meta: [
      { title: "Settings — Shop POS" },
      { name: "description", content: "Shop details, theme aur staff access yahan se manage karein." },
      { property: "og:title", content: "Settings — Shop POS" },
      { property: "og:description", content: "Shop details, theme aur staff access yahan se manage karein." },
    ],
  }),
  component: SettingsPage,
});

function SettingsPage() {
  const { shop, role, refresh } = useShop();
  const { user } = useAuth();
  const { data: members } = useShopMembers(shop?.id);
  const [form, setForm] = useState({ name: "", phone: "", address: "", currency: "Rs", bill_prefix: "" });
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    if (shop) {
      setForm({
        name: shop.name ?? "",
        phone: shop.phone ?? "",
        address: shop.address ?? "",
        currency: shop.currency ?? "Rs",
        bill_prefix: shop.bill_prefix ?? "",
      });
    }
  }, [shop]);

  const canEdit = role === "owner" || role === "manager";

  async function save() {
    if (!shop) return;
    setSaving(true);
    const { error } = await supabase
      .from("shops")
      .update({
        name: form.name.trim() || shop.name,
        phone: form.phone.trim() || null,
        address: form.address.trim() || null,
        currency: form.currency.trim() || "Rs",
        bill_prefix: form.bill_prefix.trim(),
      })
      .eq("id", shop.id);
    setSaving(false);
    if (error) {
      toast.error(error.message);
      return;
    }
    await refresh?.();
    toast.success("Shop details saved");
  }

  return (
    <PosShell title="Settings">
      <div className="h-full overflow-y-auto p-3">
        <section className="rounded-2xl bg-card p-4 shadow-[var(--shadow-tile)]">
          <h2 className="text-sm font-bold">Appearance</h2>
          <p className="mt-1 text-xs text-muted-foreground">Light, Dark ya device setting choose karein.</p>
          <div className="mt-3">
            <ThemeToggle />
          </div>
        </section>

        <section className="mt-3 rounded-2xl bg-card p-4 shadow-[var(--shadow-tile)]">
          <h2 className="text-sm font-bold">Shop details</h2>
          <div className="mt-3 grid gap-3 sm:grid-cols-2">
            <div>
              <Label htmlFor="sn">Shop name</Label>
              <Input
                id="sn"
                value={form.name}
                disabled={!canEdit}
                onChange={(e) => setForm({ ...form, name: e.target.value })}
              />
            </div>
            <div>
              <Label htmlFor="sp">Phone</Label>
              <Input
                id="sp"
                inputMode="tel"
                value={form.phone}
                disabled={!canEdit}
                onChange={(e) => setForm({ ...form, phone: e.target.value })}
              />
            </div>
            <div className="sm:col-span-2">
              <Label htmlFor="sa">Address</Label>
              <Input
                id="sa"
                value={form.address}
                disabled={!canEdit}
                onChange={(e) => setForm({ ...form, address: e.target.value })}
              />
            </div>
            <div>
              <Label htmlFor="sc">Currency symbol</Label>
              <Input
                id="sc"
                value={form.currency}
                disabled={!canEdit}
                onChange={(e) => setForm({ ...form, currency: e.target.value })}
              />
            </div>
            <div>
              <Label htmlFor="sb">Bill prefix</Label>
              <Input
                id="sb"
                value={form.bill_prefix}
                disabled={!canEdit}
                onChange={(e) => setForm({ ...form, bill_prefix: e.target.value })}
              />
            </div>
          </div>
          {canEdit && (
            <Button className="mt-3" disabled={saving} onClick={() => void save()}>
              {saving ? "Saving…" : "Save changes"}
            </Button>
          )}
        </section>

        <section className="mt-3 rounded-2xl bg-card p-4 shadow-[var(--shadow-tile)]">
          <h2 className="text-sm font-bold">Staff access</h2>
          <ul className="mt-3 space-y-2">
            {(members ?? []).map((m) => (
              <li
                key={m.id}
                className="grid grid-cols-[minmax(0,1fr)_auto] items-center gap-3 rounded-xl border border-border p-3"
              >
                <span className="truncate text-sm">{m.user_id === user?.id ? "You" : m.user_id}</span>
                <span className="shrink-0 text-xs font-semibold uppercase tracking-wide text-muted-foreground">
                  {m.role}
                </span>
              </li>
            ))}
            {!members?.length && (
              <p className="py-4 text-center text-sm text-muted-foreground">Koi staff member nahi hai.</p>
            )}
          </ul>
        </section>

        <section className="mt-3 rounded-2xl bg-card p-4 shadow-[var(--shadow-tile)]">
          <h2 className="text-sm font-bold">Account</h2>
          <p className="mt-1 truncate text-xs text-muted-foreground">{user?.email}</p>
          <Button variant="outline" className="mt-3" onClick={() => void signOutAndRedirect()}>
            <LogOut className="mr-1 h-4 w-4" /> Log out
          </Button>
        </section>
      </div>
    </PosShell>
  );
}
