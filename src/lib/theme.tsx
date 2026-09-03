import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from "react";

export type ThemePref = "light" | "dark" | "system";

type Ctx = {
  theme: ThemePref;
  resolved: "light" | "dark";
  setTheme: (t: ThemePref) => void;
};

const ThemeContext = createContext<Ctx | null>(null);
const KEY = "pos.theme";

function systemDark() {
  if (typeof window === "undefined") return false;
  return window.matchMedia("(prefers-color-scheme: dark)").matches;
}

export function ThemeProvider({ children }: { children: ReactNode }) {
  const [theme, setThemeState] = useState<ThemePref>("system");
  const [resolved, setResolved] = useState<"light" | "dark">("light");

  const apply = useCallback((pref: ThemePref) => {
    const dark = pref === "dark" || (pref === "system" && systemDark());
    document.documentElement.classList.toggle("dark", dark);
    document.documentElement.style.colorScheme = dark ? "dark" : "light";
    setResolved(dark ? "dark" : "light");
  }, []);

  useEffect(() => {
    const stored = (localStorage.getItem(KEY) as ThemePref | null) ?? "system";
    setThemeState(stored);
    apply(stored);
  }, [apply]);

  useEffect(() => {
    if (theme !== "system") return;
    const mql = window.matchMedia("(prefers-color-scheme: dark)");
    const onChange = () => apply("system");
    mql.addEventListener("change", onChange);
    return () => mql.removeEventListener("change", onChange);
  }, [theme, apply]);

  const setTheme = useCallback(
    (t: ThemePref) => {
      setThemeState(t);
      localStorage.setItem(KEY, t);
      apply(t);
    },
    [apply],
  );

  const value = useMemo(() => ({ theme, resolved, setTheme }), [theme, resolved, setTheme]);
  return <ThemeContext.Provider value={value}>{children}</ThemeContext.Provider>;
}

export function useTheme() {
  const ctx = useContext(ThemeContext);
  if (!ctx) throw new Error("useTheme must be used inside ThemeProvider");
  return ctx;
}
