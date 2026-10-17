export function canSellStock(stock: number, quantity: number, allowNegative = false): boolean {
  return Number.isFinite(quantity) && quantity > 0 && Number.isFinite(stock) && (allowNegative || quantity <= stock);
}