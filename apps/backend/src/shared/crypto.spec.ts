import { describe, expect, it } from "vitest";
import { decryptString, encryptString } from "./crypto.js";

describe("crypto", () => {
  it("round-trips", () => {
    const enc = encryptString("3520212345671", "key-1");
    expect(enc).not.toContain("3520212345671");
    expect(decryptString(enc, "key-1")).toBe("3520212345671");
  });

  it("produces different ciphertexts for the same input (random IV)", () => {
    expect(encryptString("same", "k")).not.toBe(encryptString("same", "k"));
  });

  it("fails with the wrong key or tampered data", () => {
    const enc = encryptString("secret", "right-key");
    expect(() => decryptString(enc, "wrong-key")).toThrow();
    expect(() => decryptString(enc.slice(0, -2) + "xx", "right-key")).toThrow();
  });
});
