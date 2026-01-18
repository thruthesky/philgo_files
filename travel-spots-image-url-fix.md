# Travel Spots 이미지 URL 검증 및 수정 가이드

이 문서는 `travel_spots.json` 파일의 이미지 URL을 검증하고, 404 에러나 Content-Type 오류가 발생하는 URL을 수정하는 방법을 설명합니다.

## 목차

1. [개요](#개요)
2. [스크립트 파일 위치](#스크립트-파일-위치)
3. [이미지 URL 검증 워크플로우](#이미지-url-검증-워크플로우)
4. [검증 스크립트 상세 설명](#검증-스크립트-상세-설명)
5. [이미지 URL 업데이트 스크립트](#이미지-url-업데이트-스크립트)
6. [에러 유형 및 처리 방법](#에러-유형-및-처리-방법)
7. [실제 사용 예시](#실제-사용-예시)

---

## 개요

`travel_spots.json` 파일에는 각 여행지의 `imageUrl` 필드가 있으며, 이 URL들은 Wikipedia 또는 기타 이미지 호스팅 서비스의 이미지를 참조합니다. 시간이 지남에 따라 다음과 같은 문제가 발생할 수 있습니다:

- **404 Not Found**: 이미지가 삭제되거나 URL이 변경됨
- **403 Forbidden**: 접근 권한 없음
- **Content-Type 오류**: URL이 이미지가 아닌 HTML 페이지 등을 반환
- **429 Too Many Requests**: 서버의 Rate Limiting

이러한 문제를 감지하고 수정하기 위한 스크립트들이 제공됩니다.

---

## 스크립트 파일 위치

모든 관련 스크립트는 다음 경로에 위치합니다:

```
lib/philgo_files/scripts/
├── check_image_urls.dart      # 모든 이미지 URL 유효성 검증
├── update_image_url.dart      # 개별 이미지 URL 업데이트
└── failed_image_urls.json     # 실패한 이미지 URL 기록 (검증 실행 후 생성)
```

---

## 이미지 URL 검증 워크플로우

### 전체 프로세스

```
1. check_image_urls.dart 실행
        ↓
2. 모든 이미지 URL에 HTTP HEAD 요청
        ↓
3. 검증 기준:
   - HTTP 상태 코드 (200-399)
   - Content-Type 헤더 (image/* 타입)
        ↓
4. 실패한 URL을 failed_image_urls.json에 저장
        ↓
5. 각 실패 URL에 대해 수동으로 새 이미지 URL 탐색
        ↓
6. update_image_url.dart로 개별 URL 업데이트
```

---

## 검증 스크립트 상세 설명

### check_image_urls.dart

이 스크립트는 `travel_spots.json`의 모든 이미지 URL을 순회하면서 유효성을 검증합니다.

#### 실행 방법

```bash
cd /Users/thruthesky/apps/flutter/philgo_app
dart run lib/philgo_files/scripts/check_image_urls.dart
```

#### 검증 기준

##### 1. HTTP 상태 코드 검증

```dart
// 성공 범위: 200-399 (2xx 성공, 3xx 리다이렉트)
if (response.statusCode >= 200 && response.statusCode < 400) {
  // 유효한 응답
}
```

##### 2. Content-Type 헤더 검증

허용되는 이미지 MIME 타입:

```dart
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
```

Content-Type 검증 로직:

```dart
bool isImageContentType(String? contentType) {
  if (contentType == null || contentType.isEmpty) {
    return false;
  }
  // Content-Type에서 charset 등의 추가 정보 제거
  // 예: "image/jpeg; charset=utf-8" -> "image/jpeg"
  final mimeType = contentType.split(';').first.trim().toLowerCase();

  // image/로 시작하면 이미지로 간주
  if (mimeType.startsWith('image/')) {
    return true;
  }

  return validImageContentTypes.contains(mimeType);
}
```

#### Rate Limiting 처리

Wikipedia 등 외부 서버의 Rate Limiting을 방지하기 위한 전략:

```dart
// 1차 패스: 500ms 딜레이로 모든 URL 확인
await Future.delayed(const Duration(milliseconds: 500));

// 2차 패스: 429 에러 발생한 URL은 2초 딜레이로 재시도
if (rateLimitedUrls.isNotEmpty) {
  for (final item in rateLimitedUrls) {
    // 재시도 로직
    await Future.delayed(const Duration(seconds: 2));
  }
}
```

#### User-Agent 헤더 설정

일부 서버는 봇 요청을 차단하므로 브라우저 User-Agent를 사용:

```dart
request.headers.add(
  'User-Agent',
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
);
```

#### 출력 결과 해석

```
✅ [1/677] 마닐라 오션 파크: OK (HTTP 200, image/jpeg)
❌ [15/677] 바나웨 라이스 테라스: HTTP 404
⏳ [45/677] 팔라완 언더그라운드 리버: RATE LIMITED (재시도 예정)
⚠️  [78/677] 세부 막탄: 이미지 URL 없음
```

---

## 이미지 URL 업데이트 스크립트

### update_image_url.dart

개별 여행지의 이미지 URL을 업데이트하는 스크립트입니다.

#### 실행 방법

```bash
cd /Users/thruthesky/apps/flutter/philgo_app

# 인덱스로 업데이트
dart run lib/philgo_files/scripts/update_image_url.dart 15 "https://example.com/new-image.jpg"

# 이름으로 업데이트 (한글 또는 영문)
dart run lib/philgo_files/scripts/update_image_url.dart "바나웨 라이스 테라스" "https://example.com/new-image.jpg"
dart run lib/philgo_files/scripts/update_image_url.dart "Banaue Rice Terraces" "https://example.com/new-image.jpg"
```

#### 주요 기능

1. **인덱스 또는 이름으로 여행지 검색**

```dart
// 숫자인 경우 인덱스로 검색
final parsedIndex = int.tryParse(identifier);
if (parsedIndex != null) {
  targetIndex = parsedIndex;
} else {
  // 문자열인 경우 이름으로 검색
  for (int i = 0; i < travelSpots.length; i++) {
    final spot = travelSpots[i];
    if (spot['name'] == identifier || spot['english name'] == identifier) {
      targetIndex = i;
      break;
    }
  }
}
```

2. **새 URL 유효성 사전 검증**

업데이트 전에 새 URL의 접근 가능 여부와 Content-Type을 확인합니다:

```dart
// HTTP HEAD 요청으로 URL 검증
final request = await httpClient.headUrl(uri);
final response = await request.close();

if (response.statusCode >= 200 && response.statusCode < 400) {
  if (isImageContentType(contentType)) {
    // 유효한 이미지 URL
  } else {
    // 경고: Content-Type이 이미지가 아님
    // 사용자 확인 후 진행 가능
  }
}
```

3. **JSON 파일 원자적 저장**

```dart
final encoder = const JsonEncoder.withIndent('    ');
final updatedJsonString = encoder.convert(travelSpots);
file.writeAsStringSync(updatedJsonString);
```

---

## 에러 유형 및 처리 방법

### 1. HTTP 404 Not Found

**원인**: 이미지가 삭제되었거나 URL이 변경됨

**해결 방법**:
1. Wikipedia에서 해당 여행지 검색
2. 새로운 이미지 URL 찾기 (주로 infobox 또는 본문 첫 이미지)
3. `update_image_url.dart`로 URL 업데이트

**Wikipedia 이미지 URL 형식**:
```
https://upload.wikimedia.org/wikipedia/commons/thumb/[hash]/[filename]/[size]px-[filename].jpg
```

### 2. HTTP 403 Forbidden

**원인**: 핫링킹(Hotlinking) 차단 또는 접근 권한 없음

**해결 방법**:
1. Wikipedia Commons에서 직접 이미지 URL 가져오기
2. 필요시 다른 이미지 소스 사용

### 3. Content-Type이 이미지가 아님

**원인**: URL이 이미지가 아닌 HTML 페이지나 리다이렉트 페이지를 가리킴

**예시**:
```
URL: https://en.wikipedia.org/wiki/File:Example.jpg
Content-Type: text/html; charset=UTF-8  ← HTML 페이지
```

**해결 방법**:
Wikipedia 파일 페이지 대신 실제 이미지 URL 사용:
```
# 잘못된 URL (파일 페이지)
https://en.wikipedia.org/wiki/File:Example.jpg

# 올바른 URL (실제 이미지)
https://upload.wikimedia.org/wikipedia/commons/[path]/Example.jpg
```

### 4. HTTP 429 Too Many Requests

**원인**: 서버의 Rate Limiting

**해결 방법**:
1. 스크립트가 자동으로 2초 딜레이 후 재시도
2. 지속적으로 발생 시 수동으로 나중에 다시 시도

### 5. 이미지 URL 없음 (빈 값)

**원인**: 초기 데이터 입력 시 이미지 URL을 찾지 못함

**해결 방법**:
1. Wikipedia에서 여행지 검색
2. 적절한 이미지 URL 찾기
3. `update_image_url.dart`로 URL 추가

---

## 실제 사용 예시

### 예시 1: 전체 검증 후 실패한 URL 수정

```bash
# 1단계: 전체 검증 실행
cd /Users/thruthesky/apps/flutter/philgo_app
dart run lib/philgo_files/scripts/check_image_urls.dart

# 2단계: 실패한 URL 목록 확인
cat lib/philgo_files/scripts/failed_image_urls.json

# 3단계: 각 실패 항목에 대해 새 이미지 URL 찾아서 업데이트
dart run lib/philgo_files/scripts/update_image_url.dart 15 "https://upload.wikimedia.org/wikipedia/commons/thumb/..."
```

### 예시 2: 특정 여행지 이미지 수정

```bash
# 바나웨 라이스 테라스의 이미지 URL 업데이트
dart run lib/philgo_files/scripts/update_image_url.dart "바나웨 라이스 테라스" "https://upload.wikimedia.org/wikipedia/commons/thumb/1/1d/Banaue_Rice_Terraces.jpg/800px-Banaue_Rice_Terraces.jpg"
```

### 예시 3: failed_image_urls.json 분석

```json
[
  {
    "index": 15,
    "name": "바나웨 라이스 테라스",
    "englishName": "Banaue Rice Terraces",
    "imageUrl": "https://example.com/old-broken-url.jpg",
    "error": "HTTP 404",
    "statusCode": 404,
    "contentType": "",
    "isRateLimited": false
  },
  {
    "index": 78,
    "name": "세부 막탄",
    "englishName": "Mactan Cebu",
    "imageUrl": "",
    "error": "URL이 비어있음",
    "statusCode": 0,
    "contentType": "",
    "isRateLimited": false
  }
]
```

---

## 주의사항

1. **Wikipedia 이미지 사용 시**: Wikipedia Commons의 라이선스를 확인하세요 (대부분 CC BY-SA 또는 Public Domain)

2. **대량 요청 시 Rate Limiting**: 많은 URL을 검증할 때는 적절한 딜레이를 유지하세요

3. **이미지 크기**: Wikipedia에서 thumb URL 사용 시 적절한 크기 지정 (예: 800px, 1024px)

4. **백업**: 대량 수정 전 `travel_spots.json` 파일 백업 권장

---

## 관련 파일

- [travel_spots.json](travel/travel_spots.json) - 여행지 데이터 파일
- [check_image_urls.dart](scripts/check_image_urls.dart) - 이미지 URL 검증 스크립트
- [update_image_url.dart](scripts/update_image_url.dart) - 이미지 URL 업데이트 스크립트
- [failed_image_urls.json](scripts/failed_image_urls.json) - 실패한 URL 기록
