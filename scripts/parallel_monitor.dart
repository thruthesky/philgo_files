// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'parallel_lock_utils.dart';

/// 병렬 처리 모니터링 스크립트
///
/// 진행 상황을 실시간으로 확인하고, 진행 상황 관리 기능을 제공합니다.
///
/// 사용법:
/// ```shell
/// # 진행 상황 조회
/// dart run lib/philgo_files/scripts/parallel_monitor.dart
///
/// # 실시간 모니터링 (5초마다 갱신)
/// dart run lib/philgo_files/scripts/parallel_monitor.dart --watch
///
/// # 모든 lock 초기화 (진행 중인 작업 취소)
/// dart run lib/philgo_files/scripts/parallel_monitor.dart --clear-locks
///
/// # 모든 진행 상황 초기화 (완료/실패 기록 삭제)
/// dart run lib/philgo_files/scripts/parallel_monitor.dart --reset
///
/// # 실패한 항목만 초기화 (재시도 가능하게)
/// dart run lib/philgo_files/scripts/parallel_monitor.dart --retry-failed
///
/// # 상세 정보 출력
/// dart run lib/philgo_files/scripts/parallel_monitor.dart --verbose
/// ```

/// JSON 파일 경로
const String jsonFilePath = 'lib/philgo_files/travel/travel_spots.json';

void main(List<String> args) async {
  // 명령줄 인자 파싱
  bool watchMode = args.contains('--watch');
  bool clearLocks = args.contains('--clear-locks');
  bool resetAll = args.contains('--reset');
  bool retryFailed = args.contains('--retry-failed');
  bool verbose = args.contains('--verbose');

  // 디렉토리 초기화
  initializeDirectories();

  // JSON 파일에서 총 항목 수 가져오기
  final jsonFile = File(jsonFilePath);
  if (!jsonFile.existsSync()) {
    print('❌ 오류: $jsonFilePath 파일을 찾을 수 없습니다.');
    exit(1);
  }

  final jsonString = jsonFile.readAsStringSync();
  final List<dynamic> travelSpots = jsonDecode(jsonString);
  final totalItems = travelSpots.length;

  // 관리 명령 처리
  if (clearLocks) {
    print('');
    print('⚠️  모든 lock을 초기화합니다...');
    print('   (진행 중인 작업이 취소됩니다)');
    print('');
    clearAllLocks();
    return;
  }

  if (resetAll) {
    print('');
    print('⚠️  모든 진행 상황을 초기화합니다...');
    print('   (완료/실패 기록이 삭제됩니다)');
    print('');
    stdout.write('계속하시겠습니까? (y/N): ');
    final response = stdin.readLineSync();
    if (response?.toLowerCase() == 'y') {
      clearAllProgress();
    } else {
      print('취소되었습니다.');
    }
    return;
  }

  if (retryFailed) {
    print('');
    print('🔄 실패한 항목을 재시도 가능 상태로 초기화합니다...');
    print('');
    clearFailedItems();
    return;
  }

  // 진행 상황 표시
  if (watchMode) {
    // 실시간 모니터링 모드
    print('');
    print('👁️  실시간 모니터링 모드 (5초마다 갱신, Ctrl+C로 종료)');
    print('');

    while (true) {
      // 화면 지우기 (ANSI escape code)
      print('\x1B[2J\x1B[0;0H');

      printHeader();
      printDetailedProgress(totalItems, travelSpots, verbose);

      await Future.delayed(const Duration(seconds: 5));
    }
  } else {
    // 일회성 조회
    printHeader();
    printDetailedProgress(totalItems, travelSpots, verbose);
  }
}

void printHeader() {
  print('=' * 70);
  print('📊 Travel Spots 병렬 처리 모니터');
  print('=' * 70);
  print('시간: ${DateTime.now().toString().substring(0, 19)}');
}

void printDetailedProgress(
    int totalItems, List<dynamic> travelSpots, bool verbose) {
  final progress = getProgress(totalItems);

  // 기본 진행 상황
  print('');
  print('📈 전체 진행 상황');
  print('-' * 40);
  print('  총 항목: ${progress.totalItems}개');

  final completedPercent =
      (progress.completedCount / progress.totalItems * 100).toStringAsFixed(1);
  final failedPercent =
      (progress.failedCount / progress.totalItems * 100).toStringAsFixed(1);

  print('  ✅ 완료: ${progress.completedCount}개 ($completedPercent%)');
  print('  ❌ 실패: ${progress.failedCount}개 ($failedPercent%)');
  print('  🔄 처리 중: ${progress.inProgressCount}개');
  print('  ⏳ 대기 중: ${progress.remainingCount}개');

  // 진행률 바
  final progressBar = _createProgressBar(
      progress.completedCount, progress.totalItems, 40);
  print('');
  print('  [$progressBar] $completedPercent%');

  // 처리 중인 항목 상세
  if (progress.inProgressIndices.isNotEmpty) {
    print('');
    print('🔄 현재 처리 중인 항목');
    print('-' * 40);

    for (final index in progress.inProgressIndices) {
      final lockFile = File(getLockFilePath(index));
      if (lockFile.existsSync()) {
        try {
          final content = lockFile.readAsStringSync();
          final lockInfo = LockInfo.fromJson(jsonDecode(content));
          final elapsed = DateTime.now().difference(lockInfo.lockedAt);
          final spotName = lockInfo.spotName ?? travelSpots[index]['name'];
          print(
              '  [$index] $spotName - ${lockInfo.workerId} (${elapsed.inSeconds}초 경과)');
        } catch (e) {
          print('  [$index] (정보 읽기 실패)');
        }
      }
    }
  }

  // 최근 실패한 항목
  if (progress.failedIndices.isNotEmpty) {
    print('');
    print('❌ 최근 실패한 항목 (최대 10개)');
    print('-' * 40);

    for (final index in progress.failedIndices.take(10)) {
      final failedFile = File(getFailedFilePath(index));
      if (failedFile.existsSync()) {
        try {
          final content = failedFile.readAsStringSync();
          final data = jsonDecode(content);
          final name = data['name'] ?? travelSpots[index]['name'];
          final reason = data['reason'] ?? '(알 수 없음)';
          print('  [$index] $name');
          print('       사유: $reason');
        } catch (e) {
          print('  [$index] (정보 읽기 실패)');
        }
      }
    }

    if (progress.failedIndices.length > 10) {
      print('  ... 외 ${progress.failedIndices.length - 10}개');
    }
  }

  // 지역별 통계 (verbose 모드)
  if (verbose) {
    print('');
    print('📍 지역별 진행 상황');
    print('-' * 40);

    final Map<String, Map<String, int>> provinceStats = {};

    // 완료된 항목 지역별 집계
    for (final index in progress.completedIndices) {
      if (index < travelSpots.length) {
        final province =
            travelSpots[index]['province']?.toString() ?? '(지역 없음)';
        provinceStats.putIfAbsent(
            province, () => {'completed': 0, 'failed': 0, 'total': 0});
        provinceStats[province]!['completed'] =
            provinceStats[province]!['completed']! + 1;
      }
    }

    // 실패한 항목 지역별 집계
    for (final index in progress.failedIndices) {
      if (index < travelSpots.length) {
        final province =
            travelSpots[index]['province']?.toString() ?? '(지역 없음)';
        provinceStats.putIfAbsent(
            province, () => {'completed': 0, 'failed': 0, 'total': 0});
        provinceStats[province]!['failed'] =
            provinceStats[province]!['failed']! + 1;
      }
    }

    // 전체 항목 지역별 집계
    for (final spot in travelSpots) {
      final province = spot['province']?.toString() ?? '(지역 없음)';
      provinceStats.putIfAbsent(
          province, () => {'completed': 0, 'failed': 0, 'total': 0});
      provinceStats[province]!['total'] =
          provinceStats[province]!['total']! + 1;
    }

    // 정렬 및 출력
    final sortedProvinces = provinceStats.entries.toList()
      ..sort((a, b) => b.value['total']!.compareTo(a.value['total']!));

    for (final entry in sortedProvinces.take(15)) {
      final province = entry.key;
      final completed = entry.value['completed']!;
      final failed = entry.value['failed']!;
      final total = entry.value['total']!;
      final percent = (completed / total * 100).toStringAsFixed(1);

      print('  $province: $completed/$total ($percent%) ${failed > 0 ? "[실패: $failed]" : ""}');
    }

    if (sortedProvinces.length > 15) {
      print('  ... 외 ${sortedProvinces.length - 15}개 지역');
    }
  }

  // Worker 활동 상태
  print('');
  print('👥 Worker 활동 상태');
  print('-' * 40);

  final logsDir_ = Directory(logsDir);
  if (logsDir_.existsSync()) {
    final logFiles = logsDir_.listSync().whereType<File>().toList()
      ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

    if (logFiles.isEmpty) {
      print('  (활성 Worker 없음)');
    } else {
      for (final logFile in logFiles.take(10)) {
        final workerName =
            logFile.uri.pathSegments.last.replaceAll('.log', '');
        final lastModified = logFile.lastModifiedSync();
        final elapsed = DateTime.now().difference(lastModified);

        String status;
        if (elapsed.inMinutes < 1) {
          status = '🟢 활성 (${elapsed.inSeconds}초 전)';
        } else if (elapsed.inMinutes < 5) {
          status = '🟡 대기 (${elapsed.inMinutes}분 전)';
        } else {
          status = '⚪ 비활성 (${elapsed.inMinutes}분 전)';
        }

        print('  $workerName: $status');
      }
    }
  } else {
    print('  (활성 Worker 없음)');
  }

  // 명령어 안내
  print('');
  print('💡 유용한 명령어');
  print('-' * 40);
  print('  진행 상황 조회: dart run tmp/travel-spots-updating/parallel_monitor.dart');
  print('  실시간 모니터링: dart run tmp/travel-spots-updating/parallel_monitor.dart --watch');
  print('  상세 정보: dart run tmp/travel-spots-updating/parallel_monitor.dart --verbose');
  print('  실패 재시도: dart run tmp/travel-spots-updating/parallel_monitor.dart --retry-failed');
  print('  lock 초기화: dart run tmp/travel-spots-updating/parallel_monitor.dart --clear-locks');

  print('');
  print('=' * 70);
}

String _createProgressBar(int completed, int total, int width) {
  final filledWidth = (completed / total * width).round();
  final emptyWidth = width - filledWidth;

  return '${'█' * filledWidth}${'░' * emptyWidth}';
}
