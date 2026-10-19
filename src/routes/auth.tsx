import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { useEffect } from "react";
import { LogIn, Store } from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { useAuth } from "@/lib/auth";
import { lovable } from "@/integrations/lovable/index";

export const Route = createFileRoute("/auth")({
  head: () => ({
    meta: [
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
      { title: "Login — Shop POS" },
      { name: "description", content: "Apne shop account me Google se secure login karein." },
      { property: "og:title", content: "Login — Shop POS" },
      { property: "og:description", content: "Apne shop account me Google se secure login karein." },
    ],
  }),
  component: AuthPage,
});

function AuthPage() {
  const { user, loading } = useAuth();
  const navigate = useNavigate();

  useEffect(() => {
    if (user) void navigate({ to: "/pos" });
  }, [user, navigate]);

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

  return (
    <div className="grid min-h-dvh place-items-center bg-background px-4">
      <div className="w-full max-w-sm rounded-3xl border border-border bg-card p-6 text-center shadow-[var(--shadow-panel)]">
        <div className="mx-auto grid h-16 w-16 place-items-center rounded-3xl bg-primary text-primary-foreground">
          <Store className="h-8 w-8" />
        </div>
        <h1 className="mt-4 text-xl font-black">Shop POS</h1>
        <p className="mt-1 text-sm text-muted-foreground">
          Billing, stock aur khata — ek hi app me.
        </p>
        <Button
          className="mt-6 h-12 w-full text-base font-bold"
          disabled={loading}
          onClick={() => void googleLogin()}
        >
          <LogIn className="mr-2 h-5 w-5" /> Continue with Google
        </Button>
      </div>
    </div>
  );
}
