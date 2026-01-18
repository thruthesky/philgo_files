// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

/// travel_spots.json 파일에서 모든 imageUrl을 확인하고,
/// 접근 불가한 이미지 URL을 리스트업하는 Dart 스크립트입니다.
///
/// 검증 항목:
/// 1. HTTP 상태 코드 확인 (200-399 범위)
/// 2. Content-Type 헤더가 이미지 타입인지 확인 (image/jpeg, image/png 등)
///
/// 사용법:
/// ```shell
/// cd /Users/thruthesky/apps/flutter/philgo_app
/// dart run lib/philgo_files/scripts/check_image_urls.dart
/// ```
///
/// 결과:
/// - 성공한 이미지 URL은 OK로 표시 (이미지 타입 포함)
/// - 실패한 이미지 URL은 FAILED로 표시되며, 에러 코드와 함께 출력
/// - HTTP 429 에러는 재시도 큐에 추가
/// - 최종 결과는 실패한 URL 목록을 별도로 출력

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

/// 이미지 URL 검증 결과
class ImageCheckResult {
  final int index;
  final String name;
  final String englishName;
  final String imageUrl;
  final bool isValid;
  final String? error;
  final int statusCode;
  final String contentType;
  final bool isRateLimited; // 429 에러인 경우

  ImageCheckResult({
    required this.index,
    required this.name,
    required this.englishName,
    required this.imageUrl,
    required this.isValid,
    this.error,
    required this.statusCode,
    required this.contentType,
    this.isRateLimited = false,
  });

  Map<String, dynamic> toJson() => {
    'index': index,
    'name': name,
    'englishName': englishName,
    'imageUrl': imageUrl,
    'error': error,
    'statusCode': statusCode,
    'contentType': contentType,
    'isRateLimited': isRateLimited,
  };
}

/// 단일 URL 검증 함수
Future<ImageCheckResult> checkImageUrl({
  required HttpClient httpClient,
  required int index,
  required String name,
  required String englishName,
  required String imageUrl,
}) async {
  if (imageUrl.isEmpty) {
    return ImageCheckResult(
      index: index,
      name: name,
      englishName: englishName,
      imageUrl: imageUrl,
      isValid: false,
      error: 'URL이 비어있음',
      statusCode: 0,
      contentType: '',
    );
  }

  try {
    final uri = Uri.parse(imageUrl);
    final request = await httpClient.headUrl(uri);
    request.headers.add(
      'User-Agent',
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    );
    final response = await request.close();

    final contentType =
        response.headers.contentType?.mimeType ??
        response.headers.value('content-type') ??
        '';

    await response.drain();

    // HTTP 429 (Rate Limited) 처리
    if (response.statusCode == 429) {
      return ImageCheckResult(
        index: index,
        name: name,
        englishName: englishName,
        imageUrl: imageUrl,
        isValid: false,
        error: 'HTTP 429 (Rate Limited)',
        statusCode: 429,
        contentType: contentType,
        isRateLimited: true,
      );
    }

    if (response.statusCode >= 200 && response.statusCode < 400) {
      if (isImageContentType(contentType)) {
        return ImageCheckResult(
          index: index,
          name: name,
          englishName: englishName,
          imageUrl: imageUrl,
          isValid: true,
          statusCode: response.statusCode,
          contentType: contentType,
        );
      } else {
        return ImageCheckResult(
          index: index,
          name: name,
          englishName: englishName,
          imageUrl: imageUrl,
          isValid: false,
          error: 'Content-Type이 이미지가 아님: $contentType',
          statusCode: response.statusCode,
          contentType: contentType,
        );
      }
    } else {
      return ImageCheckResult(
        index: index,
        name: name,
        englishName: englishName,
        imageUrl: imageUrl,
        isValid: false,
        error: 'HTTP ${response.statusCode}',
        statusCode: response.statusCode,
        contentType: contentType,
      );
    }
  } catch (e) {
    return ImageCheckResult(
      index: index,
      name: name,
      englishName: englishName,
      imageUrl: imageUrl,
      isValid: false,
      error: e.toString(),
      statusCode: 0,
      contentType: '',
    );
  }
}

void main() async {
  final jsonFilePath = 'lib/philgo_files/travel/travel_spots.json';

  print('======================================');
  print('📋 Travel Spots 이미지 URL 검증 도구');
  print('======================================\n');
  print('검증 항목:');
  print('  1. HTTP 상태 코드 (200-399)');
  print('  2. Content-Type이 이미지 타입인지 확인');
  print('  3. HTTP 429 에러는 별도 처리 (Rate Limited)');
  print('');

  final file = File(jsonFilePath);
  if (!file.existsSync()) {
    print('❌ 오류: $jsonFilePath 파일을 찾을 수 없습니다.');
    exit(1);
  }

  final jsonString = file.readAsStringSync();
  final List<dynamic> travelSpots = jsonDecode(jsonString);

  print('📊 총 ${travelSpots.length}개의 여행지를 확인합니다.\n');

  final List<ImageCheckResult> successUrls = [];
  final List<ImageCheckResult> failedUrls = [];
  final List<ImageCheckResult> rateLimitedUrls = [];

  final httpClient = HttpClient();
  httpClient.connectionTimeout = const Duration(seconds: 15);

  // 첫 번째 패스: 모든 URL 확인 (딜레이 500ms)
  for (int i = 0; i < travelSpots.length; i++) {
    final spot = travelSpots[i];
    final String name = spot['name'] ?? '이름 없음';
    final String englishName = spot['english name'] ?? '';
    final String imageUrl = spot['imageUrl'] ?? '';

    final result = await checkImageUrl(
      httpClient: httpClient,
      index: i,
      name: name,
      englishName: englishName,
      imageUrl: imageUrl,
    );

    if (result.isValid) {
      print(
        '✅ [${i + 1}/${travelSpots.length}] $name: OK (HTTP ${result.statusCode}, ${result.contentType})',
      );
      successUrls.add(result);
    } else if (result.isRateLimited) {
      print('⏳ [${i + 1}/${travelSpots.length}] $name: RATE LIMITED (재시도 예정)');
      rateLimitedUrls.add(result);
    } else if (result.imageUrl.isEmpty) {
      print('⚠️  [${i + 1}/${travelSpots.length}] $name: 이미지 URL 없음');
      failedUrls.add(result);
    } else {
      print('❌ [${i + 1}/${travelSpots.length}] $name: ${result.error}');
      failedUrls.add(result);
    }

    // Wikipedia 서버 레이트 리미팅 방지
    await Future.delayed(const Duration(milliseconds: 500));
  }

  // 두 번째 패스: 429 에러난 URL 재시도 (딜레이 2초)
  if (rateLimitedUrls.isNotEmpty) {
    print('\n======================================');
    print('🔄 429 에러 URL 재시도 (${rateLimitedUrls.length}개)');
    print('   딜레이: 2초');
    print('======================================\n');

    for (int i = 0; i < rateLimitedUrls.length; i++) {
      final item = rateLimitedUrls[i];

      final result = await checkImageUrl(
        httpClient: httpClient,
        index: item.index,
        name: item.name,
        englishName: item.englishName,
        imageUrl: item.imageUrl,
      );

      if (result.isValid) {
        print(
          '✅ [${i + 1}/${rateLimitedUrls.length}] ${item.name}: OK (재시도 성공)',
        );
        successUrls.add(result);
      } else if (result.isRateLimited) {
        print(
          '⏳ [${i + 1}/${rateLimitedUrls.length}] ${item.name}: 여전히 RATE LIMITED',
        );
        failedUrls.add(result);
      } else {
        print(
          '❌ [${i + 1}/${rateLimitedUrls.length}] ${item.name}: ${result.error}',
        );
        failedUrls.add(result);
      }

      await Future.delayed(const Duration(seconds: 2));
    }
  }

  httpClient.close();

  // 결과 출력
  print('\n======================================');
  print('📊 검증 결과 요약');
  print('======================================');
  print('✅ 성공 (유효한 이미지): ${successUrls.length}개');
  print('❌ 실패: ${failedUrls.length}개');

  // 실패 원인별 분류
  final emptyUrls = failedUrls.where((r) => r.imageUrl.isEmpty).length;
  final httpErrors = failedUrls
      .where((r) => r.statusCode >= 400 && r.statusCode != 429)
      .length;
  final rateLimited = failedUrls.where((r) => r.isRateLimited).length;
  final contentTypeErrors = failedUrls
      .where((r) => r.error?.contains('Content-Type') ?? false)
      .length;
  final otherErrors =
      failedUrls.length -
      emptyUrls -
      httpErrors -
      rateLimited -
      contentTypeErrors;

  print('   └─ URL 없음: $emptyUrls개');
  print('   └─ HTTP 에러: $httpErrors개');
  print('   └─ Rate Limited (429): $rateLimited개');
  print('   └─ Content-Type 에러: $contentTypeErrors개');
  print('   └─ 기타 에러: $otherErrors개');
  print('');

  if (failedUrls.isNotEmpty) {
    // 실제로 문제가 있는 URL만 필터링 (429 제외)
    final realFailedUrls = failedUrls.where((r) => !r.isRateLimited).toList();

    if (realFailedUrls.isNotEmpty) {
      print('======================================');
      print('❌ 실패한 이미지 URL 목록 (429 제외)');
      print('======================================\n');

      for (final item in realFailedUrls) {
        print('📍 [${item.index}] ${item.name}');
        print('   영문명: ${item.englishName}');
        print('   URL: ${item.imageUrl}');
        print('   에러: ${item.error}');
        if (item.contentType.isNotEmpty) {
          print('   Content-Type: ${item.contentType}');
        }
        print('   ─────────────────────────────────────');
      }
    }

    // 실패한 URL을 JSON 파일로 저장
    final failedJsonFile = File('lib/philgo_files/scripts/failed_image_urls.json');
    failedJsonFile.writeAsStringSync(
      const JsonEncoder.withIndent(
        '  ',
      ).convert(failedUrls.map((r) => r.toJson()).toList()),
    );
    print('\n📁 실패한 URL 목록이 lib/philgo_files/scripts/failed_image_urls.json에 저장되었습니다.');

    // 429 제외한 실제 실패 URL만 별도 저장
    if (realFailedUrls.isNotEmpty) {
      final realFailedJsonFile = File(
        'lib/philgo_files/scripts/real_failed_image_urls.json',
      );
      realFailedJsonFile.writeAsStringSync(
        const JsonEncoder.withIndent(
          '  ',
        ).convert(realFailedUrls.map((r) => r.toJson()).toList()),
      );
      print(
        '📁 실제 실패한 URL 목록이 lib/philgo_files/scripts/real_failed_image_urls.json에 저장되었습니다.',
      );
    }
  } else {
    print('🎉 모든 이미지 URL이 정상적으로 접근 가능하고 유효한 이미지입니다!');
  }
}
