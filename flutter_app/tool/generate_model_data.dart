import 'dart:convert';
import 'dart:io';

void main() {
  final jsonFile = File('assets/data/ai_vision_model.json');
  final data = jsonDecode(jsonFile.readAsStringSync());
  final classes = data['classes'] as List;

  final buffer = StringBuffer();
  buffer.writeln('library;');
  buffer.writeln();
  buffer.writeln('/// Pre-trained Centroid Weights extracted from Yadav VeggiFruit Store Dataset (336 images).');
  buffer.writeln('/// 31 dimensions: 16 Hue bins, 4 Sat bins, 4 Val bins, 6 Dom colors, 1 Texture.');
  buffer.writeln();
  buffer.writeln('class AiVisionModelData {');
  buffer.writeln('  AiVisionModelData._();');
  buffer.writeln();
  buffer.writeln('  static const int vectorDimensions = 31;');
  buffer.writeln('  static const int totalClasses = ${classes.length};');
  buffer.writeln();
  buffer.writeln('  static const Map<String, List<double>> centroids = {');

  for (final c in classes) {
    final classId = c['class_id'];
    final vector = (c['vector'] as List).map((v) => (v as num).toDouble()).toList();
    buffer.writeln('    \'$classId\': $vector,');
  }

  buffer.writeln('  };');
  buffer.writeln('}');

  File('lib/core/services/ai_vision_model_data.dart').writeAsStringSync(buffer.toString());
  print('✅ Generated lib/core/services/ai_vision_model_data.dart with ${classes.length} class centroids!');
}

