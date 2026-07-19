// Pakistani mobile numbers only for launch: 03XX-XXXXXXX or +923XX-XXXXXXX.
// Normalised storage format is E.164 (+923001234567).
const PK_MOBILE = /^(?:\+92|0092|92|0)(3\d{9})$/;

export function normalizePkPhone(raw: string): string | null {
  const cleaned = raw.replace(/[\s()-]/g, "");
  const match = PK_MOBILE.exec(cleaned);
  if (!match) return null;
  return `+92${match[1]}`;
}
