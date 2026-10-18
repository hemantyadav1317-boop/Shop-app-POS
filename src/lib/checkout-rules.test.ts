import { describe, expect, test } from "vitest";
import { paymentAmount, savedOrderTotal } from "./checkout-rules";
import { paymentStatus, upiUri } from "./bill-image";
import type { ReceiptData } from "./receipt";

const bill: ReceiptData = { shopName: "Yadav Store", billNo: 42, date: "2026-10-18", lines: [{ name: "Tomato", qty: 0.5, unit: "kg", price: 60 }], subTotal: 30, discount: 0, total: 30, paid: 0, due: 30, paymentMode: "online", upiId: "shop@upi", upiName: "Hemant Yadav" };
describe("Saved bill and payment rules", () => {
  test("cash received cannot exceed the saved total", () => expect(paymentAmount(100, 30)).toBe(30));
  test("negative and non-finite payments are rejected", () => { expect(() => paymentAmount(-1, 30)).toThrow(); expect(() => paymentAmount(NaN, 30)).toThrow(); });
  test("saved decimal quantities and discount keep the payable amount", () => expect(savedOrderTotal(bill.lines, 5)).toBe(25));
  test("online QR uses the outstanding amount and stays pending", () => { const uri = upiUri(bill); expect(uri).toBeTruthy(); const params = new URL(uri ?? "").searchParams; expect(params.get("am")).toBe("30.00"); expect(params.get("pa")).toBe("shop@upi"); expect(params.get("pn")).toBe("Hemant Yadav"); expect(paymentStatus(bill)).toBe("PAYMENT PENDING"); });
  test("split QR uses only the unpaid remainder", () => { const split = { ...bill, paymentMode: "split", paid: 10, due: 20 }; expect(new URL(upiUri(split) ?? "").searchParams.get("am")).toBe("20.00"); expect(paymentStatus(split)).toBe("PARTLY PAID — PENDING"); });
  test("credit stays due until payment confirmation", () => expect(paymentStatus({ ...bill, paymentMode: "credit" })).toBe("CREDIT (DUE)"));
  test("paid bills have no payment QR", () => { const paid = { ...bill, paid: 30, due: 0 }; expect(upiUri(paid)).toBeNull(); expect(paymentStatus(paid)).toBe("PAID"); });
});