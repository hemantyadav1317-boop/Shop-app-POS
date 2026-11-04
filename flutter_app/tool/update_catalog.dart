import 'dart:io';

void main() {
  final items = [
    // 🥔 VEGETABLES & TUBERS (46 classes)
    _item('adrak', 'अदरक', 'Ginger', '🫚', ['adrak', 'ginger', 'अदरक'], ['brown', 'yellow'], 'irregular', ['aloo', 'arbi']),
    _item('aloo', 'आलू', 'Potato', '🥔', ['aloo', 'aalu', 'potato', 'आलू', 'बटाटा'], ['brown', 'yellow'], 'irregular', ['lal_aloo', 'shakarkandi', 'adrak']),
    _item('lal_aloo', 'लाल आलू', 'Red Potato', '🥔', ['lal aloo', 'red potato', 'लाल आलू'], ['red', 'brown'], 'irregular', ['aloo', 'shakarkandi']),
    _item('arbi', 'अरबी / घुइयां', 'Taro Root', '🥔', ['arbi', 'arvi', 'taro', 'अरबी', 'घुइयां'], ['brown'], 'irregular', ['adrak', 'aloo']),
    _item('shakarkandi', 'शकरकंदी', 'Sweet Potato', '🍠', ['shakarkandi', 'sweet potato', 'शकरकंद'], ['purple', 'brown', 'red'], 'elongated', ['lal_aloo', 'aloo']),
    _item('pyaj', 'लाल प्याज', 'Red Onion', '🧅', ['pyaj', 'pyaz', 'onion', 'कांदा', 'kanda', 'प्याज'], ['purple', 'brown'], 'round', ['safed_pyaj', 'chukandar']),
    _item('safed_pyaj', 'सफेद प्याज', 'White Onion', '🧅', ['safed pyaj', 'white onion', 'सफेद प्याज'], ['white', 'yellow'], 'round', ['pyaj', 'lahsun']),
    _item('lahsun', 'लहसुन', 'Garlic', '🧄', ['lahsun', 'garlic', 'लहसुन'], ['white'], 'round', ['safed_pyaj']),
    _item('hari_lahsun', 'हरा लहसुन', 'Green Garlic', '🧄', ['hari lahsun', 'green garlic', 'हरा लहसुन'], ['green', 'white'], 'elongated', ['pyaj', 'dhaniya']),
    _item('tamatar', 'देसी टमाटर', 'Tomato', '🍅', ['tamatar', 'tomato', 'टमाटर'], ['red', 'orange'], 'round', ['salad_hybrid_tamatar', 'anaar']),
    _item('salad_hybrid_tamatar', 'सलाद टमाटर', 'Hybrid Salad Tomato', '🍅', ['salad tamatar', 'hybrid tomato', 'टमाटर'], ['red'], 'round', ['tamatar']),
    _item('desi_mirchi', 'देसी हरी मिर्च', 'Green Chilli', '🌶️', ['desi mirchi', 'green chilli', 'हरी मिर्च', 'मिर्ची'], ['green'], 'elongated', ['tikhi_barik_mirchi', 'moti_bharva_mirchi']),
    _item('tikhi_barik_mirchi', 'तीखी बारीक मिर्च', 'Hot Thin Green Chilli', '🌶️', ['tikhi mirchi', 'hot chilli', 'बारीक मिर्च'], ['green'], 'elongated', ['desi_mirchi']),
    _item('moti_bharva_mirchi', 'मोटी भरवा मिर्च', 'Large Stuffed Chilli', '🫑', ['moti mirchi', 'bharva mirchi', 'मोटी मिर्च'], ['green'], 'elongated', ['green_capsicum', 'desi_mirchi']),
    _item('green_capsicum', 'शिमला मिर्च', 'Green Capsicum', '🫑', ['shimla mirch', 'green capsicum', 'शिमला मिर्च'], ['green'], 'round', ['mixed_capsicum', 'moti_bharva_mirchi']),
    _item('mixed_capsicum', 'लाल-पीली शिमला मिर्च', 'Mixed Capsicum', '🫑', ['lal pili shimla mirch', 'yellow red capsicum'], ['yellow', 'red'], 'round', ['green_capsicum']),
    _item('bhindi', 'भिंडी', 'Okra / Lady Finger', '🥬', ['bhindi', 'okra', 'ladyfinger', 'भिंडी'], ['green'], 'elongated', ['beans', 'tori']),
    _item('beans', 'हरी बीन्स / फलियां', 'Green Beans', '🫛', ['beans', 'green beans', 'बीन्स', 'फली'], ['green'], 'elongated', ['gavar_fali', 'sem_fali', 'chola_fali']),
    _item('gavar_fali', 'गवार फली', 'Cluster Beans', '🫛', ['gavar fali', 'guar fali', 'गवार फली'], ['green'], 'elongated', ['beans', 'chola_fali']),
    _item('sem_fali', 'सेम फली', 'Flat Beans', '🫛', ['sem fali', 'broad beans', 'सेम'], ['green'], 'elongated', ['beans', 'gavar_fali']),
    _item('chola_fali', 'चौला फली', 'Cowpea / Long Beans', '🫛', ['chola fali', 'lobia fali', 'चौला फली'], ['green'], 'elongated', ['beans', 'sangri_fali']),
    _item('sangri_fali', 'सांगरी फली', 'Sangri Pods', '🌾', ['sangri', 'sangri fali', 'सांगरी'], ['brown', 'green'], 'elongated', ['chola_fali']),
    _item('matar', 'हरी मटर', 'Green Peas', '🫛', ['matar', 'peas', 'green peas', 'मटर'], ['green'], 'round', ['beans']),
    _item('gobhi', 'फूलगोभी', 'Cauliflower', '🥦', ['gobhi', 'phool gobhi', 'cauliflower', 'फूलगोभी'], ['white', 'green'], 'round', ['broccoli', 'cabbage']),
    _item('broccoli', 'ब्रोकली', 'Broccoli', '🥦', ['broccoli', 'brokali', 'ब्रोकली'], ['green'], 'round', ['gobhi']),
    _item('kheera', 'देसी खीरा', 'Cucumber', '🥒', ['kheera', 'cucumber', 'खीरा'], ['green'], 'elongated', ['english_kheera', 'tar_kakdi', 'lauki']),
    _item('english_kheera', 'इंग्लिश खीरा', 'English Cucumber', '🥒', ['english kheera', 'english cucumber'], ['green'], 'elongated', ['kheera', 'tar_kakdi']),
    _item('tar_kakdi', 'तर ककड़ी', 'Long Green Cucumber', '🥒', ['tar kakdi', 'kakdi', 'ककड़ी'], ['green'], 'elongated', ['kheera', 'english_kheera', 'tori']),
    _item('lauki', 'लौकी / घिया', 'Bottle Gourd', '🥒', ['lauki', 'ghiya', 'bottle gourd', 'लौकी'], ['green'], 'elongated', ['tori', 'gilki_tori', 'kheera']),
    _item('tori', 'तोरी / तोरई', 'Ridge Gourd', '🥒', ['tori', 'turai', 'ridge gourd', 'तोरी'], ['green'], 'elongated', ['gilki_tori', 'lauki']),
    _item('gilki_tori', 'गिलकी तोरी', 'Sponge Gourd', '🥒', ['gilki', 'sponge gourd', 'गिलकी'], ['green'], 'elongated', ['tori', 'lauki']),
    _item('karela', 'करेला', 'Bitter Gourd', '🥒', ['karela', 'bitter gourd', 'करेला'], ['green'], 'elongated', ['tori', 'kundru']),
    _item('tinda', 'देसी टिंडा', 'Round Gourd', '🍈', ['tinda', 'round gourd', 'टिंडा'], ['green'], 'round', ['chappan_tinda', 'parwal_kachri']),
    _item('chappan_tinda', 'छप्पन टिंडा', 'Squash Gourd', '🍈', ['chappan tinda', 'squash gourd', 'छप्पन टिंडा'], ['green', 'yellow'], 'round', ['tinda']),
    _item('parwal_kachri', 'परवल / काचरी', 'Pointed Gourd / Kachri', '🍈', ['parwal', 'kachri', 'परवल', 'काचरी'], ['green'], 'round', ['tinda', 'kundru']),
    _item('kundru', 'कुंदरू', 'Ivy Gourd', '🥒', ['kundru', 'ivy gourd', 'कुंदरू'], ['green'], 'elongated', ['parwal_kachri', 'karela']),
    _item('kaddu', 'पीला कद्दू', 'Pumpkin', '🎃', ['kaddu', 'pumpkin', 'कद्दू', 'सीताफल'], ['yellow', 'orange', 'green'], 'round', ['tarbooj']),
    _item('black_baingan', 'गोल काला बैंगन', 'Black Eggplant', '🍆', ['black baingan', 'eggplant', 'काला बैंगन', 'बैंगन'], ['purple'], 'round', ['black_bharta_baingan', 'lal_baingan']),
    _item('black_bharta_baingan', 'भरता बैंगन', 'Large Black Bharta Eggplant', '🍆', ['bharta baingan', 'large eggplant', 'भरता बैंगन'], ['purple'], 'round', ['black_baingan']),
    _item('lal_baingan', 'बैंगनी / लाल बैंगन', 'Purple Eggplant', '🍆', ['lal baingan', 'purple eggplant', 'बैंगन'], ['purple'], 'round', ['black_baingan']),
    _item('muli', 'मूली', 'Radish', '🥕', ['muli', 'radish', 'मूली'], ['white'], 'elongated', ['orange_carrot', 'red_carrot']),
    _item('red_carrot', 'देसी लाल गाजर', 'Red Carrot', '🥕', ['lal gajar', 'red carrot', 'गाजर'], ['red'], 'elongated', ['orange_carrot', 'muli']),
    _item('orange_carrot', 'संतरी गाजर', 'Orange Carrot', '🥕', ['orange gajar', 'orange carrot', 'गाजर'], ['orange'], 'elongated', ['red_carrot', 'muli']),
    _item('chukandar', 'चुकंदर', 'Beetroot', '🫐', ['chukandar', 'beetroot', 'चुकंदर'], ['purple', 'red'], 'round', ['pyaj']),
    _item('mushroom', 'बटन मशरूम', 'Button Mushroom', '🍄', ['mushroom', 'button mushroom', 'मशरूम'], ['white'], 'round', ['lahsun']),
    _item('singhada', 'सिंघाड़ा', 'Water Chestnut', '🌰', ['singhada', 'water chestnut', 'सिंघाड़ा'], ['green', 'brown', 'purple'], 'irregular', ['jamun']),

    // 🌿 LEAFY GREENS (6 classes)
    _item('palak', 'पालक', 'Spinach', '🥬', ['palak', 'spinach', 'पालक'], ['green'], 'leafy', ['bathua', 'hari_methi']),
    _item('hari_methi', 'हरी मेथी', 'Fenugreek Greens', '🌿', ['hari methi', 'methi', 'fenugreek', 'मेथी'], ['green'], 'leafy', ['palak', 'bathua', 'dhaniya']),
    _item('bathua', 'बथुआ', 'Bathua Greens', '🌿', ['bathua', 'bathua saag', 'बथुआ'], ['green'], 'leafy', ['palak', 'hari_methi']),
    _item('dhaniya', 'हरा धनिया', 'Coriander', '🌿', ['dhaniya', 'coriander', 'धनिया', 'कोथमीर'], ['green'], 'leafy', ['pudina', 'hari_methi']),
    _item('pudina', 'पुदीना', 'Mint', '🌿', ['pudina', 'mint', 'पुदीना'], ['green'], 'leafy', ['dhaniya']),
    _item('bel_patra_leaves', 'बेलपत्र', 'Bel Patra Leaves', '🍃', ['bel patra', 'bilva patra', 'बेलपत्र'], ['green'], 'leafy', ['dhaniya']),

    // 🍎 FRUITS (25 classes)
    _item('tamatar_fruit', 'टमाटर फल', 'Tomato', '🍅', ['tamatar'], ['red'], 'round', ['anaar']),
    _item('aavla', 'आंवला', 'Indian Gooseberry', '🟢', ['aavla', 'amla', 'आंवला'], ['green', 'yellow'], 'round', ['amrood', 'nimbu']),
    _item('amrood', 'अमरूद', 'Guava', '🍈', ['amrood', 'guava', 'अमरूद', 'पेरू'], ['green', 'yellow'], 'round', ['aavla', 'pear']),
    _item('anaar', 'अनार', 'Pomegranate', '🍎', ['anaar', 'pomegranate', 'अनार'], ['red'], 'round', ['tamatar', 'apple', 'plum']),
    _item('bael_fruit', 'बेल फल / श्रीफल', 'Bael Fruit', '🍈', ['bael fruit', 'bilva fruit', 'बेल फल'], ['green', 'yellow', 'brown'], 'round', ['nariyal_pani', 'amrood']),
    _item('chikoo', 'चीकू', 'Sapodilla / Chikoo', '🥔', ['chikoo', 'chiku', 'sapota', 'चीकू'], ['brown'], 'round', ['kiwi', 'aloo']),
    _item('desi_orange', 'देसी संतरा', 'Desi Orange', '🍊', ['desi santra', 'orange', 'संतरा'], ['orange'], 'round', ['green_orange', 'malta', 'mini_orange']),
    _item('green_orange', 'हरा संतरा / मौसमी', 'Green Orange / Sweet Lime', '🟢', ['green santra', 'mosambi', 'मौसमी', 'कीन्नू'], ['green', 'yellow'], 'round', ['desi_orange', 'malta', 'nimbu']),
    _item('malta', 'माल्टा संतरा', 'Malta Orange', '🍊', ['malta', 'malta santra', 'माल्टा'], ['orange'], 'round', ['desi_orange', 'mini_orange']),
    _item('mini_orange', 'मिनी संतरा / कीन्नू', 'Mini Orange', '🍊', ['mini orange', 'kinnu', 'छोटा संतरा'], ['orange'], 'round', ['desi_orange', 'nimbu']),
    _item('nimbu', 'नींबू', 'Lemon', '🍋', ['nimbu', 'lemon', 'नींबू'], ['yellow', 'green'], 'round', ['aavla', 'mini_orange']),
    _item('jamun', 'जामुन', 'Black Plum / Jamun', '🫐', ['jamun', 'black plum', 'जामुन'], ['purple'], 'elongated', ['plum', 'singhada']),
    _item('katahal', 'कटहल', 'Jackfruit', '🍈', ['katahal', 'jackfruit', 'कटहल'], ['green', 'yellow'], 'irregular', ['tarbooj', 'pineapple']),
    _item('kele', 'केला', 'Banana', '🍌', ['kele', 'banana', 'केला'], ['yellow', 'green'], 'elongated', ['cucumber']),
    _item('kivi', 'कीवी', 'Kiwi', '🥝', ['kivi', 'kiwi', 'कीवी'], ['brown', 'green'], 'round', ['chikoo']),
    _item('nariyal_pani', 'नारियल पानी / डाभ', 'Tender Coconut', '🥥', ['nariyal pani', 'tender coconut', 'नारियल'], ['green', 'yellow'], 'round', ['bael_fruit']),
    _item('papita', 'पपीता', 'Papaya', '🍈', ['papita', 'papaya', 'पपीता'], ['orange', 'yellow', 'green'], 'elongated', ['lauki']),
    _item('pear', 'नाशपाती / बबूगोशा', 'Pear', '🍐', ['pear', 'nashpati', 'babugosha', 'नाशपाती'], ['green', 'yellow'], 'round', ['amrood']),
    _item('persimmon', 'अमरफल / परसिमन', 'Persimmon', '🍅', ['persimmon', 'amarfal', 'रामफल'], ['orange', 'red'], 'round', ['tamatar']),
    _item('pineapple', 'अनानास', 'Pineapple', '🍍', ['pineapple', 'ananas', 'अनानास'], ['yellow', 'brown', 'green'], 'elongated', ['katahal']),
    _item('plum', 'आलू बुखारा / प्लम', 'Plum', '🍑', ['plum', 'aaloo bukhara', 'आलूबुखारा'], ['purple', 'red'], 'round', ['anaar', 'jamun']),
    _item('ramfal', 'रामफल', 'Wild Sweetsop / Ramfal', '🍈', ['ramfal', 'ramphal', 'रामफल'], ['orange', 'red', 'yellow'], 'round', ['sitafal']),
    _item('sitafal', 'सीताफल / शरीफा', 'Custard Apple / Sharifa', '🍈', ['sitafal', 'sharifa', 'custard apple', 'सीताफल'], ['green'], 'round', ['ramfal']),
    _item('strawberry', 'स्ट्रॉबेरी', 'Strawberry', '🍓', ['strawberry', 'स्ट्रॉबेरी'], ['red'], 'round', ['anaar']),
    _item('tarbooj', 'तरबूज', 'Watermelon', '🍉', ['tarbooj', 'watermelon', 'तरबूज'], ['green'], 'round', ['kaddu', 'katahal']),

    // 📦 PACKAGED ITEMS (7 classes)
    _item('cow_milk', 'गाय का दूध', 'Cow Milk', '🥛', ['cow milk', 'gai doodh', 'दूध'], ['white', 'blue'], 'elongated', ['buffalo_milk', 'chhach']),
    _item('buffalo_milk', 'भैंस का दूध', 'Buffalo Milk', '🥛', ['buffalo milk', 'bhains doodh', 'दूध'], ['white', 'yellow'], 'elongated', ['cow_milk', 'chhach']),
    _item('chhach', 'छाछ / मट्ठा', 'Buttermilk / Chhach', '🥛', ['chhach', 'chach', 'mattha', 'छाछ'], ['white', 'green'], 'elongated', ['cow_milk', 'buffalo_milk']),
    _item('zahidi_dates', 'जाहिदी खजूर', 'Zahidi Dates', '🌴', ['zahidi dates', 'khajoor', 'खजूर'], ['brown', 'yellow'], 'elongated', ['baran_iranian_dates', 'seer_shah_seedless_dates']),
    _item('baran_iranian_dates', 'ईरानी खजूर', 'Baran Iranian Dates', '🌴', ['iranian dates', 'baran dates', 'खजूर'], ['brown', 'black'], 'elongated', ['zahidi_dates', 'jk_selected_dates']),
    _item('seer_shah_seedless_dates', 'सीडलेस खजूर', 'Seer Shah Seedless Dates', '🌴', ['seedless dates', 'khajoor', 'खजूर'], ['brown'], 'elongated', ['zahidi_dates', 'jk_selected_dates']),
    _item('jk_selected_dates', 'जेके सिलेक्टेड खजूर', 'JK Selected Dates', '🌴', ['jk dates', 'selected dates', 'खजूर'], ['brown'], 'elongated', ['baran_iranian_dates', 'seer_shah_seedless_dates']),
  ];

  final buffer = StringBuffer();
  buffer.writeln('library;');
  buffer.writeln();
  buffer.writeln('/// AI Vision Catalog for Indian Vegetables, Fruits, and Store Items.');
  buffer.writeln('/// Generated and aligned with Yadav VeggiFruit Store Dataset (83 classes).');
  buffer.writeln();
  buffer.writeln('class ProduceItem {');
  buffer.writeln('  final String id;');
  buffer.writeln('  final String hindiName;');
  buffer.writeln('  final String englishName;');
  buffer.writeln('  final String icon;');
  buffer.writeln('  final List<String> aliases;');
  buffer.writeln('  final List<String> primaryColors;');
  buffer.writeln('  final String shapeType;');
  buffer.writeln('  final List<String> confusableWith;');
  buffer.writeln();
  buffer.writeln('  const ProduceItem({');
  buffer.writeln('    required this.id,');
  buffer.writeln('    required this.hindiName,');
  buffer.writeln('    required this.englishName,');
  buffer.writeln('    required this.icon,');
  buffer.writeln('    required this.aliases,');
  buffer.writeln('    required this.primaryColors,');
  buffer.writeln('    required this.shapeType,');
  buffer.writeln('    this.confusableWith = const [],');
  buffer.writeln('  });');
  buffer.writeln('}');
  buffer.writeln();
  buffer.writeln('class AiVisionCatalog {');
  buffer.writeln('  AiVisionCatalog._();');
  buffer.writeln();
  buffer.writeln('  static const List<ProduceItem> allItems = [');

  for (final itm in items) {
    buffer.writeln('    ProduceItem(');
    buffer.writeln('      id: \'${itm['id']}\',');
    buffer.writeln('      hindiName: \'${itm['hindiName']}\',');
    buffer.writeln('      englishName: \'${itm['englishName']}\',');
    buffer.writeln('      icon: \'${itm['icon']}\',');
    buffer.writeln('      aliases: ${itm['aliases']},');
    buffer.writeln('      primaryColors: ${itm['primaryColors']},');
    buffer.writeln('      shapeType: \'${itm['shapeType']}\',');
    buffer.writeln('      confusableWith: ${itm['confusableWith']},');
    buffer.writeln('    ),');
  }

  buffer.writeln('  ];');
  buffer.writeln();
  buffer.writeln('  static ProduceItem? findById(String id) {');
  buffer.writeln('    try {');
  buffer.writeln('      return allItems.firstWhere((item) => item.id == id);');
  buffer.writeln('    } catch (_) {');
  buffer.writeln('      return null;');
  buffer.writeln('    }');
  buffer.writeln('  }');
  buffer.writeln();
  buffer.writeln('  static ProduceItem? findByText(String query) {');
  buffer.writeln('    final clean = query.trim().toLowerCase();');
  buffer.writeln('    for (final item in allItems) {');
  buffer.writeln('      if (item.id.toLowerCase() == clean ||');
  buffer.writeln('          item.hindiName.toLowerCase() == clean ||');
  buffer.writeln('          item.englishName.toLowerCase() == clean) {');
  buffer.writeln('        return item;');
  buffer.writeln('      }');
  buffer.writeln('      for (final a in item.aliases) {');
  buffer.writeln('        if (clean.contains(a.toLowerCase()) || a.toLowerCase().contains(clean)) {');
  buffer.writeln('          return item;');
  buffer.writeln('        }');
  buffer.writeln('      }');
  buffer.writeln('    }');
  buffer.writeln('    return null;');
  buffer.writeln('  }');
  buffer.writeln('}');

  File('lib/core/services/ai_vision_catalog.dart').writeAsStringSync(buffer.toString());
  print('✅ Successfully updated lib/core/services/ai_vision_catalog.dart with ${items.length} classes!');
}

Map<String, dynamic> _item(
  String id,
  String hindiName,
  String englishName,
  String icon,
  List<String> aliases,
  List<String> colors,
  String shape,
  List<String> confusable,
) {
  return {
    'id': id,
    'hindiName': hindiName,
    'englishName': englishName,
    'icon': icon,
    'aliases': aliases.map((s) => '\'$s\'').toList(),
    'primaryColors': colors.map((s) => '\'$s\'').toList(),
    'shapeType': shape,
    'confusableWith': confusable.map((s) => '\'$s\'').toList(),
  };
}

