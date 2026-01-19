// texts 필드의 품질을 분석하는 스크립트
// - texts가 비어있는 항목
// - texts의 description이 짧은 항목 (50자 미만)
// - texts 항목 수가 적은 항목 (4개 미만)

import 'dart:convert';
import 'dart:io';

void main() async {
  // JSON 파일 읽기
  final jsonFile = File('lib/philgo_files/travel/travel_spots.json');
  final jsonString = await jsonFile.readAsString();
  final List<dynamic> spots = jsonDecode(jsonString);

  // 문제 항목 분류
  List<Map<String, dynamic>> emptyTexts = [];
  List<Map<String, dynamic>> fewTexts = []; // 4개 미만
  List<Map<String, dynamic>> shortDescription = []; // texts 내 description이 짧은 항목

  for (int i = 0; i < spots.length; i++) {
    final spot = spots[i];
    final name = spot['name'] ?? '';
    final englishName = spot['english name'] ?? '';
    final province = spot['province'] ?? '';
    final List<dynamic> texts = spot['texts'] ?? [];

    // texts가 비어있는 경우
    if (texts.isEmpty) {
      emptyTexts.add({
        'index': i,
        'name': name,
        'englishName': englishName,
        'province': province,
      });
      continue;
    }

    // texts 항목 수가 4개 미만인 경우
    if (texts.length < 4) {
      fewTexts.add({
        'index': i,
        'name': name,
        'englishName': englishName,
        'province': province,
        'textsCount': texts.length,
      });
    }

    // texts 문자열의 총 길이 계산 (문자열 또는 Map 형식 모두 지원)
    int totalTextsLength = 0;
    for (var text in texts) {
      if (text is String) {
        totalTextsLength += text.length;
      } else if (text is Map) {
        // Map 형식: {'title': '...', 'description': '...'}
        final title = text['title'] ?? '';
        final desc = text['description'] ?? '';
        totalTextsLength += (title as String).length + (desc as String).length;
      }
    }

    // 전체 texts 내용이 부실한 경우 (총 길이가 500자 미만)
    if (totalTextsLength < 500) {
      shortDescription.add({
        'index': i,
        'name': name,
        'englishName': englishName,
        'province': province,
        'textsCount': texts.length,
        'totalTextsLength': totalTextsLength,
      });
    }
  }

  // 결과 출력
  print('======================================');
  print('📊 texts 필드 품질 분석 결과');
  print('======================================\n');

  print('총 항목 수: ${spots.length}개\n');

  print('📝 texts가 비어있는 항목: ${emptyTexts.length}개');
  print('📝 texts 항목 수가 4개 미만: ${fewTexts.length}개');
  print('📝 texts 내용이 부실한 항목 (총 500자 미만): ${shortDescription.length}개\n');

  // texts가 비어있는 항목 (상위 10개)
  if (emptyTexts.isNotEmpty) {
    print('======================================');
    print('🔴 texts가 비어있는 항목');
    print('======================================');
    for (int i = 0; i < emptyTexts.length && i < 10; i++) {
      final item = emptyTexts[i];
      print('[${item['index']}] ${item['name']} (${item['englishName']})');
      print('   province: ${item['province']}');
    }
    if (emptyTexts.length > 10) {
      print('   ... 외 ${emptyTexts.length - 10}개');
    }
    print('');
  }

  // texts 항목 수가 4개 미만인 항목 (상위 20개)
  if (fewTexts.isNotEmpty) {
    print('======================================');
    print('🟡 texts 항목 수가 4개 미만인 항목 (상위 20개)');
    print('======================================');
    for (int i = 0; i < fewTexts.length && i < 20; i++) {
      final item = fewTexts[i];
      print('[${item['index']}] ${item['name']} (${item['englishName']}) - ${item['textsCount']}개');
      print('   province: ${item['province']}');
    }
    if (fewTexts.length > 20) {
      print('   ... 외 ${fewTexts.length - 20}개');
    }
    print('');
  }

  // texts 내용이 부실한 항목 (상위 30개)
  if (shortDescription.isNotEmpty) {
    print('======================================');
    print('🟠 texts 내용이 부실한 항목 (총 500자 미만, 상위 30개)');
    print('======================================');
    // 길이 순으로 정렬
    shortDescription.sort((a, b) => (a['totalTextsLength'] as int).compareTo(b['totalTextsLength'] as int));
    for (int i = 0; i < shortDescription.length && i < 30; i++) {
      final item = shortDescription[i];
      print('[${item['index']}] ${item['name']} (${item['englishName']})');
      print('   texts 수: ${item['textsCount']}개, 총 길이: ${item['totalTextsLength']}자');
      print('   province: ${item['province']}');
    }
    if (shortDescription.length > 30) {
      print('   ... 외 ${shortDescription.length - 30}개');
    }
    print('');
  }

  // 결과를 JSON 파일로 저장
  final outputData = {
    'generated_at': DateTime.now().toIso8601String(),
    'total_spots': spots.length,
    'empty_texts': emptyTexts,
    'few_texts': fewTexts,
    'short_description': shortDescription,
  };

  final outputFile = File('lib/philgo_files/scripts/texts_quality_analysis.json');
  await outputFile.writeAsString(
    const JsonEncoder.withIndent('    ').convert(outputData),
  );
  print('======================================');
  print('📁 상세 결과가 lib/philgo_files/scripts/texts_quality_analysis.json에 저장되었습니다.');
  print('======================================');
}
