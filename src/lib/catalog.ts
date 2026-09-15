export type CatalogItem = {
  name: string;
  category: string;
  unit: "kg" | "pc";
  price: number;
  /** Cartoon-style icon shown on the POS tile */
  icon: string;
};

export const CATEGORY_ORDER = [
  "FRUITS",
  "VEGETABLES",
  "GREEN VEGGIES",
  "SALAD",
  "MASALA",
  "MIRCHI",
  "DAIRY PRODUCTS",
] as const;

/**
 * Shop ka asli catalogue. Naam exactly wahi rakhe gaye hain.
 * Duplicate se bachne ke liye `normalizeName` se compare hota hai.
 */
export const CATALOG: CatalogItem[] = [

  // FRUITS
  { name: "स्ट्रॉबेरी (strawberry) 🍓", category: "FRUITS", unit: "pc", price: 80, icon: "🍓" },
  { name: "स्वीट कॉर्न", category: "FRUITS", unit: "kg", price: 80, icon: "🌽" },
  { name: "रामफल", category: "FRUITS", unit: "kg", price: 280, icon: "🍈" },
  { name: "लीची", category: "FRUITS", unit: "kg", price: 260, icon: "🔴" },
  { name: "संतरा (orange 🍊)", category: "FRUITS", unit: "kg", price: 450, icon: "🍊" },
  { name: "सियाडा", category: "FRUITS", unit: "kg", price: 80, icon: "🫐" },
  { name: "सीता फल", category: "FRUITS", unit: "kg", price: 140, icon: "🍈" },
  { name: "पाइनएप्पल", category: "FRUITS", unit: "kg", price: 110, icon: "🍍" },
  { name: "बब्बूगोशा / नग", category: "FRUITS", unit: "kg", price: 260, icon: "🍐" },
  { name: "बील", category: "FRUITS", unit: "kg", price: 70, icon: "🥥" },
  { name: "मक्का (corn)", category: "FRUITS", unit: "kg", price: 70, icon: "🌽" },
  { name: "माल्टा", category: "FRUITS", unit: "kg", price: 220, icon: "🍊" },
  { name: "तरबूज 🍉", category: "FRUITS", unit: "kg", price: 55, icon: "🍉" },
  { name: "नारियल पानी", category: "FRUITS", unit: "pc", price: 90, icon: "🥥" },
  { name: "नारियल पूजा 🥥", category: "FRUITS", unit: "pc", price: 60, icon: "🥥" },
  { name: "नाशपती", category: "FRUITS", unit: "kg", price: 160, icon: "🍐" },
  { name: "पपीता (PAPAYA)", category: "FRUITS", unit: "kg", price: 90, icon: "🧡" },
  { name: "खजूर पैकेट Gulf Dates", category: "FRUITS", unit: "pc", price: 140, icon: "🌴" },
  { name: "खजूरजा", category: "FRUITS", unit: "kg", price: 80, icon: "🌴" },
  { name: "खरबूजा मुस्कान", category: "FRUITS", unit: "kg", price: 70, icon: "🍈" },
  { name: "चीकू", category: "FRUITS", unit: "kg", price: 140, icon: "🟤" },
  { name: "जामुन", category: "FRUITS", unit: "kg", price: 260, icon: "🫐" },
  { name: "आम लंगड़ा 🥭", category: "FRUITS", unit: "kg", price: 220, icon: "🥭" },
  { name: "आलू बुखारा", category: "FRUITS", unit: "kg", price: 200, icon: "🍑" },
  { name: "किन्नू (kinnow) 🍊", category: "FRUITS", unit: "kg", price: 140, icon: "🍊" },
  { name: "कीवी (kiwi)", category: "FRUITS", unit: "pc", price: 180, icon: "🥝" },
  { name: "केला (banana) 🍌", category: "FRUITS", unit: "kg", price: 50, icon: "🍌" },
  { name: "अमरूद (guava)", category: "FRUITS", unit: "kg", price: 180, icon: "🟢" },
  { name: "आंवला", category: "FRUITS", unit: "kg", price: 100, icon: "🟢" },
  { name: "आम (mango) 🥭 जूस", category: "FRUITS", unit: "kg", price: 240, icon: "🥭" },
  { name: "आम चौसा 🥭", category: "FRUITS", unit: "kg", price: 180, icon: "🥭" },
  { name: "आम दशहरी 🥭🥭 गोल्ड", category: "FRUITS", unit: "kg", price: 240, icon: "🥭" },
  { name: "VT Dates", category: "FRUITS", unit: "pc", price: 50, icon: "🌴" },
  { name: "अंगूर Black 🍇 (grapes)", category: "FRUITS", unit: "kg", price: 300, icon: "🍇" },
  { name: "अंगूर green 🍇🌿 (grapes)", category: "FRUITS", unit: "kg", price: 300, icon: "🍇" },
  { name: "अनार (pomegranate)", category: "FRUITS", unit: "kg", price: 240, icon: "🍎" },
  { name: "Apple Royal gala 🍎🍎🍎", category: "FRUITS", unit: "kg", price: 320, icon: "🍎" },
  { name: "Apple 🍎🍎", category: "FRUITS", unit: "kg", price: 280, icon: "🍏" },

  // VEGETABLES
  { name: "लौकी", category: "VEGETABLES", unit: "kg", price: 60, icon: "🥒" },
  { name: "शोगरी", category: "VEGETABLES", unit: "kg", price: 80, icon: "🌿" },
  { name: "सेम फली", category: "VEGETABLES", unit: "kg", price: 100, icon: "🫛" },
  { name: "हल्दी", category: "VEGETABLES", unit: "kg", price: 160, icon: "🫚" },
  { name: "भिन्डी", category: "VEGETABLES", unit: "kg", price: 80, icon: "🫛" },
  { name: "मटर pencil", category: "VEGETABLES", unit: "kg", price: 180, icon: "🫛" },
  { name: "मशरूम", category: "VEGETABLES", unit: "pc", price: 80, icon: "🍄" },
  { name: "फूल गोभी", category: "VEGETABLES", unit: "kg", price: 140, icon: "🥦" },
  { name: "बीन्स (Beans)", category: "VEGETABLES", unit: "kg", price: 250, icon: "🫛" },
  { name: "बैंगन काले", category: "VEGETABLES", unit: "kg", price: 80, icon: "🍆" },
  { name: "बैंगन देसी (Baingan)", category: "VEGETABLES", unit: "kg", price: 140, icon: "🍆" },
  { name: "भरत बैंगन", category: "VEGETABLES", unit: "kg", price: 120, icon: "🍆" },
  { name: "टमाटर 🍅", category: "VEGETABLES", unit: "kg", price: 60, icon: "🍅" },
  { name: "टिंडा (desi)", category: "VEGETABLES", unit: "kg", price: 200, icon: "🟢" },
  { name: "टिंडा चप्पन", category: "VEGETABLES", unit: "kg", price: 80, icon: "🟢" },
  { name: "तुरई देसी", category: "VEGETABLES", unit: "kg", price: 120, icon: "🥒" },
  { name: "पत्ता गोभी", category: "VEGETABLES", unit: "kg", price: 70, icon: "🥬" },
  { name: "गाजर Red", category: "VEGETABLES", unit: "kg", price: 50, icon: "🥕" },
  { name: "गिलकी तोसी", category: "VEGETABLES", unit: "kg", price: 120, icon: "🥒" },
  { name: "ग्वार फली", category: "VEGETABLES", unit: "kg", price: 200, icon: "🫛" },
  { name: "चोला फली", category: "VEGETABLES", unit: "kg", price: 140, icon: "🫛" },
  { name: "टमाटर Hybrid tomato 🍅", category: "VEGETABLES", unit: "kg", price: 70, icon: "🍅" },
  { name: "कांदा", category: "VEGETABLES", unit: "kg", price: 30, icon: "🧅" },
  { name: "काचरी", category: "VEGETABLES", unit: "kg", price: 100, icon: "🍈" },
  { name: "कुंदरू", category: "VEGETABLES", unit: "kg", price: 80, icon: "🥒" },
  { name: "केरी", category: "VEGETABLES", unit: "kg", price: 200, icon: "🥭" },
  { name: "केरूजा", category: "VEGETABLES", unit: "kg", price: 120, icon: "🌿" },
  { name: "ब्रोकोली", category: "VEGETABLES", unit: "kg", price: 200, icon: "🥦" },
  { name: "परवल", category: "VEGETABLES", unit: "kg", price: 120, icon: "🥒" },
  { name: "अरबी (Arabi)", category: "VEGETABLES", unit: "kg", price: 80, icon: "🥔" },
  { name: "आलू", category: "VEGETABLES", unit: "kg", price: 25, icon: "🥔" },
  { name: "आलू लाल", category: "VEGETABLES", unit: "kg", price: 40, icon: "🍠" },

  // GREEN VEGGIES
  { name: "धनिया (coriander) 🌿", category: "GREEN VEGGIES", unit: "kg", price: 300, icon: "🌿" },
  { name: "पालक", category: "GREEN VEGGIES", unit: "kg", price: 100, icon: "🥬" },
  { name: "पुदीना", category: "GREEN VEGGIES", unit: "kg", price: 150, icon: "🌱" },
  { name: "बथुआ Bunch", category: "GREEN VEGGIES", unit: "kg", price: 80, icon: "🌿" },
  { name: "मूली (radish)", category: "GREEN VEGGIES", unit: "kg", price: 80, icon: "🥬" },
  { name: "मेथी Bunch", category: "GREEN VEGGIES", unit: "kg", price: 80, icon: "🌿" },
  { name: "सरसो", category: "GREEN VEGGIES", unit: "pc", price: 40, icon: "🥬" },
  { name: "हरी प्याज (spring Onion)", category: "GREEN VEGGIES", unit: "kg", price: 200, icon: "🧅" },
  { name: "हरी लहसुन", category: "GREEN VEGGIES", unit: "kg", price: 200, icon: "🧄" },

  // SALAD
  { name: "ककड़ी", category: "SALAD", unit: "kg", price: 100, icon: "🥒" },
  { name: "खीरा Desi 🥒", category: "SALAD", unit: "kg", price: 60, icon: "🥒" },
  { name: "खीरा English 🥒", category: "SALAD", unit: "kg", price: 70, icon: "🥒" },
  { name: "गाजर. पहाड़ी", category: "SALAD", unit: "kg", price: 120, icon: "🥕" },
  { name: "चुकन्दर (beetroot)", category: "SALAD", unit: "kg", price: 80, icon: "🍠" },
  { name: "शकरकन्दी", category: "SALAD", unit: "kg", price: 100, icon: "🍠" },
  { name: "सफेद प्याज", category: "SALAD", unit: "kg", price: 30, icon: "🧅" },

  // MASALA
  { name: "अदरक (Ginger)", category: "MASALA", unit: "kg", price: 400, icon: "🫚" },
  { name: "कॉफी", category: "MASALA", unit: "pc", price: 140, icon: "☕" },
  { name: "छुला लहसुन", category: "MASALA", unit: "kg", price: 400, icon: "🧄" },
  { name: "नींबू (lemon 🍋)", category: "MASALA", unit: "kg", price: 250, icon: "🍋" },
  { name: "प्याज (onion) 🧅", category: "MASALA", unit: "kg", price: 80, icon: "🧅" },
  { name: "लहसुन 🧄", category: "MASALA", unit: "kg", price: 350, icon: "🧄" },

  // MIRCHI
  { name: "मोटी मिर्ची लाल", category: "MIRCHI", unit: "kg", price: 200, icon: "🌶️" },
  { name: "मिर्ची Normal 🌶️", category: "MIRCHI", unit: "kg", price: 100, icon: "🌶️" },
  { name: "मिर्ची 🌶️ तीखी", category: "MIRCHI", unit: "kg", price: 200, icon: "🌶️" },
  { name: "मोटी मिर्ची", category: "MIRCHI", unit: "kg", price: 150, icon: "🫑" },

  // DAIRY PRODUCTS
  { name: "Buffalo 🐃 milk", category: "DAIRY PRODUCTS", unit: "pc", price: 90, icon: "🥛" },
  { name: "Cow milk", category: "DAIRY PRODUCTS", unit: "pc", price: 70, icon: "🥛" },
  { name: "छाछ", category: "DAIRY PRODUCTS", unit: "pc", price: 40, icon: "🥛" },
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
