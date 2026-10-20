import { describe, expect, test } from "vitest";
import { parseStockCsv } from "./bulk-stock";
describe("bulk stock csv", () => {
  test("reads name and quantity", () => { expect(parseStockCsv("name,quantity\nTomato,10")).toEqual([{ name: "Tomato", quantity: 10, category: undefined, unit: undefined, price: undefined, cost_price: undefined }]); });
  test("skips rows without a numeric quantity", () => { expect(parseStockCsv("name,qty\nApple,abc\nMango,2")).toHaveLength(1); });
  test("rejects files missing the quantity column", () => { expect(parseStockCsv("name,price\nApple,50")).toEqual([]); });
});
