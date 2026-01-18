// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

/// travel_spots.json 파일에서 특정 여행지의 imageUrl을 업데이트하는 Dart 스크립트입니다.
///
/// 사용법:
/// ```shell
/// cd /Users/thruthesky/apps/flutter/philgo_app
/// dart run lib/philgo_files/scripts/update_image_url.dart <인덱스 또는 이름> <새로운 이미지 URL>
/// ```
///
/// 예시:
/// ```shell
/// dart run lib/philgo_files/scripts/update_image_url.dart 0 "https://example.com/new-image.jpg"
/// dart run lib/philgo_files/scripts/update_image_url.dart "바나웨 라이스 테라스" "https://example.com/new-image.jpg"
/// ```
///
/// 주의: 인덱스는 0부터 시작합니다.

/// 허용되는 이미지 Content-Type 목록
const List<String> validImageContentTypes = [
  'image/jpeg',
  'image/jpg',
  'image/png',
  'image/gif',
  'image/webp',
  'image/svg+xml',
  'image/bmp',
  'image/tiff',
  'image/x-icon',
  'image/vnd.microsoft.icon',
];

/// Content-Type이 이미지 타입인지 확인
bool isImageContentType(String? contentType) {
  if (contentType == null || contentType.isEmpty) {
    return false;
  }
  // Content-Type에서 charset 등의 추가 정보 제거
  final mimeType = contentType.split(';').first.trim().toLowerCase();

  // image/로 시작하면 이미지로 간주
  if (mimeType.startsWith('image/')) {
    return true;
  }

  return validImageContentTypes.contains(mimeType);
}

void main(List<String> args) async {
  // travel_spots.json 파일 경로
  final jsonFilePath = 'lib/philgo_files/travel/travel_spots.json';

  print('======================================');
  print('📋 Travel Spots 이미지 URL 업데이트 도구');
  print('======================================\n');

  // 인자 확인
  if (args.length < 2) {
    print(
      '사용법: dart run lib/philgo_files/scripts/update_image_url.dart <인덱스 또는 이름> <새로운 이미지 URL>',
    );
    print('');
    print('예시:');
    print(
      '  dart run lib/philgo_files/scripts/update_image_url.dart 0 "https://example.com/new-image.jpg"',
    );
    print(
      '  dart run lib/philgo_files/scripts/update_image_url.dart "바나웨 라이스 테라스" "https://example.com/new-image.jpg"',
    );
    exit(1);
  }

  final String identifier = args[0];
  final String newImageUrl = args[1];

  // JSON 파일 읽기
  final file = File(jsonFilePath);
  if (!file.existsSync()) {
    print('❌ 오류: $jsonFilePath 파일을 찾을 수 없습니다.');
    print('스크립트를 프로젝트 루트 디렉토리에서 실행해주세요.');
    exit(1);
  }

  final jsonString = file.readAsStringSync();
  final List<dynamic> travelSpots = jsonDecode(jsonString);

  // 인덱스 또는 이름으로 여행지 찾기
  int? targetIndex;

  // 숫자인지 확인
  final parsedIndex = int.tryParse(identifier);
  if (parsedIndex != null) {
    // 인덱스로 찾기
    if (parsedIndex < 0 || parsedIndex >= travelSpots.length) {
      print(
        '❌ 오류: 인덱스 $parsedIndex가 유효하지 않습니다. (0-${travelSpots.length - 1} 범위)',
      );
      exit(1);
    }
    targetIndex = parsedIndex;
  } else {
    // 이름으로 찾기
    for (int i = 0; i < travelSpots.length; i++) {
      final spot = travelSpots[i];
      final String name = spot['name'] ?? '';
      final String englishName = spot['english name'] ?? '';

      if (name == identifier || englishName == identifier) {
        targetIndex = i;
        break;
      }
    }

    if (targetIndex == null) {
      print('❌ 오류: "$identifier" 이름의 여행지를 찾을 수 없습니다.');
      exit(1);
    }
  }

  // 타겟 여행지 정보
  final targetSpot = travelSpots[targetIndex];
  final String name = targetSpot['name'] ?? '이름 없음';
  final String englishName = targetSpot['english name'] ?? '';
  final String oldImageUrl = targetSpot['imageUrl'] ?? '';

  print('📍 대상 여행지 정보:');
  print('   인덱스: $targetIndex');
  print('   이름: $name');
  print('   영문명: $englishName');
  print('   기존 URL: $oldImageUrl');
  print('   새 URL: $newImageUrl');
  print('');

  // 새 이미지 URL 유효성 검증
  print('🔍 새 이미지 URL 접근 가능 여부 및 이미지 타입 확인 중...');

  final httpClient = HttpClient();
  httpClient.connectionTimeout = const Duration(seconds: 10);

  try {
    final uri = Uri.parse(newImageUrl);
    final request = await httpClient.headUrl(uri);
    request.headers.add(
      'User-Agent',
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
    );
    final response = await request.close();

    // Content-Type 헤더 가져오기
    final contentType =
        response.headers.contentType?.mimeType ??
        response.headers.value('content-type') ??
        '';

    await response.drain();

    if (response.statusCode >= 200 && response.statusCode < 400) {
      // Content-Type이 이미지인지 확인
      if (isImageContentType(contentType)) {
        print(
          '✅ 새 이미지 URL이 유효합니다. (HTTP ${response.statusCode}, $contentType)',
        );
      } else {
        print(
          '⚠️  경고: Content-Type이 이미지가 아닙니다. (HTTP ${response.statusCode}, Content-Type: $contentType)',
        );
        print('계속 진행하시겠습니까? (y/n)');

        final input = stdin.readLineSync();
        if (input?.toLowerCase() != 'y') {
          print('❌ 업데이트가 취소되었습니다.');
          httpClient.close();
          exit(0);
        }
      }
    } else {
      print('⚠️  경고: 새 이미지 URL에 접근할 수 없습니다. (HTTP ${response.statusCode})');
      print('계속 진행하시겠습니까? (y/n)');

      final input = stdin.readLineSync();
      if (input?.toLowerCase() != 'y') {
        print('❌ 업데이트가 취소되었습니다.');
        httpClient.close();
        exit(0);
      }
    }
  } catch (e) {
    print('⚠️  경고: 새 이미지 URL 확인 중 오류 발생: $e');
    print('계속 진행하시겠습니까? (y/n)');

    final input = stdin.readLineSync();
    if (input?.toLowerCase() != 'y') {
      print('❌ 업데이트가 취소되었습니다.');
      httpClient.close();
      exit(0);
    }
  }

  httpClient.close();

  // 이미지 URL 업데이트
  travelSpots[targetIndex]['imageUrl'] = newImageUrl;

  // JSON 파일 저장
  final encoder = const JsonEncoder.withIndent('    ');
  final updatedJsonString = encoder.convert(travelSpots);
  file.writeAsStringSync(updatedJsonString);

  print('');
  print('✅ 이미지 URL이 성공적으로 업데이트되었습니다!');
  print('   $jsonFilePath 파일이 수정되었습니다.');
}
