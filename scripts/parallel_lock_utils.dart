// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

/// 병렬 처리를 위한 Lock 유틸리티 클래스
///
/// 여러 프로세스가 동시에 실행될 때 동일한 여행 정보를 중복 처리하지 않도록
/// 파일 기반의 Mutual Exclusion(상호 배제)을 구현합니다.
///
/// 폴더 구조:
/// - 스크립트: lib/philgo_files/scripts/
/// - 작업 데이터: tmp/travel-spots-updating/
///
/// ```
/// tmp/travel-spots-updating/
/// ├── locks/           # 현재 처리 중인 항목 lock 파일
/// │   ├── 0.lock       # 인덱스 0번 항목 처리 중
/// │   └── ...
/// ├── completed/       # 완료된 항목 기록
/// │   ├── 0.done       # 인덱스 0번 항목 완료
/// │   └── ...
/// ├── failed/          # 실패한 항목 기록
/// │   ├── 2.failed     # 인덱스 2번 항목 실패
/// │   └── ...
/// ├── logs/            # 작업 로그
/// │   └── worker_1.log
/// └── progress.json    # 전체 진행 상황 요약
/// ```

/// 기본 경로 설정
const String baseDir = 'tmp/travel-spots-updating';
const String locksDir = '$baseDir/locks';
const String completedDir = '$baseDir/completed';
const String failedDir = '$baseDir/failed';
const String logsDir = '$baseDir/logs';
const String progressFile = '$baseDir/progress.json';

/// Lock 상태 열거형
enum LockStatus {
  available, // 사용 가능 (lock 없음)
  locked, // 다른 프로세스가 처리 중
  completed, // 이미 완료됨
  failed, // 이전에 실패함
}

/// Lock 정보 클래스
class LockInfo {
  final int index;
  final String workerId;
  final DateTime lockedAt;
  final String? spotName;

  LockInfo({
    required this.index,
    required this.workerId,
    required this.lockedAt,
    this.spotName,
  });

  Map<String, dynamic> toJson() => {
        'index': index,
        'workerId': workerId,
        'lockedAt': lockedAt.toIso8601String(),
        'spotName': spotName,
      };

  factory LockInfo.fromJson(Map<String, dynamic> json) => LockInfo(
        index: json['index'] as int,
        workerId: json['workerId'] as String,
        lockedAt: DateTime.parse(json['lockedAt'] as String),
        spotName: json['spotName'] as String?,
      );
}

/// 진행 상황 정보 클래스
class ProgressInfo {
  final int totalItems;
  final int completedCount;
  final int failedCount;
  final int inProgressCount;
  final int remainingCount;
  final DateTime lastUpdated;
  final List<int> completedIndices;
  final List<int> failedIndices;
  final List<int> inProgressIndices;

  ProgressInfo({
    required this.totalItems,
    required this.completedCount,
    required this.failedCount,
    required this.inProgressCount,
    required this.remainingCount,
    required this.lastUpdated,
    required this.completedIndices,
    required this.failedIndices,
    required this.inProgressIndices,
  });

  Map<String, dynamic> toJson() => {
        'totalItems': totalItems,
        'completedCount': completedCount,
        'failedCount': failedCount,
        'inProgressCount': inProgressCount,
        'remainingCount': remainingCount,
        'lastUpdated': lastUpdated.toIso8601String(),
        'completedIndices': completedIndices,
        'failedIndices': failedIndices,
        'inProgressIndices': inProgressIndices,
        'progressPercent':
            (completedCount / totalItems * 100).toStringAsFixed(1),
      };
}

/// 디렉토리 초기화
void initializeDirectories() {
  Directory(locksDir).createSync(recursive: true);
  Directory(completedDir).createSync(recursive: true);
  Directory(failedDir).createSync(recursive: true);
  Directory(logsDir).createSync(recursive: true);
}

/// Lock 파일 경로 반환
String getLockFilePath(int index) => '$locksDir/$index.lock';

/// 완료 파일 경로 반환
String getCompletedFilePath(int index) => '$completedDir/$index.done';

/// 실패 파일 경로 반환
String getFailedFilePath(int index) => '$failedDir/$index.failed';

/// 항목의 Lock 상태 확인
LockStatus checkLockStatus(int index) {
  // 완료 확인 (최우선)
  if (File(getCompletedFilePath(index)).existsSync()) {
    return LockStatus.completed;
  }

  // 실패 확인
  if (File(getFailedFilePath(index)).existsSync()) {
    return LockStatus.failed;
  }

  // Lock 확인
  if (File(getLockFilePath(index)).existsSync()) {
    // Lock 파일이 오래된 경우 (5분 이상) 자동 해제
    final lockFile = File(getLockFilePath(index));
    try {
      final content = lockFile.readAsStringSync();
      final lockInfo = LockInfo.fromJson(jsonDecode(content));
      final elapsed = DateTime.now().difference(lockInfo.lockedAt);

      if (elapsed.inMinutes > 5) {
        // 오래된 lock 자동 해제
        print('   ⚠️  오래된 lock 발견 (${elapsed.inMinutes}분), 자동 해제: $index');
        lockFile.deleteSync();
        return LockStatus.available;
      }
    } catch (e) {
      // lock 파일 읽기 실패 시 삭제
      lockFile.deleteSync();
      return LockStatus.available;
    }

    return LockStatus.locked;
  }

  return LockStatus.available;
}

/// Lock 획득 시도 (Atomic operation)
/// 성공 시 true, 실패 시 false 반환
bool tryAcquireLock(int index, String workerId, {String? spotName}) {
  final status = checkLockStatus(index);

  if (status != LockStatus.available) {
    return false;
  }

  final lockFile = File(getLockFilePath(index));

  try {
    // Atomic하게 lock 파일 생성 시도
    // FileMode.writeOnlyAppend는 파일이 이미 존재하면 append하지만,
    // 여기서는 exclusive 생성을 위해 먼저 존재 여부 재확인
    if (lockFile.existsSync()) {
      return false;
    }

    final lockInfo = LockInfo(
      index: index,
      workerId: workerId,
      lockedAt: DateTime.now(),
      spotName: spotName,
    );

    lockFile.writeAsStringSync(jsonEncode(lockInfo.toJson()));

    // 생성 후 자신의 lock인지 확인 (race condition 방지)
    final content = lockFile.readAsStringSync();
    final savedInfo = LockInfo.fromJson(jsonDecode(content));

    if (savedInfo.workerId != workerId) {
      return false;
    }

    return true;
  } catch (e) {
    return false;
  }
}

/// Lock 해제
void releaseLock(int index) {
  final lockFile = File(getLockFilePath(index));
  if (lockFile.existsSync()) {
    lockFile.deleteSync();
  }
}

/// 완료 표시
void markCompleted(int index, {Map<String, dynamic>? metadata}) {
  // Lock 해제
  releaseLock(index);

  // 완료 파일 생성
  final completedFile = File(getCompletedFilePath(index));
  final data = {
    'index': index,
    'completedAt': DateTime.now().toIso8601String(),
    ...?metadata,
  };
  completedFile.writeAsStringSync(jsonEncode(data));
}

/// 실패 표시
void markFailed(int index, String reason, {Map<String, dynamic>? metadata}) {
  // Lock 해제
  releaseLock(index);

  // 실패 파일 생성
  final failedFile = File(getFailedFilePath(index));
  final data = {
    'index': index,
    'failedAt': DateTime.now().toIso8601String(),
    'reason': reason,
    ...?metadata,
  };
  failedFile.writeAsStringSync(jsonEncode(data));
}

/// 다음 처리할 항목 인덱스 찾기
/// 처리 가능한 항목이 없으면 -1 반환
int findNextAvailableIndex(int totalItems, String workerId,
    {List<int>? targetIndices}) {
  final indices = targetIndices ?? List.generate(totalItems, (i) => i);

  for (final index in indices) {
    if (tryAcquireLock(index, workerId)) {
      return index;
    }
  }

  return -1;
}

/// 전체 진행 상황 조회
ProgressInfo getProgress(int totalItems) {
  final completedDir_ = Directory(completedDir);
  final failedDir_ = Directory(failedDir);
  final locksDir_ = Directory(locksDir);

  final completedIndices = <int>[];
  final failedIndices = <int>[];
  final inProgressIndices = <int>[];

  // 완료된 항목 수집
  if (completedDir_.existsSync()) {
    for (final file in completedDir_.listSync()) {
      if (file is File && file.path.endsWith('.done')) {
        final indexStr = file.uri.pathSegments.last.replaceAll('.done', '');
        final index = int.tryParse(indexStr);
        if (index != null) {
          completedIndices.add(index);
        }
      }
    }
  }

  // 실패한 항목 수집
  if (failedDir_.existsSync()) {
    for (final file in failedDir_.listSync()) {
      if (file is File && file.path.endsWith('.failed')) {
        final indexStr = file.uri.pathSegments.last.replaceAll('.failed', '');
        final index = int.tryParse(indexStr);
        if (index != null) {
          failedIndices.add(index);
        }
      }
    }
  }

  // 처리 중인 항목 수집
  if (locksDir_.existsSync()) {
    for (final file in locksDir_.listSync()) {
      if (file is File && file.path.endsWith('.lock')) {
        final indexStr = file.uri.pathSegments.last.replaceAll('.lock', '');
        final index = int.tryParse(indexStr);
        if (index != null) {
          inProgressIndices.add(index);
        }
      }
    }
  }

  completedIndices.sort();
  failedIndices.sort();
  inProgressIndices.sort();

  final completedCount = completedIndices.length;
  final failedCount = failedIndices.length;
  final inProgressCount = inProgressIndices.length;
  final remainingCount =
      totalItems - completedCount - failedCount - inProgressCount;

  return ProgressInfo(
    totalItems: totalItems,
    completedCount: completedCount,
    failedCount: failedCount,
    inProgressCount: inProgressCount,
    remainingCount: remainingCount,
    lastUpdated: DateTime.now(),
    completedIndices: completedIndices,
    failedIndices: failedIndices,
    inProgressIndices: inProgressIndices,
  );
}

/// 진행 상황을 파일에 저장
void saveProgress(int totalItems) {
  final progress = getProgress(totalItems);
  final encoder = const JsonEncoder.withIndent('    ');
  File(progressFile).writeAsStringSync(encoder.convert(progress.toJson()));
}

/// 모든 lock 초기화 (주의: 모든 진행 중인 작업 취소됨)
void clearAllLocks() {
  final locksDir_ = Directory(locksDir);
  if (locksDir_.existsSync()) {
    for (final file in locksDir_.listSync()) {
      if (file is File && file.path.endsWith('.lock')) {
        file.deleteSync();
      }
    }
  }
  print('✅ 모든 lock이 초기화되었습니다.');
}

/// 모든 진행 상황 초기화 (주의: 모든 기록 삭제됨)
void clearAllProgress() {
  // Locks 삭제
  final locksDir_ = Directory(locksDir);
  if (locksDir_.existsSync()) {
    locksDir_.deleteSync(recursive: true);
    locksDir_.createSync();
  }

  // Completed 삭제
  final completedDir_ = Directory(completedDir);
  if (completedDir_.existsSync()) {
    completedDir_.deleteSync(recursive: true);
    completedDir_.createSync();
  }

  // Failed 삭제
  final failedDir_ = Directory(failedDir);
  if (failedDir_.existsSync()) {
    failedDir_.deleteSync(recursive: true);
    failedDir_.createSync();
  }

  // Progress 파일 삭제
  final progressFile_ = File(progressFile);
  if (progressFile_.existsSync()) {
    progressFile_.deleteSync();
  }

  print('✅ 모든 진행 상황이 초기화되었습니다.');
}

/// 실패한 항목 재시도를 위해 failed 상태 초기화
void clearFailedItems() {
  final failedDir_ = Directory(failedDir);
  if (failedDir_.existsSync()) {
    for (final file in failedDir_.listSync()) {
      if (file is File && file.path.endsWith('.failed')) {
        file.deleteSync();
      }
    }
  }
  print('✅ 실패한 항목들의 상태가 초기화되었습니다. 재시도 가능합니다.');
}

/// Worker 로그 기록
void logWorker(String workerId, String message) {
  final logFile = File('$logsDir/$workerId.log');
  final timestamp = DateTime.now().toIso8601String();
  logFile.writeAsStringSync('[$timestamp] $message\n', mode: FileMode.append);
}

/// 진행 상황 출력
void printProgress(int totalItems) {
  final progress = getProgress(totalItems);

  print('');
  print('=' * 60);
  print('📊 진행 상황');
  print('=' * 60);
  print('  총 항목: ${progress.totalItems}개');
  print(
      '  ✅ 완료: ${progress.completedCount}개 (${(progress.completedCount / progress.totalItems * 100).toStringAsFixed(1)}%)');
  print(
      '  ❌ 실패: ${progress.failedCount}개 (${(progress.failedCount / progress.totalItems * 100).toStringAsFixed(1)}%)');
  print('  🔄 처리 중: ${progress.inProgressCount}개');
  print('  ⏳ 대기 중: ${progress.remainingCount}개');
  print('=' * 60);
  print('');
}
