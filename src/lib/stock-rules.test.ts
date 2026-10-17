import { describe, expect, test } from "bun:test";
import { canSellStock } from "./stock-rules";
import { matchesProduct } from "./product-search";
describe("Inventory sale rules", () => {
  test("negative stock is blocked by default", () => { expect(canSellStock(0, 1)).toBe(false); });
  test("an explicit opt-in permits negative stock", () => { expect(canSellStock(0, 1, true)).toBe(true); });
  test("decimal quantities respect available stock", () => { expect(canSellStock(0.5, 0.5)).toBe(true); expect(canSellStock(0.5, 0.501)).toBe(false); });
  test("old negative stock cannot be sold further without opt-in", () => { expect(canSellStock(-2, 0.25)).toBe(false); });
  test("invalid quantities cannot be sold", () => { expect(canSellStock(10, -1, true)).toBe(false); expect(canSellStock(10, NaN, true)).toBe(false); });
});
describe("Product search", () => {
  test("English partial search matches Hindi products", () => { expect(matchesProduct({name: "टमाटर"}, "tomat")).toBe(true); expect(matchesProduct({name: "आलू"}, "tomat")).toBe(false); });
  test("Hindi partial search works", () => { expect(matchesProduct({name: "टमाटर"}, "टमा")).toBe(true); });
  test("SKU and barcode match actual product fields", () => { expect(matchesProduct({name:"Milk", sku:"DAIRY-12", barcode:"8901234567890"}, "dairy-12")).toBe(true); expect(matchesProduct({name:"Milk", barcode:"8901234567890"}, "8901234567890")).toBe(true); expect(matchesProduct({name:"Milk"}, "8901234567890")).toBe(false); });
});