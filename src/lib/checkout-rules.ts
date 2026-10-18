export function paymentAmount(paid: number, total: number) {
  if (!Number.isFinite(paid) || !Number.isFinite(total) || paid < 0 || total < 0) {
    throw new Error("Enter a valid payment amount");
  }
  return Math.min(paid, total);
}

export function savedOrderTotal(lines: { price: number; qty: number }[], discount = 0) {
  return Math.max(0, +(lines.reduce((sum, line) => sum + line.price * line.qty, 0) - discount).toFixed(2));
}