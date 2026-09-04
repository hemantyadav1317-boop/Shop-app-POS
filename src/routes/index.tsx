import { createFileRoute, Link, useNavigate } from "@tanstack/react-router";
import { useEffect } from "react";
import { Download, LogIn, Smartphone, Store } from "lucide-react";
import { Button } from "@/components/ui/button";
import { useAuth } from "@/lib/auth";
import { useInstallPrompt } from "@/lib/pwa";
import { ThemeToggle } from "@/components/pos/ThemeToggle";
import { toast } from "sonner";
import { lovable } from "@/integrations/lovable/index";

export const Route = createFileRoute("/")({
  head: () => ({
    meta: [
      { title: "Shop POS — Billing, stock & khata for your shop" },
      {
        name: "description",
        content:
          "Install the Shop POS app for fast billing, inventory, customer credit and reports on Android phone or tablet.",
      },
      { property: "og:title", content: "Shop POS — Billing, stock & khata for your shop" },
      {
        property: "og:description",
        content:
          "Install the Shop POS app for fast billing, inventory, customer credit and reports on Android phone or tablet.",
      },
    ],
  }),
  component: Landing,
});

function Landing() {
  const { user, loading } = useAuth();
  const navigate = useNavigate();
  const { canInstall, installed, install } = useInstallPrompt();

  useEffect(() => {
    if (installed && user) void navigate({ to: "/pos" });
  }, [installed, user, navigate]);

  async function googleLogin() {
    const result = await lovable.auth.signInWithOAuth("google", {
      redirect_uri: window.location.origin,
    });
    if (result.error) {
      toast.error("Google login failed. Dobara try karein.");
      return;
    }
    if (result.redirected) return;
    void navigate({ to: "/pos" });
  }

  async function onInstall() {
    const outcome = await install();
    if (outcome === "unavailable") {
      toast.info("Browser menu → 'Add to Home screen' se app install karein.");
    }
  }

  return (
    <div className="min-h-dvh bg-background">
      <header className="mx-auto flex max-w-5xl items-center justify-between gap-3 px-4 py-4">
        <div className="flex items-center gap-2">
          <div className="grid h-10 w-10 place-items-center rounded-2xl bg-primary text-primary-foreground">
            <Store className="h-5 w-5" />
          </div>
          <span className="text-base font-black">Shop POS</span>
        </div>
        <ThemeToggle />
      </header>

      <main className="mx-auto max-w-5xl px-4 pb-16">
        <section className="pt-6 sm:pt-14">
          <h1 className="text-3xl font-black leading-tight sm:text-5xl">
            Your Shop. Your Billing.
            <br />
            <span className="text-primary">Your Complete Business System.</span>
          </h1>
          <p className="mt-4 max-w-xl text-sm text-muted-foreground sm:text-base">
            Fast POS billing, stock, customer khata, purchases, expenses aur reports — Android phone
            aur tablet dono par.
          </p>

          <div className="mt-7 flex flex-col gap-3 sm:flex-row">
            {user ? (
              <Button asChild className="h-12 text-base font-bold sm:w-52">
                <Link to="/pos">Open POS</Link>
              </Button>
            ) : (
              <Button
                className="h-12 text-base font-bold sm:w-56"
                disabled={loading}
                onClick={() => void googleLogin()}
              >
                <LogIn className="mr-2 h-5 w-5" /> Continue with Google
              </Button>
            )}

            {!installed && (
              <Button
                variant="outline"
                className="h-12 text-base font-semibold sm:w-52"
                onClick={() => void onInstall()}
              >
                <Download className="mr-2 h-5 w-5" />
                {canInstall ? "Install POS App" : "Add to Home screen"}
              </Button>
            )}

            {installed && user === null && (
              <Button variant="outline" asChild className="h-12 sm:w-40">
                <Link to="/auth">Login</Link>
              </Button>
            )}
          </div>
        </section>

        <section className="mt-12 grid gap-3 sm:grid-cols-3">
          {[
            { icon: Smartphone, t: "Phone + Tablet", d: "Dono ke liye alag optimised layout." },
            { icon: Store, t: "Poora shop system", d: "Stock, khata, purchase, expense, reports." },
            { icon: Download, t: "Installable app", d: "Home screen se app jaisa khulta hai." },
          ].map((f) => (
            <div key={f.t} className="rounded-2xl border border-border bg-card p-4">
              <f.icon className="h-5 w-5 text-primary" />
              <p className="mt-2 text-sm font-bold">{f.t}</p>
              <p className="text-xs text-muted-foreground">{f.d}</p>
            </div>
          ))}
        </section>
      </main>
    </div>
  );
}
