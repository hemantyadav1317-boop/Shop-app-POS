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
    ["मैगी", "maggi maggie noodles"],
    ["बिस्कुट", "biscuit biscuits cookie cookies parle good day marie oreo bourbon"],
    ["तेल", "oil tel refine mustard sunflower sarson soya fortune saffola"],
    ["नमक", "salt namak tata salt"],
    ["चाय", "tea chai patti tata tea red label wagh bakri"],
    ["कॉफी", "coffee nescafe bru"],
    ["चीनी", "sugar cheeni shakkar madhur"],
    ["आटा", "atta flour wheat aashirvaad fortune"],
    ["चावल", "rice chawal basmati daawat india gate"],
    ["दाल", "dal pulses toor arhar moong chana sampann"],
    ["साबुन", "soap sabun dettol lifebuoy lux dove pears"],
    ["सर्फ", "surf detergent powder wash excel tide ariel rin"],
    ["मंजन", "toothpaste paste colgate closeup sensodyne"],
    ["मक्खन", "butter amul butter makhan"],
    ["घी", "ghee desi ghee cow ghee amul patanjali"],
    ["चिप्स", "chips lays kurkure namkeen bhujia sev haldiram"],
    ["शैम्पू", "shampoo clinic plus sunsilk dove head shoulders"],
    ["हार्पिक", "harpic toilet cleaner lizol colin floor"],
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
