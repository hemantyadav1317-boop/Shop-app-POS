import { Button } from "@/components/ui/button";
import { Monitor, Moon, Sun } from "lucide-react";
import { useTheme, type ThemePref } from "@/lib/theme";

const OPTIONS: { value: ThemePref; icon: typeof Sun; label: string }[] = [
  { value: "light", icon: Sun, label: "Light" },
  { value: "dark", icon: Moon, label: "Dark" },
  { value: "system", icon: Monitor, label: "Device" },
];

export function ThemeToggle({ full = false }: { full?: boolean }) {
  const { theme, setTheme } = useTheme();

  return (
    <div
      className={`flex gap-1 rounded-lg border border-border bg-card p-1 ${full ? "w-full" : ""}`}
      role="group"
      aria-label="Appearance"
    >
      {OPTIONS.map((o) => (
        <Button variant="ghost"
          key={o.value}
          type="button"
          onClick={() => setTheme(o.value)}
          aria-pressed={theme === o.value}
          aria-label={o.label}
          title={o.label}
          className={`flex flex-1 items-center justify-center gap-1.5 rounded-lg px-2.5 h-10 py-2 text-xs font-medium transition-colors ${
            theme === o.value
              ? "bg-primary text-primary-foreground"
              : "text-muted-foreground hover:bg-muted"
          }`}
        >
          <o.icon className="h-4 w-4" />
          {full && <span>{o.label}</span>}
        </Button>
      ))}
    </div>
  );
}
