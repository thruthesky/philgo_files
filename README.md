# philgo_files

PhilGo 파일, 이미지 repository

## 개요

이 저장소는 필고 앱과 웹에서 공통으로 사용되는 리소스 파일들을 관리합니다.

- **GitHub Repository**: [https://github.com/thruthesky/philgo_files](https://github.com/thruthesky/philgo_files)
- **파일 접근 URL**: `https://file.philgo.com/philgo_files/{파일경로}`

## 파일 구조

```
philgo_files/
├── map/                # 지도 이미지 파일들
├── icons/              # 아이콘 파일들
├── travel/             # 여행 관련 파일들
│   └── travel_spots.json  # 여행 명소 데이터
└── info.yaml           # 리소스 파일 메타데이터
```

## 웹 서버 배포

파일이 변경되면 웹 서버에 업로드해야 합니다.

### 배포 절차

#### 1. Git 커밋 및 푸시

```bash
# 변경사항 커밋
git add .
git commit -m "Update files"
git push origin main
```

#### 2. 웹 서버 업데이트

**방법 1: 한 줄 명령어 (권장)**

```bash
ssh philgo@178.128.124.178 "cd www/philgo_files; git pull"
```

**방법 2: 서버 직접 접속**

```bash
# 서버 접속
sf  # 또는 ssh philgo@178.128.124.178

# philgo_files 디렉토리로 이동 후 업데이트
cd www/philgo_files
git pull
```

## 상세 문서

자세한 사용법은 다음 문서를 참조하세요:

- [PhilGo Files 가이드](../.claude/skills/philgo-skill/references/philgo-files.md)
- [여행 명소 개발 가이드](../.claude/skills/philgo-skill/references/app/philgo-app-travel-spots.md)
