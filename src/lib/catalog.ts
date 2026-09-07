export type CatalogItem = {
  name: string;
  category: string;
  unit: "kg" | "pc";
  price: number;
};

export const CATEGORY_ORDER = [
  "FRUITS 🍎",
  "VEGETABLES",
  "GREEN VEGGIES",
  "SALAD 🥗",
  "MASALA",
  "MIRCHI",
] as const;

/**
 * Shop ka asli catalogue (screenshots se). Naam exactly wahi rakhe gaye hain.
 * Duplicate se bachne ke liye `normalizeName` se compare hota hai.
 */
export const CATALOG: CatalogItem[] = [
  // FRUITS
  { name: "Apple Royal gala 🍎", category: "FRUITS 🍎", unit: "kg", price: 320 },
  { name: "Apple 🍎", category: "FRUITS 🍎", unit: "kg", price: 280 },
  { name: "Kivi", category: "FRUITS 🍎", unit: "pc", price: 160 },
  { name: "Lychee (लीची)", category: "FRUITS 🍎", unit: "kg", price: 280 },
  { name: "Pulm", category: "FRUITS 🍎", unit: "kg", price: 240 },
  { name: "VT Dates", category: "FRUITS 🍎", unit: "kg", price: 50 },

  // VEGETABLES
  { name: "Brokli", category: "VEGETABLES", unit: "kg", price: 200 },
  { name: "Parval", category: "VEGETABLES", unit: "kg", price: 120 },
  { name: "अरबी (Arabi)", category: "VEGETABLES", unit: "kg", price: 80 },
  { name: "आलू", category: "VEGETABLES", unit: "kg", price: 25 },
  { name: "आलू लाल", category: "VEGETABLES", unit: "kg", price: 40 },
  { name: "कयोड़ा", category: "VEGETABLES", unit: "kg", price: 240 },
  { name: "कटहल", category: "VEGETABLES", unit: "pc", price: 60 },
  { name: "कद्दू", category: "VEGETABLES", unit: "kg", price: 60 },
  { name: "करेला", category: "VEGETABLES", unit: "kg", price: 140 },
  { name: "कांदा", category: "VEGETABLES", unit: "kg", price: 30 },
  { name: "काचरी", category: "VEGETABLES", unit: "kg", price: 100 },
  { name: "कुन्दरु", category: "VEGETABLES", unit: "kg", price: 80 },
  { name: "केरी", category: "VEGETABLES", unit: "kg", price: 200 },
  { name: "केरूजा", category: "VEGETABLES", unit: "kg", price: 120 },
  { name: "गाजर Red", category: "VEGETABLES", unit: "kg", price: 50 },
  { name: "गिलकी त्योरी", category: "VEGETABLES", unit: "kg", price: 120 },
  { name: "ग्वार फली", category: "VEGETABLES", unit: "kg", price: 200 },
  { name: "चोला फली", category: "VEGETABLES", unit: "kg", price: 140 },
  { name: "टमाटर Hybrid tomato 🍅", category: "VEGETABLES", unit: "kg", price: 70 },
  { name: "टमाटर 🍅", category: "VEGETABLES", unit: "kg", price: 60 },
  { name: "टिण्डा (desi)", category: "VEGETABLES", unit: "kg", price: 200 },
  { name: "टिण्डा चप्पन", category: "VEGETABLES", unit: "kg", price: 80 },
  { name: "तुरई देशी", category: "VEGETABLES", unit: "kg", price: 180 },
  { name: "पत्ता गोभी 🥬", category: "VEGETABLES", unit: "kg", price: 70 },
  { name: "फुल गोभी", category: "VEGETABLES", unit: "kg", price: 140 },
  { name: "बिन्स (Beans)", category: "VEGETABLES", unit: "kg", price: 250 },
  { name: "बैंगन काले", category: "VEGETABLES", unit: "kg", price: 60 },
  { name: "बैंगन देशी (Baingan)", category: "VEGETABLES", unit: "kg", price: 140 },
  { name: "भरता बैंगन", category: "VEGETABLES", unit: "kg", price: 120 },
  { name: "भिण्डी", category: "VEGETABLES", unit: "kg", price: 80 },
  { name: "मटर pencil", category: "VEGETABLES", unit: "kg", price: 180 },
  { name: "मशरूम", category: "VEGETABLES", unit: "pc", price: 80 },
  { name: "लोकी", category: "VEGETABLES", unit: "kg", price: 60 },
  { name: "शीगरी", category: "VEGETABLES", unit: "kg", price: 80 },
  { name: "सेम फली", category: "VEGETABLES", unit: "kg", price: 100 },
  { name: "हल्दी", category: "VEGETABLES", unit: "kg", price: 160 },

  // GREEN VEGGIES
  { name: "धनिया (coriander) 🌿", category: "GREEN VEGGIES", unit: "kg", price: 300 },
  { name: "पालक", category: "GREEN VEGGIES", unit: "kg", price: 100 },
  { name: "पुदीना", category: "GREEN VEGGIES", unit: "kg", price: 150 },
  { name: "बथुआ Bunch", category: "GREEN VEGGIES", unit: "kg", price: 80 },
  { name: "मूली (radish)", category: "GREEN VEGGIES", unit: "kg", price: 80 },
  { name: "मैथी Bunch", category: "GREEN VEGGIES", unit: "kg", price: 80 },
  { name: "सरसो", category: "GREEN VEGGIES", unit: "pc", price: 40 },
  { name: "हरी प्याज (spring Onion)", category: "GREEN VEGGIES", unit: "kg", price: 200 },
  { name: "हरी लहसुन", category: "GREEN VEGGIES", unit: "kg", price: 200 },

  // SALAD
  { name: "ककडी", category: "SALAD 🥗", unit: "kg", price: 100 },
  { name: "खीरा Desi 🥒", category: "SALAD 🥗", unit: "kg", price: 60 },
  { name: "खीरा English 🥒", category: "SALAD 🥗", unit: "kg", price: 70 },
  { name: "गाजर पहाडी", category: "SALAD 🥗", unit: "kg", price: 120 },
  { name: "चुकन्दर (beetroot)", category: "SALAD 🥗", unit: "kg", price: 80 },
  { name: "सकरकन्दी", category: "SALAD 🥗", unit: "kg", price: 100 },
  { name: "सफेद प्याज", category: "SALAD 🥗", unit: "kg", price: 30 },

  // MASALA
  { name: "अदरक (Ginger)", category: "MASALA", unit: "kg", price: 400 },
  { name: "कॉपी", category: "MASALA", unit: "pc", price: 140 },
  { name: "छुला लहसुन", category: "MASALA", unit: "kg", price: 400 },
  { name: "नींबू (lemon) 🍋", category: "MASALA", unit: "kg", price: 250 },
  { name: "प्याज (onion) 🧅", category: "MASALA", unit: "kg", price: 80 },
  { name: "लहसुन 🧄", category: "MASALA", unit: "kg", price: 350 },

  // MIRCHI
  { name: "Moti mirchi lal", category: "MIRCHI", unit: "kg", price: 200 },
  { name: "मिर्ची Normal 🌶️", category: "MIRCHI", unit: "kg", price: 100 },
  { name: "मिर्ची 🌶️ तीखी", category: "MIRCHI", unit: "kg", price: 200 },
  { name: "मोटी मिर्ची", category: "MIRCHI", unit: "kg", price: 150 },
  { name: "मोटी मिर्ची लाल 🌶️", category: "MIRCHI", unit: "kg", price: 150 },
  { name: "लाल - पीली शिमला (Bell papers)", category: "MIRCHI", unit: "kg", price: 200 },
  { name: "शिमला Green", category: "MIRCHI", unit: "kg", price: 120 },
];

/** Emoji, spaces aur case hata kar naam compare karta hai (duplicate check). */
export function normalizeName(name: string) {
  return name
    .toLowerCase()
    .replace(/[^\p{L}\p{N}]+/gu, "")
    .trim();
}
