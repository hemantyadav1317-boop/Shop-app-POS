library;

/// AI Vision Catalog for Indian Vegetables, Fruits, and Loose Kirana Items.
/// Maps visual signatures, colors, aspect ratios, and bilingual names.

class ProduceItem {
  final String id;
  final String hindiName;
  final String englishName;
  final String icon;
  final List<String> aliases;
  final List<String> primaryColors; // 'red', 'green', 'yellow', 'brown', 'purple', 'white', 'orange'
  final String shapeType; // 'round', 'elongated', 'irregular', 'leafy', 'cluster'
  final List<String> confusableWith; // IDs of items that look similar

  const ProduceItem({
    required this.id,
    required this.hindiName,
    required this.englishName,
    required this.icon,
    required this.aliases,
    required this.primaryColors,
    required this.shapeType,
    this.confusableWith = const [],
  });
}

class AiVisionCatalog {
  AiVisionCatalog._();

  static const List<ProduceItem> allItems = [
    // 🥔 Roots & Tubers
    ProduceItem(
      id: 'potato',
      hindiName: 'आलू',
      englishName: 'Potato',
      icon: '🥔',
      aliases: ['aalu', 'aloo', 'potato', 'आलू', 'बटाटा', 'batata'],
      primaryColors: ['brown', 'yellow'],
      shapeType: 'irregular',
      confusableWith: ['sweet_potato', 'ginger'],
    ),
    ProduceItem(
      id: 'onion',
      hindiName: 'प्याज',
      englishName: 'Onion',
      icon: '🧅',
      aliases: ['pyaz', 'pyaaj', 'onion', 'कांदा', 'kanda', 'प्याज'],
      primaryColors: ['purple', 'pink', 'brown'],
      shapeType: 'round',
      confusableWith: ['garlic', 'beetroot'],
    ),
    ProduceItem(
      id: 'tomato',
      hindiName: 'टमाटर',
      englishName: 'Tomato',
      icon: '🍅',
      aliases: ['tamatar', 'tomato', 'tamater', 'टमाटर'],
      primaryColors: ['red', 'orange'],
      shapeType: 'round',
      confusableWith: ['apple', 'plum'],
    ),
    ProduceItem(
      id: 'ginger',
      hindiName: 'अदरक',
      englishName: 'Ginger',
      icon: '🫚',
      aliases: ['adrak', 'ginger', 'अदरक'],
      primaryColors: ['brown', 'yellow'],
      shapeType: 'irregular',
      confusableWith: ['potato'],
    ),
    ProduceItem(
      id: 'garlic',
      hindiName: 'लहसुन',
      englishName: 'Garlic',
      icon: '🧄',
      aliases: ['lahsun', 'garlic', 'लहसुन'],
      primaryColors: ['white'],
      shapeType: 'round',
      confusableWith: ['onion'],
    ),

    // 🥒 Greens & Cucurbits
    ProduceItem(
      id: 'cucumber',
      hindiName: 'खीरा',
      englishName: 'Cucumber',
      icon: '🥒',
      aliases: ['kheera', 'khira', 'cucumber', 'खीरा'],
      primaryColors: ['green'],
      shapeType: 'elongated',
      confusableWith: ['kakdi', 'bottle_gourd', 'zucchini'],
    ),
    ProduceItem(
      id: 'kakdi',
      hindiName: 'ककड़ी',
      englishName: 'Kakdi',
      icon: '🥒',
      aliases: ['kakdi', 'kakadi', 'ककड़ी'],
      primaryColors: ['green', 'yellow'],
      shapeType: 'elongated',
      confusableWith: ['cucumber'],
    ),
    ProduceItem(
      id: 'green_chilli',
      hindiName: 'हरी मिर्च',
      englishName: 'Green Chilli',
      icon: '🌶️',
      aliases: ['hari mirch', 'green chilli', 'mirchi', 'हरी मिर्च', 'मिर्च'],
      primaryColors: ['green'],
      shapeType: 'elongated',
      confusableWith: ['beans'],
    ),
    ProduceItem(
      id: 'capsicum',
      hindiName: 'शिमला मिर्च',
      englishName: 'Capsicum',
      icon: '🫑',
      aliases: ['shimla mirch', 'capsicum', 'bell pepper', 'शिमला मिर्च'],
      primaryColors: ['green'],
      shapeType: 'round',
      confusableWith: ['apple'],
    ),
    ProduceItem(
      id: 'bottle_gourd',
      hindiName: 'लौकी',
      englishName: 'Bottle Gourd',
      icon: '🥒',
      aliases: ['lauki', 'bottle gourd', 'ghiya', 'लौकी', 'घिया'],
      primaryColors: ['green'],
      shapeType: 'elongated',
      confusableWith: ['cucumber', 'ridge_gourd'],
    ),
    ProduceItem(
      id: 'bitter_gourd',
      hindiName: 'करेला',
      englishName: 'Bitter Gourd',
      icon: '🥒',
      aliases: ['karela', 'bitter gourd', 'करेला'],
      primaryColors: ['green'],
      shapeType: 'elongated',
      confusableWith: ['ridge_gourd'],
    ),
    ProduceItem(
      id: 'ridge_gourd',
      hindiName: 'तोरई',
      englishName: 'Ridge Gourd',
      icon: '🥒',
      aliases: ['torai', 'turai', 'ridge gourd', 'तोरई', 'तोरी'],
      primaryColors: ['green'],
      shapeType: 'elongated',
      confusableWith: ['bottle_gourd', 'bitter_gourd'],
    ),
    ProduceItem(
      id: 'ladyfinger',
      hindiName: 'भिंडी',
      englishName: 'Ladyfinger / Okra',
      icon: '🌱',
      aliases: ['bhindi', 'ladyfinger', 'okra', 'भिंडी'],
      primaryColors: ['green'],
      shapeType: 'elongated',
      confusableWith: ['green_chilli', 'beans'],
    ),
    ProduceItem(
      id: 'brinjal',
      hindiName: 'बैंगन',
      englishName: 'Brinjal / Eggplant',
      icon: '🍆',
      aliases: ['baingan', 'brinjal', 'eggplant', 'बैंगन'],
      primaryColors: ['purple', 'green'],
      shapeType: 'round',
      confusableWith: ['onion'],
    ),
    ProduceItem(
      id: 'cauliflower',
      hindiName: 'फूलगोभी',
      englishName: 'Cauliflower',
      icon: '🥦',
      aliases: ['phool gobi', 'cauliflower', 'gobi', 'फूलगोभी'],
      primaryColors: ['white', 'green'],
      shapeType: 'round',
      confusableWith: ['cabbage'],
    ),
    ProduceItem(
      id: 'cabbage',
      hindiName: 'पत्तागोभी',
      englishName: 'Cabbage',
      icon: '🥬',
      aliases: ['patta gobi', 'cabbage', 'bandh gobi', 'पत्तागोभी'],
      primaryColors: ['green'],
      shapeType: 'round',
      confusableWith: ['cauliflower'],
    ),
    ProduceItem(
      id: 'carrot',
      hindiName: 'गाजर',
      englishName: 'Carrot',
      icon: '🥕',
      aliases: ['gajar', 'carrot', 'गाजर'],
      primaryColors: ['orange', 'red'],
      shapeType: 'elongated',
      confusableWith: ['radish'],
    ),
    ProduceItem(
      id: 'radish',
      hindiName: 'मूली',
      englishName: 'Radish',
      icon: '🌱',
      aliases: ['mooli', 'muli', 'radish', 'मूली'],
      primaryColors: ['white'],
      shapeType: 'elongated',
      confusableWith: ['carrot'],
    ),
    ProduceItem(
      id: 'coriander',
      hindiName: 'धनिया',
      englishName: 'Coriander',
      icon: '🌿',
      aliases: ['dhaniya', 'coriander', 'धनिया', 'कोथमीर'],
      primaryColors: ['green'],
      shapeType: 'leafy',
      confusableWith: ['spinach', 'methi'],
    ),
    ProduceItem(
      id: 'spinach',
      hindiName: 'पालक',
      englishName: 'Spinach',
      icon: '🥬',
      aliases: ['palak', 'spinach', 'पालक'],
      primaryColors: ['green'],
      shapeType: 'leafy',
      confusableWith: ['coriander', 'methi'],
    ),
    ProduceItem(
      id: 'lemon',
      hindiName: 'नींबू',
      englishName: 'Lemon',
      icon: '🍋',
      aliases: ['nimbu', 'lemon', 'नींबू'],
      primaryColors: ['yellow', 'green'],
      shapeType: 'round',
      confusableWith: ['orange', 'sweet_lime'],
    ),
    ProduceItem(
      id: 'peas',
      hindiName: 'मटर',
      englishName: 'Green Peas',
      icon: '🟢',
      aliases: ['matar', 'green peas', 'मटर'],
      primaryColors: ['green'],
      shapeType: 'cluster',
      confusableWith: ['beans'],
    ),

    // 🍎 Fruits
    ProduceItem(
      id: 'apple',
      hindiName: 'सेब',
      englishName: 'Apple',
      icon: '🍎',
      aliases: ['seb', 'apple', 'सेब'],
      primaryColors: ['red'],
      shapeType: 'round',
      confusableWith: ['tomato', 'pomegranate'],
    ),
    ProduceItem(
      id: 'banana',
      hindiName: 'केला',
      englishName: 'Banana',
      icon: '🍌',
      aliases: ['kela', 'banana', 'केला'],
      primaryColors: ['yellow', 'green'],
      shapeType: 'elongated',
      confusableWith: [],
    ),
    ProduceItem(
      id: 'orange',
      hindiName: 'संतरा',
      englishName: 'Orange / Santra',
      icon: '🍊',
      aliases: ['santra', 'orange', 'संतरा', 'narangi'],
      primaryColors: ['orange'],
      shapeType: 'round',
      confusableWith: ['lemon'],
    ),
    ProduceItem(
      id: 'pomegranate',
      hindiName: 'अनार',
      englishName: 'Pomegranate',
      icon: '🍎',
      aliases: ['anaar', 'anar', 'pomegranate', 'अनार'],
      primaryColors: ['red'],
      shapeType: 'round',
      confusableWith: ['apple'],
    ),
    ProduceItem(
      id: 'guava',
      hindiName: 'अमरूद',
      englishName: 'Guava',
      icon: '🍈',
      aliases: ['amrood', 'guava', 'अमरूद'],
      primaryColors: ['green', 'yellow'],
      shapeType: 'round',
      confusableWith: ['raw_mango'],
    ),
    ProduceItem(
      id: 'raw_mango',
      hindiName: 'कच्चा आम / कैरी',
      englishName: 'Raw Mango',
      icon: '🥭',
      aliases: ['kaccha aam', 'kairi', 'raw mango', 'कैरी', 'कच्चा आम'],
      primaryColors: ['green'],
      shapeType: 'round',
      confusableWith: ['guava'],
    ),
    ProduceItem(
      id: 'papaya',
      hindiName: 'पपीता',
      englishName: 'Papaya',
      icon: '🍈',
      aliases: ['papita', 'papaya', 'पपीता'],
      primaryColors: ['green', 'yellow', 'orange'],
      shapeType: 'elongated',
      confusableWith: ['bottle_gourd'],
    ),
    ProduceItem(
      id: 'watermelon',
      hindiName: 'तरबूज',
      englishName: 'Watermelon',
      icon: '🍉',
      aliases: ['tarbooj', 'watermelon', 'तरबूज'],
      primaryColors: ['green'],
      shapeType: 'round',
      confusableWith: ['muskmelon'],
    ),
  ];

  static ProduceItem? findById(String id) {
    try {
      return allItems.firstWhere((item) => item.id == id);
    } catch (_) {
      return null;
    }
  }

  static ProduceItem? findByText(String query) {
    final clean = query.trim().toLowerCase();
    for (final item in allItems) {
      if (item.id.toLowerCase() == clean ||
          item.hindiName.toLowerCase() == clean ||
          item.englishName.toLowerCase() == clean) {
        return item;
      }
      for (final a in item.aliases) {
        if (clean.contains(a.toLowerCase()) || a.toLowerCase().contains(clean)) {
          return item;
        }
      }
    }
    return null;
  }
}
