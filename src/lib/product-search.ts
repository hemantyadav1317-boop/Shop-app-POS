type SearchProduct = { name: string; category?: string; name_en?: string | null; name_hi?: string | null; sku?: string | null; barcode?: string | null };
const aliases = [
  ["आलू", "potato aloo"], ["टमाटर", "tomato tamatar"], ["प्याज", "onion pyaz"],
  ["अदरक", "ginger adrak"], ["लहसुन", "garlic lahsun"], ["गाजर", "carrot gajar"],
  ["भिंडी", "okra ladyfinger bhindi"], ["बैंगन", "brinjal eggplant baingan"],
  ["लौकी", "bottle gourd lauki"], ["पालक", "spinach palak"], ["गोभी", "cauliflower cabbage gobhi"],
  ["धनिया", "coriander dhaniya"], ["पुदीना", "mint pudina"], ["मिर्च", "chilli mirchi"],
  ["नींबू", "lemon lime nimbu"], ["खीरा", "cucumber kheera"], ["करेला", "bitter gourd karela"],
  ["सेब", "apple seb"], ["केला", "banana kela"], ["आम", "mango aam"],
  ["अमरूद", "guava amrood"], ["अनार", "pomegranate anar"], ["अंगूर", "grapes angoor"],
  ["पपीता", "papaya papita"], ["संतरा", "orange santra"], ["तरबूज", "watermelon tarbooj"],
  ["चीकू", "sapota chikoo"], ["लीची", "lychee litchi"], ["नारियल", "coconut nariyal"],
  ["खरबूजा", "muskmelon kharbuja"], ["दूध", "milk doodh"], ["दही", "curd yogurt dahi"],
  ["पनीर", "paneer cheese"], ["आइस", "ice cream"],
];
const normalize = (value: string) => value.normalize("NFKC").toLowerCase().trim();
export function matchesProduct(product: SearchProduct, query: string): boolean {
  const term = normalize(query);
  if (!term) return true;
  const name = normalize([product.name, product.name_en, product.name_hi].filter(Boolean).join(" "));
  const extra = aliases.filter(([hi, en]) => (hi && name.includes(hi)) || (en && en.split(" ").some(word => name.includes(word)))).map(pair => pair.join(" ")).join(" ");
  const searchable = normalize([name, extra, product.category, product.sku, product.barcode].filter(Boolean).join(" "));
  return term.split(/\s+/).every(word => searchable.includes(word));
}