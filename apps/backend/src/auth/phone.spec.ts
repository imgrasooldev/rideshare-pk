import { describe, expect, it } from "vitest";
import { normalizePkPhone } from "./phone.js";

describe("normalizePkPhone", () => {
  it.each([
    ["03001234567", "+923001234567"],
    ["+923001234567", "+923001234567"],
    ["923001234567", "+923001234567"],
    ["00923001234567", "+923001234567"],
    ["0300-1234567", "+923001234567"],
    ["0300 123 4567", "+923001234567"]
  ])("normalises %s to %s", (input, expected) => {
    expect(normalizePkPhone(input)).toBe(expected);
  });

  it.each([
    "1234",
    "042111222333",      // landline
    "+13001234567",      // wrong country
    "030012345678",      // too long
    "0300123456",        // too short
    "03oo1234567"        // letters
  ])("rejects %s", (input) => {
    expect(normalizePkPhone(input)).toBeNull();
  });
});
