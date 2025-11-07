# TODO: 시스템 트레이 완성

## 📊 현재 상태

### ✅ 완료된 작업
- [x] TrayService 코드 구현 (lib/services/tray_service.dart)
- [x] assets/icons 폴더 생성
- [x] pubspec.yaml에 assets 등록
- [x] eyebottle 로고 다운로드 (assets/icons/tray_icon.png, 20KB)
- [x] 아이콘 로드 로직 구현 (_prepareIcon 메서드)

### ❌ 문제
- PNG 파일은 성공적으로 로드되지만, `system_tray` 패키지가 `Bad Arguments` 에러 발생
- 로그: `✅ 트레이 아이콘 준비 완료: C:\Users\user\AppData\Local\Temp\tray_icon.png`
- 이후 `PlatformException(Bad Arguments, null, false, null)` 발생

## 🔧 해결 방법

### 방법 1: PNG를 ICO로 변환 (추천)

**단계**:
1. **온라인 변환 도구 사용**:
   - https://convertio.co/png-ico/
   - https://www.icoconverter.com/
   - https://cloudconvert.com/png-to-ico

2. **변환 설정**:
   - 입력: `assets/icons/eyebottle-logo.png`
   - 출력 크기: 32x32 픽셀 (권장)
   - 또는 멀티 사이즈: 16x16, 32x32, 48x48 포함

3. **파일 배치**:
   ```
   C:\ws-workspace\sat-lec-rec\assets\icons\tray_icon.ico
   ```

4. **TrayService 수정 불필요**:
   - 현재 코드는 이미 `.ico` 파일을 우선 시도함
   - `_prepareIcon()` 메서드가 `tray_icon.ico` → `tray_icon.png` 순서로 시도

5. **테스트**:
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

### 방법 2: 다른 아이콘 라이브러리 사용

현재 `system_tray: 2.0.3` 사용 중인데, 다른 패키지 시도 가능:
- `tray_manager` (https://pub.dev/packages/tray_manager)
- `flutter_window_manager` + 커스텀 트레이

**주의**: 패키지 변경은 코드 전면 수정 필요

### 방법 3: 트레이 없이 운영

트레이는 **선택적 기능**이므로 없어도 앱은 정상 작동:
- 창을 닫으면 앱이 종료됨 (현재 동작)
- 백그라운드 실행이 필요하면 창을 최소화하여 사용
- 스케줄된 녹화는 정상 작동

## 📁 관련 파일

### 주요 코드
- `lib/services/tray_service.dart` (300줄)
  - `_prepareIcon()`: 아이콘 로드 (줄 81-115)
  - `initialize()`: 트레이 초기화 (줄 30-76)
  - `_buildTrayMenu()`: 메뉴 구성 (줄 117-159)

### 아이콘 파일
- WSL: `/home/usereyebottle/projects/sat-lec-rec/assets/icons/`
  - `eyebottle-logo.png` (원본, 20KB)
  - `tray_icon.png` (현재 사용, eyebottle-logo.png 복사본)
  - `README.md` (아이콘 사용 가이드)

- Windows: `C:\ws-workspace\sat-lec-rec\assets\icons\`
  - 동일한 파일들 동기화됨

### 설정 파일
- `pubspec.yaml` (줄 88-89):
  ```yaml
  assets:
    - assets/icons/
  ```

## 🐛 디버깅 정보

### 성공한 로그
```
📍 TrayService 초기화 시작...
✅ 트레이 아이콘 준비 완료: C:\Users\user\AppData\Local\Temp\tray_icon.png
🐛 트레이 아이콘 경로: C:\Users\user\AppData\Local\Temp\tray_icon.png
```

### 실패한 지점
```
PlatformException(Bad Arguments, null, false, null)
#3   SystemTray.initSystemTray (package:system_tray/src/tray.dart:47:18)
```

**분석**:
- 아이콘 파일 로드는 성공 (rootBundle.load, writeAsBytes 모두 정상)
- `SystemTray.initSystemTray()` 호출 시 네이티브 레이어에서 거부
- PNG 형식 또는 파일 크기가 system_tray 패키지와 호환되지 않음

## 🎯 다음 작업 시 체크리스트

- [ ] eyebottle-logo.png를 32x32 ICO로 변환
- [ ] `tray_icon.ico` 파일을 assets/icons/ 폴더에 배치
- [ ] Windows로 동기화: `rsync -av assets/ /mnt/c/ws-workspace/sat-lec-rec/assets/`
- [ ] `flutter clean && flutter pub get && flutter run`
- [ ] 트레이 아이콘 표시 확인
- [ ] 창 닫기 → 트레이로 최소화 테스트
- [ ] 트레이 우클릭 → 메뉴 테스트
- [ ] 트레이 좌클릭 → 창 복원 테스트

## 📚 참고 자료

### system_tray 패키지 문서
- https://pub.dev/packages/system_tray
- https://github.com/antler119/system_tray

### ICO 변환 도구
- Convertio: https://convertio.co/png-ico/
- ICO Converter: https://www.icoconverter.com/
- CloudConvert: https://cloudconvert.com/png-to-ico

### 아이콘 소스
- eyebottle 홈페이지: http://eyebottle.kr/
- 로고 원본 경로: http://eyebottle.kr/assets/logos/eyebottle-logo.png
