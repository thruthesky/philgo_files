import 'dart:convert';
import 'dart:io';

/// texts 항목에 이모지가 없는 여행 아이템을 찾는 스크립트
///
/// texts 형식:
/// - 좋은 형식: 문자열 배열 ["# 🌹 제목...", "## 📌 요약...", ...]
/// - 부실한 형식: 객체 배열 [{"title": "...", "description": "..."}, ...]
void main() {
  final jsonFile = File('lib/philgo_files/travel/travel_spots.json');
  final jsonString = jsonFile.readAsStringSync();
  final List<dynamic> spots = jsonDecode(jsonString);

  // 이모지 감지를 위한 정규표현식 (일반적인 이모지 범위)
  final emojiRegex = RegExp(
    r'[\u{1F300}-\u{1F9FF}]|[\u{2600}-\u{26FF}]|[\u{2700}-\u{27BF}]|[\u{1F600}-\u{1F64F}]|[\u{1F680}-\u{1F6FF}]|[\u{1F1E0}-\u{1F1FF}]|[\u{2300}-\u{23FF}]|[\u{2B50}]|[\u{2934}-\u{2935}]|[\u{25AA}-\u{25AB}]|[\u{25B6}]|[\u{25C0}]|[\u{25FB}-\u{25FE}]|[\u{2614}-\u{2615}]|[\u{2648}-\u{2653}]|[\u{267F}]|[\u{2693}]|[\u{26A1}]|[\u{26AA}-\u{26AB}]|[\u{26BD}-\u{26BE}]|[\u{26C4}-\u{26C5}]|[\u{26CE}]|[\u{26D4}]|[\u{26EA}]|[\u{26F2}-\u{26F3}]|[\u{26F5}]|[\u{26FA}]|[\u{26FD}]|[\u{2702}]|[\u{2705}]|[\u{2708}-\u{270D}]|[\u{270F}]|[\u{2712}]|[\u{2714}]|[\u{2716}]|[\u{271D}]|[\u{2721}]|[\u{2728}]|[\u{2733}-\u{2734}]|[\u{2744}]|[\u{2747}]|[\u{274C}]|[\u{274E}]|[\u{2753}-\u{2755}]|[\u{2757}]|[\u{2763}-\u{2764}]|[\u{2795}-\u{2797}]|[\u{27A1}]|[\u{27B0}]|[\u{1F004}]|[\u{1F0CF}]|[\u{1F170}-\u{1F171}]|[\u{1F17E}-\u{1F17F}]|[\u{1F18E}]|[\u{1F191}-\u{1F19A}]|[\u{1F1E6}-\u{1F1FF}]|[\u{1F201}-\u{1F202}]|[\u{1F21A}]|[\u{1F22F}]|[\u{1F232}-\u{1F23A}]|[\u{1F250}-\u{1F251}]',
    unicode: true,
  );

  final List<Map<String, dynamic>> noEmojiItems = [];
  final List<Map<String, dynamic>> objectFormatItems = []; // 객체 배열 형식 항목

  for (int i = 0; i < spots.length; i++) {
    final spot = spots[i] as Map<String, dynamic>;
    final texts = spot['texts'] as List<dynamic>?;

    if (texts == null || texts.isEmpty) {
      continue; // texts가 없거나 비어있는 항목은 건너뜀
    }

    // texts 형식 확인 및 이모지 검사
    String allTexts = '';
    bool isObjectFormat = false;

    for (var textItem in texts) {
      if (textItem is String) {
        // 문자열 배열 형식 (좋은 형식)
        allTexts += textItem;
      } else if (textItem is Map) {
        // 객체 배열 형식 (부실한 형식)
        isObjectFormat = true;
        allTexts += (textItem['title'] ?? '') + ' ' + (textItem['description'] ?? '');
      }
    }

    // 객체 형식인 항목은 별도 추적
    if (isObjectFormat) {
      objectFormatItems.add({
        'index': i,
        'name': spot['name'],
        'englishName': spot['englishName'] ?? spot['english name'],
        'city': spot['city'],
        'province': spot['province'],
      });
    }

    // 이모지가 없는 항목 추적
    if (!emojiRegex.hasMatch(allTexts)) {
      noEmojiItems.add({
        'index': i,
        'name': spot['name'],
        'englishName': spot['englishName'] ?? spot['english name'],
        'city': spot['city'],
        'province': spot['province'],
        'isObjectFormat': isObjectFormat,
      });
    }
  }

  print('=== 분석 결과 요약 ===');
  print('전체 항목 수: ${spots.length}');
  print('객체 배열 형식 (부실) 항목 수: ${objectFormatItems.length}');
  print('이모지 없는 항목 수: ${noEmojiItems.length}');
  print('');

  print('=== 객체 배열 형식 (부실) 항목 목록 ===');
  for (var item in objectFormatItems) {
    print('${item['index']}: ${item['name']} | ${item['englishName']} | ${item['city']}, ${item['province']}');
  }

  print('\n=== 이모지 없는 항목 목록 (문자열 형식만) ===');
  final stringFormatNoEmoji = noEmojiItems.where((item) => item['isObjectFormat'] != true).toList();
  print('총 ${stringFormatNoEmoji.length}개 항목\n');
  for (var item in stringFormatNoEmoji) {
    print('${item['index']}: ${item['name']} | ${item['englishName']} | ${item['city']}, ${item['province']}');
  }
}
