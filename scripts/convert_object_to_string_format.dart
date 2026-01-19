import 'dart:convert';
import 'dart:io';

/// 객체 배열 형식 texts를 이모지 포함 문자열 배열 형식으로 자동 변환
/// 기존 데이터를 최대한 활용하면서 이모지와 마크다운 형식 추가
void main() {
  final jsonFile = File('lib/philgo_files/travel/travel_spots.json');
  final List<dynamic> spots = jsonDecode(jsonFile.readAsStringSync());

  // 카테고리별 이모지 매핑
  final categoryEmojis = {
    '해변': '🏖️',
    '비치': '🏖️',
    '석호': '🌊',
    '라군': '🌊',
    '폭포': '💦',
    '동굴': '🕳️',
    '산': '⛰️',
    '화산': '🌋',
    '호수': '🏞️',
    '섬': '🏝️',
    '다이빙': '🤿',
    '스노클링': '🐠',
    '난파선': '🚢',
    '온천': '♨️',
    '역사': '🏛️',
    '교회': '⛪',
    '사파리': '🦁',
    '야생동물': '🦎',
    '계단식 논': '🌾',
    '테라스': '🌾',
    '서핑': '🏄',
    '공원': '🌳',
    '요새': '🏰',
    '유적': '🏛️',
    '시장': '🛍️',
    '모래 언덕': '🏜️',
    '풍력발전': '💨',
    '절벽': '🧗',
    '전망대': '👀',
  };

  // 기본 섹션 이모지
  final sectionEmojis = ['📌', '🗺️', '💡', '📝', '🎯', '⭐', '🌟', '✨'];

  int convertedCount = 0;

  for (int i = 530; i < spots.length; i++) {
    final spot = spots[i] as Map<String, dynamic>;
    final texts = spot['texts'] as List<dynamic>?;

    if (texts == null || texts.isEmpty) continue;

    // 이미 문자열 형식인지 확인
    if (texts[0] is String) continue;

    // 객체 배열 형식인 경우 변환
    if (texts[0] is Map) {
      final name = spot['name'] ?? '';
      final englishName = spot['englishName'] ?? spot['english name'] ?? '';
      final title = spot['title'] ?? '';
      final description = spot['description'] ?? '';
      final city = spot['city'] ?? '';
      final province = spot['province'] ?? '';
      final category = spot['category'] ?? '';

      // 카테고리에 맞는 이모지 선택
      String mainEmoji = '🏝️'; // 기본 이모지
      for (var key in categoryEmojis.keys) {
        if (name.contains(key) ||
            title.contains(key) ||
            category.contains(key) ||
            description.contains(key)) {
          mainEmoji = categoryEmojis[key]!;
          break;
        }
      }

      // 문자열 배열 형식으로 변환
      List<String> newTexts = [];

      // 첫 번째 섹션: 개요
      final overviewSection = '''# $mainEmoji $name ($englishName)

## 📌 한눈에 보기
- 🏷️ 한 줄 소개: $title
- 🧭 분류: ${category.isNotEmpty ? category : _inferCategory(name, title, description)}
- 📍 위치: $city, $province

$description''';
      newTexts.add(overviewSection);

      // 기존 texts 객체들을 섹션으로 변환
      for (int j = 0; j < texts.length; j++) {
        final textObj = texts[j] as Map;
        final sectionTitle = textObj['title'] ?? '';
        final sectionDesc = textObj['description'] ?? '';

        if (sectionTitle.isEmpty && sectionDesc.isEmpty) continue;

        // 첫 번째 객체는 이미 개요에 포함되어 있을 수 있으므로 스킵
        if (j == 0 && sectionTitle.contains('개요')) continue;

        final emoji = sectionEmojis[j % sectionEmojis.length];
        final section = '''## $emoji $sectionTitle

$sectionDesc''';
        newTexts.add(section);
      }

      // 마지막 섹션: 여행 팁
      newTexts.add('''## 💡 여행 팁

- 🕐 방문 추천 시간: 오전 일찍 방문하면 붐비지 않음
- 📷 사진 포인트: 메인 뷰포인트에서 파노라마 촬영
- 👟 준비물: 편한 신발, 물, 자외선 차단제
- 🎒 추천 코스: 투어 패키지 이용 권장''');

      spot['texts'] = newTexts;
      convertedCount++;
    }
  }

  // 저장
  final encoder = JsonEncoder.withIndent('  ');
  jsonFile.writeAsStringSync(encoder.convert(spots));

  print('✅ 변환 완료: $convertedCount개 항목');
}

/// 이름, 제목, 설명에서 카테고리 추론
String _inferCategory(String name, String title, String description) {
  final text = '$name $title $description'.toLowerCase();
  if (text.contains('비치') || text.contains('beach') || text.contains('해변')) {
    return '해변';
  }
  if (text.contains('라군') || text.contains('lagoon') || text.contains('석호')) {
    return '석호';
  }
  if (text.contains('폭포') || text.contains('falls') || text.contains('waterfall')) {
    return '폭포';
  }
  if (text.contains('동굴') || text.contains('cave')) {
    return '동굴';
  }
  if (text.contains('섬') || text.contains('island')) {
    return '섬';
  }
  if (text.contains('다이빙') || text.contains('diving') || text.contains('렉')) {
    return '다이빙';
  }
  if (text.contains('온천') || text.contains('hot spring')) {
    return '온천';
  }
  if (text.contains('호수') || text.contains('lake')) {
    return '호수';
  }
  return '관광지';
}
