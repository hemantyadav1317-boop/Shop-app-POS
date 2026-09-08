export type CatalogItem = {
  name: string;
  category: string;
  unit: "kg" | "pc";
  price: number;
  /** Cartoon-style icon shown on the POS tile */
  icon: string;
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
 * Shop ka asli catalogue. Naam exactly wahi rakhe gaye hain.
 * Duplicate se bachne ke liye `normalizeName` se compare hota hai.
 */
export const CATALOG: CatalogItem[] = [
  // FRUITS
  { name: "Apple Royal gala 🍎", category: "FRUITS 🍎", unit: "kg", price: 320, icon: "🍎" },
  { name: "Apple 🍎", category: "FRUITS 🍎", unit: "kg", price: 280, icon: "🍏" },
  { name: "Kivi", category: "FRUITS 🍎", unit: "pc", price: 160, icon: "🥝" },
  { name: "Lychee (लीची)", category: "FRUITS 🍎", unit: "kg", price: 280, icon: "🍒" },
  { name: "Pulm", category: "FRUITS 🍎", unit: "kg", price: 240, icon: "🍑" },
  { name: "VT Dates", category: "FRUITS 🍎", unit: "kg", price: 50, icon: "🌴" },

  // VEGETABLES
  { name: "Brokli", category: "VEGETABLES", unit: "kg", price: 200, icon: "🥦" },
  { name: "Parval", category: "VEGETABLES", unit: "kg", price: 120, icon: "🥒" },
  { name: "अरबी (Arabi)", category: "VEGETABLES", unit: "kg", price: 80, icon: "🥔" },
  { name: "आलू", category: "VEGETABLES", unit: "kg", price: 25, icon: "🥔" },
  { name: "आलू लाल", category: "VEGETABLES", unit: "kg", price: 40, icon: "🍠" },
  { name: "कयोड़ा", category: "VEGETABLES", unit: "kg", price: 240, icon: "🥬" },
  { name: "कटहल", category: "VEGETABLES", unit: "pc", price: 60, icon: "🍈" },
  { name: "कद्दू", category: "VEGETABLES", unit: "kg", price: 60, icon: "🎃" },
  { name: "करेला", category: "VEGETABLES", unit: "kg", price: 140, icon: "🥒" },
  { name: "कांदा", category: "VEGETABLES", unit: "kg", price: 30, icon: "🧅" },
  { name: "काचरी", category: "VEGETABLES", unit: "kg", price: 100, icon: "🥭" },
  { name: "कुन्दरु", category: "VEGETABLES", unit: "kg", price: 80, icon: "🥒" },
  { name: "केरी", category: "VEGETABLES", unit: "kg", price: 200, icon: "🥭" },
  { name: "केरूजा", category: "VEGETABLES", unit: "kg", price: 120, icon: "🥬" },
  { name: "गाजर Red", category: "VEGETABLES", unit: "kg", price: 50, icon: "🥕" },
  { name: "गिलकी त्योरी", category: "VEGETABLES", unit: "kg", price: 120, icon: "🥒" },
  { name: "ग्वार फली", category: "VEGETABLES", unit: "kg", price: 200, icon: "🫛" },
  { name: "चोला फली", category: "VEGETABLES", unit: "kg", price: 140, icon: "🫛" },
  { name: "टमाटर Hybrid tomato 🍅", category: "VEGETABLES", unit: "kg", price: 70, icon: "🍅" },
  { name: "टमाटर 🍅", category: "VEGETABLES", unit: "kg", price: 60, icon: "🍅" },
  { name: "टिण्डा (desi)", category: "VEGETABLES", unit: "kg", price: 200, icon: "🥎" },
  { name: "टिण्डा चप्पन", category: "VEGETABLES", unit: "kg", price: 80, icon: "🥎" },
  { name: "तुरई देशी", category: "VEGETABLES", unit: "kg", price: 180, icon: "🥒" },
  { name: "पत्ता गोभी 🥬", category: "VEGETABLES", unit: "kg", price: 70, icon: "🥬" },
  { name: "फुल गोभी", category: "VEGETABLES", unit: "kg", price: 140, icon: "🥦" },
  { name: "बिन्स (Beans)", category: "VEGETABLES", unit: "kg", price: 250, icon: "🫛" },
  { name: "बैंगन काले", category: "VEGETABLES", unit: "kg", price: 60, icon: "🍆" },
  { name: "बैंगन देशी (Baingan)", category: "VEGETABLES", unit: "kg", price: 140, icon: "🍆" },
  { name: "भरता बैंगन", category: "VEGETABLES", unit: "kg", price: 120, icon: "🍆" },
  { name: "भिण्डी", category: "VEGETABLES", unit: "kg", price: 80, icon: "🌿" },
  { name: "मटर pencil", category: "VEGETABLES", unit: "kg", price: 180, icon: "🫛" },
  { name: "मशरूम", category: "VEGETABLES", unit: "pc", price: 80, icon: "🍄" },
  { name: "लोकी", category: "VEGETABLES", unit: "kg", price: 60, icon: "🥒" },
  { name: "शीगरी", category: "VEGETABLES", unit: "kg", price: 80, icon: "🌿" },
  { name: "सेम फली", category: "VEGETABLES", unit: "kg", price: 100, icon: "🫛" },
  { name: "हल्दी", category: "VEGETABLES", unit: "kg", price: 160, icon: "🫚" },

  // GREEN VEGGIES
  { name: "धनिया (coriander) 🌿", category: "GREEN VEGGIES", unit: "kg", price: 300, icon: "🌿" },
  { name: "पालक", category: "GREEN VEGGIES", unit: "kg", price: 100, icon: "🥬" },
  { name: "पुदीना", category: "GREEN VEGGIES", unit: "kg", price: 150, icon: "🌱" },
  { name: "बथुआ Bunch", category: "GREEN VEGGIES", unit: "kg", price: 80, icon: "🌿" },
  { name: "मूली (radish)", category: "GREEN VEGGIES", unit: "kg", price: 80, icon: "🥬" },
  { name: "मैथी Bunch", category: "GREEN VEGGIES", unit: "kg", price: 80, icon: "🌿" },
  { name: "सरसो", category: "GREEN VEGGIES", unit: "pc", price: 40, icon: "🌼" },
  { name: "हरी प्याज (spring Onion)", category: "GREEN VEGGIES", unit: "kg", price: 200, icon: "🧅" },
  { name: "हरी लहसुन", category: "GREEN VEGGIES", unit: "kg", price: 200, icon: "🧄" },

  // SALAD
  { name: "ककडी", category: "SALAD 🥗", unit: "kg", price: 100, icon: "🥒" },
  { name: "खीरा Desi 🥒", category: "SALAD 🥗", unit: "kg", price: 60, icon: "🥒" },
  { name: "खीरा English 🥒", category: "SALAD 🥗", unit: "kg", price: 70, icon: "🥒" },
  { name: "गाजर पहाडी", category: "SALAD 🥗", unit: "kg", price: 120, icon: "🥕" },
  { name: "चुकन्दर (beetroot)", category: "SALAD 🥗", unit: "kg", price: 80, icon: "🍠" },
  { name: "सकरकन्दी", category: "SALAD 🥗", unit: "kg", price: 100, icon: "🍠" },
  { name: "सफेद प्याज", category: "SALAD 🥗", unit: "kg", price: 30, icon: "🧅" },

  // MASALA
  { name: "अदरक (Ginger)", category: "MASALA", unit: "kg", price: 400, icon: "🫚" },
  { name: "कॉपी", category: "MASALA", unit: "pc", price: 140, icon: "☕" },
  { name: "छुला लहसुन", category: "MASALA", unit: "kg", price: 400, icon: "🧄" },
  { name: "नींबू (lemon) 🍋", category: "MASALA", unit: "kg", price: 250, icon: "🍋" },
  { name: "प्याज (onion) 🧅", category: "MASALA", unit: "kg", price: 80, icon: "🧅" },
  { name: "लहसुन 🧄", category: "MASALA", unit: "kg", price: 350, icon: "🧄" },

  // MIRCHI
  { name: "Moti mirchi lal", category: "MIRCHI", unit: "kg", price: 200, icon: "🌶️" },
  { name: "मिर्ची Normal 🌶️", category: "MIRCHI", unit: "kg", price: 100, icon: "🌶️" },
  { name: "मिर्ची 🌶️ तीखी", category: "MIRCHI", unit: "kg", price: 200, icon: "🌶️" },
  { name: "मोटी मिर्ची", category: "MIRCHI", unit: "kg", price: 150, icon: "🫑" },
  { name: "मोटी मिर्ची लाल 🌶️", category: "MIRCHI", unit: "kg", price: 150, icon: "🌶️" },
  { name: "लाल - पीली शिमला (Bell papers)", category: "MIRCHI", unit: "kg", price: 200, icon: "🫑" },
  { name: "शिमला Green", category: "MIRCHI", unit: "kg", price: 120, icon: "🫑" },
];

/** Emoji, spaces aur case hata kar naam compare karta hai (duplicate check). */
export function normalizeName(name: string) {
  return name
    .toLowerCase()
    .replace(/[^\p{L}\p{N}]+/gu, "")
    .trim();
}

const ICON_BY_NAME = new Map(CATALOG.map((p) => [normalizeName(p.name), p.icon]));

const KEYWORD_ICONS: Array<[RegExp, string]> = [
  [/mirch|मिर्च/i, "🌶️"],
  [/shimla|शिमला|capsic/i, "🫑"],
  [/tamatar|टमाटर|tomato/i, "🍅"],
  [/aloo|आलू|potato|arabi|अरबी/i, "🥔"],
  [/pyaj|प्याज|onion|kanda|कांदा/i, "🧅"],
  [/lahsun|लहसुन|garlic/i, "🧄"],
  [/adrak|अदरक|ginger|haldi|हल्दी/i, "🫚"],
  [/nimbu|नींबू|lemon/i, "🍋"],
  [/gajar|गाजर|carrot/i, "🥕"],
  [/gobhi|गोभी|brok|ब्रोक/i, "🥦"],
  [/palak|पालक|patta|पत्ता|mooli|मूली/i, "🥬"],
  [/dhaniya|धनिया|pudina|पुदीना|methi|मैथी|bathua|बथुआ/i, "🌿"],
  [/baingan|बैंगन|brinjal/i, "🍆"],
  [/kheera|खीरा|kakdi|ककडी|lauki|लोकी|turai|तुरई|karela|करेला|parval/i, "🥒"],
  [/matar|मटर|beans|बिन्स|fali|फली/i, "🫛"],
  [/mushroom|मशरूम/i, "🍄"],
  [/apple|सेब/i, "🍎"],
  [/banana|केला/i, "🍌"],
  [/mango|आम|keri|केरी|kachri|काचरी/i, "🥭"],
  [/grape|अंगूर/i, "🍇"],
  [/kaddu|कद्दू|pumpkin/i, "🎃"],
  [/beetroot|चुकन्दर|shakar|सकरकन्दी/i, "🍠"],
  [/kiwi|kivi/i, "🥝"],
  [/milk|दूध|paneer|curd|butter/i, "🥛"],
  [/ice ?cream|आइस/i, "🍦"],
];

/** Kisi bhi product ke liye icon deta hai (catalogue ya keyword match se). */
export function productIcon(name: string, category?: string) {
  const exact = ICON_BY_NAME.get(normalizeName(name));
  if (exact) return exact;
  for (const [re, icon] of KEYWORD_ICONS) if (re.test(name)) return icon;
  if (category) for (const [re, icon] of KEYWORD_ICONS) if (re.test(category)) return icon;
  return "🛒";
}
