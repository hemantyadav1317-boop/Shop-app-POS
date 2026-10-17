class ProductAliases {
  static const List<List<String>> list = [
    ["आलू", "potato aloo"],
    ["टमाटर", "tomato tamatar"],
    ["प्याज", "onion pyaz pyaaz"],
    ["अदरक", "ginger adrak"],
    ["लहसुन", "garlic lahsun"],
    ["गाजर", "carrot gajar"],
    ["भिंडी", "okra ladyfinger bhindi"],
    ["बैंगन", "brinjal eggplant baingan"],
    ["लौकी", "bottle gourd lauki"],
    ["पालक", "spinach palak"],
    ["गोभी", "cauliflower cabbage gobhi"],
    ["धनिया", "coriander dhaniya"],
    ["पुदीना", "mint pudina"],
    ["मिर्च", "chilli mirchi"],
    ["नींबू", "lemon lime nimbu"],
    ["खीरा", "cucumber kheera"],
    ["करेला", "bitter gourd karela"],
    ["सेब", "apple seb"],
    ["केला", "banana kela"],
    ["आम", "mango aam"],
    ["अमरूद", "guava amrood"],
    ["अनार", "pomegranate anar"],
    ["अंगूर", "grapes angoor"],
    ["पपीता", "papaya papita"],
    ["संतरा", "orange santra"],
    ["तरबूज", "watermelon tarbooj"],
    ["चीकू", "sapota chikoo"],
    ["लीची", "lychee litchi"],
    ["नारियल", "coconut nariyal"],
    ["खरबूजा", "muskmelon kharbuja"],
    ["दूध", "milk doodh"],
    ["दही", "curd yogurt dahi"],
    ["पनीर", "paneer cheese"],
    ["आइस", "ice cream"],
  ];

  static bool matches(String name, String? category, String? barcode, String query) {
    final term = query.trim().toLowerCase();
    if (term.isEmpty) return true;

    final lowerName = name.toLowerCase();
    final lowerCategory = (category ?? '').toLowerCase();
    final lowerBarcode = (barcode ?? '').toLowerCase();

    // Check direct match
    if (lowerName.contains(term) || lowerCategory.contains(term) || lowerBarcode.contains(term)) {
      return true;
    }

    // Check Hindi-English synonyms
    for (final pair in list) {
      final hindi = pair[0].toLowerCase();
      final english = pair[1].toLowerCase();

      final matchesName = lowerName.contains(hindi) || english.split(' ').any((w) => lowerName.contains(w));
      if (matchesName) {
        if (hindi.contains(term) || english.contains(term)) {
          return true;
        }
      }
    }

    // Check multi-word query
    final words = term.split(RegExp(r'\s+'));
    return words.every((w) => lowerName.contains(w) || lowerCategory.contains(w) || lowerBarcode.contains(w));
  }
}
