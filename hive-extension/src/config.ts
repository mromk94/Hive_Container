// Origin allowlist (dev)
export const ALLOWLIST: string[] = [
  "file://",
  "http://localhost",
  "https://localhost",
  // Provider and common sites
  "https://chatgpt.com",
  "https://claude.ai",
  "https://x.ai",
  "https://gemini.google.com",
  "https://deepseek.com"
];

export function isAllowedOrigin(origin?: string | null): boolean {
  if (!origin) return false;
  for (const pat of ALLOWLIST) {
    if (pat.endsWith("*")) {
      const prefix = pat.slice(0, -1);
      if (origin.startsWith(prefix)) return true;
    } else {
      if (origin === pat || origin.startsWith(pat + ":") || origin.startsWith(pat + "/")) return true;
    }
  }
  return false;
}
