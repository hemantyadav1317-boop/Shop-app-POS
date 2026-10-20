import { toast } from "sonner";

/** Distinct synthesized sounds per action. No audio files needed; works offline. */
export type SoundKind = "tap" | "add" | "remove" | "sale" | "success" | "error" | "warning" | "print" | "share" | "nav" | "import";

type Note = [freq: number, startMs: number, durMs: number, type?: OscillatorType];

const SOUNDS: Record<SoundKind, Note[]> = {
  tap: [[880, 0, 35, "triangle"]],
  nav: [[660, 0, 50, "sine"], [990, 45, 50, "sine"]],
  add: [[740, 0, 70, "triangle"], [1110, 60, 90, "triangle"]],
  remove: [[520, 0, 70, "triangle"], [330, 60, 110, "triangle"]],
  sale: [[523, 0, 110, "sine"], [659, 100, 110, "sine"], [784, 200, 110, "sine"], [1047, 300, 260, "sine"]],
  success: [[784, 0, 90, "sine"], [1175, 80, 160, "sine"]],
  error: [[220, 0, 160, "square"], [180, 150, 220, "square"]],
  warning: [[440, 0, 120, "sawtooth"], [440, 180, 120, "sawtooth"]],
  print: [[1200, 0, 25, "square"], [1200, 60, 25, "square"], [1200, 120, 25, "square"], [900, 180, 80, "triangle"]],
  share: [[600, 0, 60, "sine"], [900, 50, 60, "sine"], [1350, 100, 120, "sine"]],
  import: [[392, 0, 90, "triangle"], [523, 90, 90, "triangle"], [659, 180, 90, "triangle"], [784, 270, 180, "triangle"]],
};

const KEY = "pos.sound";
let ctx: AudioContext | null = null;

export function soundEnabled() {
  if (typeof window === "undefined") return false;
  return localStorage.getItem(KEY) !== "off";
}
export function setSoundEnabled(on: boolean) {
  localStorage.setItem(KEY, on ? "on" : "off");
}

export function playSound(kind: SoundKind) {
  if (!soundEnabled()) return;
  try {
    ctx ??= new AudioContext();
    if (ctx.state === "suspended") void ctx.resume();
    const now = ctx.currentTime;
    for (const [freq, start, dur, type = "sine"] of SOUNDS[kind]) {
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = type;
      osc.frequency.value = freq;
      const t0 = now + start / 1000;
      const t1 = t0 + dur / 1000;
      const vol = type === "square" || type === "sawtooth" ? 0.06 : 0.15;
      gain.gain.setValueAtTime(0.0001, t0);
      gain.gain.exponentialRampToValueAtTime(vol, t0 + 0.01);
      gain.gain.exponentialRampToValueAtTime(0.0001, t1);
      osc.connect(gain).connect(ctx.destination);
      osc.start(t0);
      osc.stop(t1 + 0.02);
    }
  } catch {
    /* audio not available */
  }
}

let installed = false;
/** Hooks toasts and button taps so every action gets a sound. */
export function installGlobalSounds() {
  if (installed || typeof window === "undefined") return;
  installed = true;
  const t = toast as unknown as Record<string, (...a: unknown[]) => unknown>;
  const wrap = (name: string, kind: SoundKind) => {
    const orig = t[name];
    t[name] = (...a: unknown[]) => { playSound(kind); return orig?.(...a); };
  };
  wrap("success", "success");
  wrap("error", "error");
  wrap("warning", "warning");
  wrap("info", "nav");
  document.addEventListener("click", (e) => {
    const el = (e.target as HTMLElement | null)?.closest("button, a, [role=button]") as HTMLElement | null;
    if (!el || el.dataset["sound"] === "none") return;
    const kind = (el.dataset["sound"] as SoundKind | undefined) ?? (el.tagName === "A" ? "nav" : "tap");
    playSound(kind);
  }, { capture: true });
}
