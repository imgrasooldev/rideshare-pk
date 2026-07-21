"use client";

import { useEffect, useState } from "react";
import { Moon, Sun } from "lucide-react";

/** Toggles <html class="dark"> and persists the choice. */
export function ThemeToggle() {
  const [dark, setDark] = useState(false);

  useEffect(() => {
    setDark(document.documentElement.classList.contains("dark"));
  }, []);

  const toggle = () => {
    const next = !document.documentElement.classList.contains("dark");
    document.documentElement.classList.toggle("dark", next);
    try {
      localStorage.setItem("admin-theme", next ? "dark" : "light");
    } catch {
      /* ignore */
    }
    setDark(next);
  };

  return (
    <button
      onClick={toggle}
      aria-label="Toggle theme"
      title={dark ? "Switch to light" : "Switch to dark"}
      className="grid h-9 w-9 place-items-center rounded-xl border border-slate-200 bg-white text-slate-500 transition hover:text-slate-900 dark:border-white/10 dark:bg-white/[0.04] dark:text-slate-400 dark:hover:text-white"
    >
      {dark ? <Sun size={16} /> : <Moon size={16} />}
    </button>
  );
}
