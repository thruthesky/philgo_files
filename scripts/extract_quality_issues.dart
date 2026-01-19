// 품질 문제가 있는 항목들을 유형별로 추출하는 스크립트
// Type C: description 부실 (50자 미만)
// Type D: city/province 누락
// Type F: title 부실 (10자 미만)

import 'dart:convert';
import 'dart:io';

void main() async {
  // JSON 파일 읽기
  final jsonFile =
      File('lib/philgo_files/travel/travel_spots.json');
  final jsonString = await jsonFile.readAsString();
  final List<dynamic> spots = jsonDecode(jsonString);

  // 유형별 문제 항목 저장
  List<Map<String, dynamic>> typeCIssues = []; // description 부실
  List<Map<String, dynamic>> typeDIssues = []; // location 누락
  List<Map<String, dynamic>> typeFIssues = []; // title 부실

  for (int i = 0; i < spots.length; i++) {
    final spot = spots[i];
    final name = spot['name'] ?? '';
    final englishName = spot['english name'] ?? '';
    final title = spot['title'] ?? '';
    final description = spot['description'] ?? '';
    final city = spot['city'] ?? '';
    final province = spot['province'] ?? '';

    // Type C: description 부실 (50자 미만)
    if (description.length < 50) {
      typeCIssues.add({
        'index': i,
        'name': name,
        'englishName': englishName,
        'province': province,
        'currentDescription': description,
        'descriptionLength': description.length,
      });
    }

    // Type D: city 또는 province 누락
    if (city.isEmpty || province.isEmpty) {
      typeDIssues.add({
        'index': i,
        'name': name,
        'englishName': englishName,
        'currentCity': city,
        'currentProvince': province,
        'cityEmpty': city.isEmpty,
        'provinceEmpty': province.isEmpty,
      });
    }

    // Type F: title 부실 (10자 미만)
    if (title.length < 10) {
      typeFIssues.add({
        'index': i,
        'name': name,
        'englishName': englishName,
        'province': province,
        'currentTitle': title,
        'titleLength': title.length,
      });
    }
  }

  // 결과 출력
  print('======================================');
  print('📊 품질 문제 항목 추출 결과');
  print('======================================\n');

  print('📝 Type C (description 부실, 50자 미만): ${typeCIssues.length}개');
  print('📍 Type D (city/province 누락): ${typeDIssues.length}개');
  print('📌 Type F (title 부실, 10자 미만): ${typeFIssues.length}개');
  print('');

  // 중복 제거한 총 문제 항목 수
  Set<int> allProblemIndices = {};
  for (var item in typeCIssues) {
    allProblemIndices.add(item['index']);
  }
  for (var item in typeDIssues) {
    allProblemIndices.add(item['index']);
  }
  for (var item in typeFIssues) {
    allProblemIndices.add(item['index']);
  }
  print('총 문제 항목 수 (중복 제거): ${allProblemIndices.length}개\n');

  // Type C 상세 (상위 30개)
  print('======================================');
  print('📝 Type C: description 부실 항목 (상위 30개)');
  print('======================================');
  for (int i = 0; i < typeCIssues.length && i < 30; i++) {
    final item = typeCIssues[i];
    print(
        '[${item['index']}] ${item['name']} (${item['englishName']}) - ${item['descriptionLength']}자');
    print('   현재: ${item['currentDescription']}');
    print('');
  }

  // Type D 상세 (상위 20개)
  print('\n======================================');
  print('📍 Type D: city/province 누락 항목 (상위 20개)');
  print('======================================');
  for (int i = 0; i < typeDIssues.length && i < 20; i++) {
    final item = typeDIssues[i];
    print(
        '[${item['index']}] ${item['name']} (${item['englishName']})');
    print('   city: "${item['currentCity']}" (${item['cityEmpty'] ? '누락' : 'OK'})');
    print('   province: "${item['currentProvince']}" (${item['provinceEmpty'] ? '누락' : 'OK'})');
    print('');
  }

  // Type F 상세 (상위 30개)
  print('\n======================================');
  print('📌 Type F: title 부실 항목 (상위 30개)');
  print('======================================');
  for (int i = 0; i < typeFIssues.length && i < 30; i++) {
    final item = typeFIssues[i];
    print(
        '[${item['index']}] ${item['name']} (${item['englishName']}) - ${item['titleLength']}자');
    print('   현재 title: "${item['currentTitle']}"');
    print('');
  }

  // 결과를 JSON 파일로 저장
  final outputData = {
    'generated_at': DateTime.now().toIso8601String(),
    'type_c_issues': typeCIssues,
    'type_d_issues': typeDIssues,
    'type_f_issues': typeFIssues,
    'all_problem_indices': allProblemIndices.toList()..sort(),
  };

  final outputFile =
      File('lib/philgo_files/scripts/quality_issues_detail.json');
  await outputFile.writeAsString(
    const JsonEncoder.withIndent('    ').convert(outputData),
  );
  print('\n======================================');
  print('📁 상세 결과가 lib/philgo_files/scripts/quality_issues_detail.json에 저장되었습니다.');
  print('======================================');
}
