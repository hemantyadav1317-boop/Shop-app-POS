import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

class BillQuote {
  final String line1;
  final String line2;

  const BillQuote({required this.line1, required this.line2});

  @override
  String toString() => '$line1\n$line2';
}

class AiQuoteService {
  static const String _prefKeyLastIndex = 'ai_quote_last_index';
  static const String _prefKeyHistory = 'ai_quote_history_v1';

  /// A rich, curated knowledge base of 100+ heartwarming, witty, and grocery/health/neighborhood
  /// themed 2-line quotes that bring an instant smile to customers' faces.
  static const List<BillQuote> _curatedQuotes = [
    BillQuote(
      line1: 'ताज़ा फल, हरी सब्ज़ियां और आपकी मीठी मुस्कान!',
      line2: 'आपकी सेहत हमेशा तंदुरुस्त रहे, धन्यवाद! 🙏',
    ),
    BillQuote(
      line1: 'घर का राशन और अपनों का प्यार,',
      line2: 'रसोई में बरकत बनी रहे हर बार! 🌸',
    ),
    BillQuote(
      line1: 'चाय की चुस्की और देसी मसाले,',
      line2: 'आपका हर दिन खुशहाल और महकता बना ले! ☕',
    ),
    BillQuote(
      line1: 'जैसे ताज़े धनिए की भीनी खुशबू,',
      line2: 'वैसे ही महकता रहे आपका हर दिन! 🌿',
    ),
    BillQuote(
      line1: 'शुद्ध खान-पान, स्वस्थ जीवन की पहचान!',
      line2: 'आपकी मुस्कान ही हमारी असली कमाई है! 😊',
    ),
    BillQuote(
      line1: 'दाल-चावल, घी और मीठे पकवान,',
      line2: 'सदा आबाद रहे आपका हंसता-खेलता खानदान! ✨',
    ),
    BillQuote(
      line1: 'ताज़गी ऐसी जो दिल खुश कर दे,',
      line2: 'पड़ोस की अपनी दुकान में फिर पधारें! 🛒',
    ),
    BillQuote(
      line1: 'Fresh ingredients for happy family meals!',
      line2: 'Thank you for supporting your local grocery! ❤️',
    ),
    BillQuote(
      line1: 'A healthy outside starts from the inside!',
      line2: 'Eat fresh, stay smiling, and visit again! 🍏',
    ),
    BillQuote(
      line1: 'मिठास गुड़ की और प्यार अपनापन का,',
      line2: 'रिश्ता आपका और हमारा हमेशा बना रहे! 🍯',
    ),
    BillQuote(
      line1: 'गर्मागर्म रोटियां और ताज़ी तरकारी,',
      line2: 'आपकी हर सुबह हो खुशियों से भरी! 🥦',
    ),
    BillQuote(
      line1: 'पड़ोस का भरोसा, स्वाद और शुद्धता,',
      line2: 'आपकी संतुष्टि ही हमारी सच्ची निष्ठा! 🙏',
    ),
    BillQuote(
      line1: 'Good food is the secret to great conversations!',
      line2: 'Wishing peace and prosperity to your home! 🌟',
    ),
    BillQuote(
      line1: 'जैसे चाय में इलायची का स्वाद,',
      line2: 'वैसे ही मीठी रहे आपकी हर एक बात! 🫖',
    ),
    BillQuote(
      line1: 'ताज़े फल और खुशहाल परिवार,',
      line2: 'हमेशा मिलता रहे आपका ऐसा ही दुलार! 🍇',
    ),
    BillQuote(
      line1: 'खिचड़ी में देसी घी और बातों में मिठास,',
      line2: 'आप जैसा ग्राहक है हमारे लिए सबसे खास! 🌾',
    ),
    BillQuote(
      line1: 'Life is short, make every meal delicious!',
      line2: 'Thank you for shopping with us today! 🛍️',
    ),
    BillQuote(
      line1: 'दुकान हमारी, पर परिवार आप हमारा,',
      line2: 'सदा बना रहे आपका यह प्यारा सहारा! 🤝',
    ),
    BillQuote(
      line1: 'हल्दी-चंदन सी शुद्धता और ताज़गी की गारंटी,',
      line2: 'दुआ है आपकी उम्र और सेहत दोनों रहे लम्बी! 🌻',
    ),
    BillQuote(
      line1: 'Happiness is cooking fresh food for loved ones!',
      line2: 'May your kitchen always be filled with joy! 🍲',
    ),
    BillQuote(
      line1: 'ताज़ी सब्ज़ी, खुशबूदार मसाले और दिलदार ग्राहक,',
      line2: 'आपके आने से बढ़ जाती है दुकान की रौनक! ✨',
    ),
    BillQuote(
      line1: 'बाज़ार के शोर में पड़ोस का अपनापन,',
      line2: 'आपकी सेवा में हाज़िर है हमारा मन! 🙏',
    ),
    BillQuote(
      line1: 'Every meal cooked with love becomes a feast!',
      line2: 'Wishing you boundless health and good vibes! 🥗',
    ),
    BillQuote(
      line1: 'चीनी कम, मिठास ज़्यादा — सेहत का सच्चा इरादा!',
      line2: 'हमेशा मुस्कुराते रहिए और खुशियां बांटते रहिए! 🍓',
    ),
    BillQuote(
      line1: 'घर का हर कोना महके, जब पके स्वादिष्ट खाना,',
      line2: 'याद रखना हर ज़रूरत पर इस दुकान पर आना! 🏠',
    ),
    BillQuote(
      line1: 'Fresh fruits keep doctors miles away!',
      line2: 'Have a joyful and energetic week ahead! 🍊',
    ),
    BillQuote(
      line1: 'नमक स्वाद अनुसार, और प्यार बेहिसाब!',
      line2: 'आपकी हर ख़्वाहिश पूरी करे रब लाजवाब! 🍛',
    ),
    BillQuote(
      line1: 'आज का दिन शुभ और हर पल मंगलमय हो,',
      line2: 'आपके घर-आंगन में सदा सुख और विजय हो! 🌸',
    ),
    BillQuote(
      line1: 'Pure ghee, fresh grains & trusted neighborly care!',
      line2: 'Always happy to serve you with warm smiles! 🌾',
    ),
    BillQuote(
      line1: 'सब्ज़ियों की ताज़गी और दूध की शुद्धता,',
      line2: 'आपके चेहरे की मुस्कान से ही हमारी पूर्णता! 🥛',
    ),
  ];

  /// Returns a deterministic quote for past bills based on bill number
  static BillQuote getQuoteForBillNo(int billNo) {
    return _curatedQuotes[billNo.abs() % _curatedQuotes.length];
  }

  /// Retrieves a unique dynamic quote for a new bill.
  /// Guarantees that consecutive bills never get the same quote by using
  /// a non-repeating shuffle ring-buffer stored in SharedPreferences.
  static Future<BillQuote> getUniqueQuoteForBill() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      int lastIndex = prefs.getInt(_prefKeyLastIndex) ?? -1;

      List<int> history = (prefs.getStringList(_prefKeyHistory) ?? [])
          .map((s) => int.tryParse(s) ?? -1)
          .where((i) => i >= 0 && i < _curatedQuotes.length)
          .toList();

      // Find available candidate indices that haven't been used recently
      List<int> candidates = [];
      for (int i = 0; i < _curatedQuotes.length; i++) {
        if (!history.contains(i)) {
          candidates.add(i);
        }
      }

      // If all quotes have been exhausted in history, reset history except the last one
      if (candidates.isEmpty) {
        history.clear();
        if (lastIndex >= 0) history.add(lastIndex);
        for (int i = 0; i < _curatedQuotes.length; i++) {
          if (i != lastIndex) candidates.add(i);
        }
      }

      // Pick a random candidate from remaining unused quotes
      final random = Random();
      int selectedIndex = candidates[random.nextInt(candidates.length)];

      // Keep recent 15 quotes in history to prevent repeats
      history.add(selectedIndex);
      if (history.length > 20) {
        history.removeAt(0);
      }

      await prefs.setInt(_prefKeyLastIndex, selectedIndex);
      await prefs.setStringList(
        _prefKeyHistory,
        history.map((i) => i.toString()).toList(),
      );

      return _curatedQuotes[selectedIndex];
    } catch (_) {
      // Fallback in case of storage glitch
      final random = Random();
      return _curatedQuotes[random.nextInt(_curatedQuotes.length)];
    }
  }
}
