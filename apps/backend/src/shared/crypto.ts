import { createCipheriv, createDecipheriv, createHash, randomBytes } from "node:crypto";

// AES-256-GCM for PII at rest (CNIC). Output: base64url(iv).(tag).(ciphertext).
// Key is derived from the configured passphrase; rotating it requires re-encrypting rows.

function deriveKey(passphrase: string): Buffer {
  return createHash("sha256").update(passphrase).digest();
}

export function encryptString(plain: string, passphrase: string): string {
  const iv = randomBytes(12);
  const cipher = createCipheriv("aes-256-gcm", deriveKey(passphrase), iv);
  const enc = Buffer.concat([cipher.update(plain, "utf8"), cipher.final()]);
  const tag = cipher.getAuthTag();
  return [iv, tag, enc].map((b) => b.toString("base64url")).join(".");
}

export function decryptString(encoded: string, passphrase: string): string {
  const [iv, tag, enc] = encoded.split(".").map((p) => Buffer.from(p ?? "", "base64url"));
  if (!iv || !tag || !enc) throw new Error("malformed ciphertext");
  const decipher = createDecipheriv("aes-256-gcm", deriveKey(passphrase), iv);
  decipher.setAuthTag(tag);
  return Buffer.concat([decipher.update(enc), decipher.final()]).toString("utf8");
}
