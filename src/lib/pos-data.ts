export type Product = {
  id: string;
  name: string;
  price: number;
  unit: "kg" | "pc";
  category: string;
  stock: number;
};

export const CATEGORIES = [
  "All",
  "Fruits 🍎",
  "Green Veggies 🥬",
  "Dairy Products 🥛",
  "Masala",
  "Pooja 🪔",
  "Icecream 🍦",
  "Salad 🥗",
] as const;

export const PRODUCTS: Product[] = [
  { id: "p1", name: "Apple Royal Gala 🍎", price: 320, unit: "kg", category: "Fruits 🍎", stock: 24 },
  { id: "p2", name: "Apple 🍎", price: 280, unit: "kg", category: "Fruits 🍎", stock: 30 },
  { id: "p3", name: "Kivi", price: 160, unit: "kg", category: "Fruits 🍎", stock: 12 },
  { id: "p4", name: "Lychee (लीची)", price: 280, unit: "kg", category: "Fruits 🍎", stock: 8 },
  { id: "p5", name: "Plum", price: 240, unit: "kg", category: "Fruits 🍎", stock: 10 },
  { id: "p6", name: "VT Dates", price: 50, unit: "pc", category: "Fruits 🍎", stock: 40 },
  { id: "p7", name: "अंगूर Black 🍇", price: 300, unit: "kg", category: "Fruits 🍎", stock: 15 },
  { id: "p8", name: "अंगूर Green 🍏", price: 300, unit: "kg", category: "Fruits 🍎", stock: 15 },
  { id: "p9", name: "अनार (Pomegranate)", price: 240, unit: "kg", category: "Fruits 🍎", stock: 20 },
  { id: "p10", name: "अमरूद (Guava)", price: 180, unit: "kg", category: "Fruits 🍎", stock: 18 },
  { id: "p11", name: "आँवला", price: 300, unit: "kg", category: "Fruits 🍎", stock: 6 },
  { id: "p12", name: "आम (Mango) 🥭", price: 240, unit: "kg", category: "Fruits 🍎", stock: 22 },
  { id: "p13", name: "केला (Banana) 🍌", price: 50, unit: "kg", category: "Fruits 🍎", stock: 35 },

  { id: "v1", name: "टमाटर 🍅", price: 50, unit: "kg", category: "Green Veggies 🥬", stock: 40 },
  { id: "v2", name: "आलू", price: 25, unit: "kg", category: "Green Veggies 🥬", stock: 90 },
  { id: "v3", name: "प्याज (Onion) 🧅", price: 65, unit: "kg", category: "Green Veggies 🥬", stock: 70 },
  { id: "v4", name: "भिंडी", price: 80, unit: "kg", category: "Green Veggies 🥬", stock: 14 },
  { id: "v5", name: "बिन्स (Beans)", price: 250, unit: "kg", category: "Green Veggies 🥬", stock: 9 },
  { id: "v6", name: "मूली (Radish)", price: 80, unit: "kg", category: "Green Veggies 🥬", stock: 11 },
  { id: "v7", name: "अदरक (Ginger)", price: 400, unit: "kg", category: "Green Veggies 🥬", stock: 5 },
  { id: "v8", name: "हरी प्याज (Spring Onion)", price: 200, unit: "kg", category: "Green Veggies 🥬", stock: 7 },
  { id: "v9", name: "खीरा English 🥒", price: 70, unit: "kg", category: "Salad 🥗", stock: 16 },
  { id: "v10", name: "स्वीट कॉर्न 🌽", price: 80, unit: "pc", category: "Salad 🥗", stock: 25 },

  { id: "d1", name: "Amul Milk 500ml", price: 30, unit: "pc", category: "Dairy Products 🥛", stock: 60 },
  { id: "d2", name: "Amul Butter 100g", price: 62, unit: "pc", category: "Dairy Products 🥛", stock: 28 },
  { id: "d3", name: "Paneer 200g", price: 95, unit: "pc", category: "Dairy Products 🥛", stock: 12 },
  { id: "d4", name: "Curd 400g", price: 45, unit: "pc", category: "Dairy Products 🥛", stock: 20 },

  { id: "m1", name: "हल्दी 100g", price: 40, unit: "pc", category: "Masala", stock: 30 },
  { id: "m2", name: "मिर्च पाउडर 100g", price: 55, unit: "pc", category: "Masala", stock: 26 },
  { id: "m3", name: "धनिया 100g", price: 35, unit: "pc", category: "Masala", stock: 24 },
  { id: "m4", name: "गरम मसाला 50g", price: 60, unit: "pc", category: "Masala", stock: 18 },

  { id: "j1", name: "नारियल पूजा 🥥", price: 60, unit: "pc", category: "Pooja 🪔", stock: 22 },
  { id: "j2", name: "अगरबत्ती", price: 40, unit: "pc", category: "Pooja 🪔", stock: 33 },
  { id: "j3", name: "दीपक तेल", price: 120, unit: "pc", category: "Pooja 🪔", stock: 10 },

  { id: "i1", name: "Vanilla Cup 🍦", price: 30, unit: "pc", category: "Icecream 🍦", stock: 40 },
  { id: "i2", name: "Chocobar", price: 25, unit: "pc", category: "Icecream 🍦", stock: 45 },
  { id: "i3", name: "Family Pack 700ml", price: 220, unit: "pc", category: "Icecream 🍦", stock: 8 },
];

export const formatRs = (n: number) =>
  `Rs ${n.toLocaleString("en-IN", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
