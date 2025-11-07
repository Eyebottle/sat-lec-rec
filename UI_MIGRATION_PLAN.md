# sat-lec-rec UI 마이그레이션 계획서

## 📋 프로젝트 개요

**목적**: eyebottlelee (아이보틀녹음기)의 UI 디자인 시스템을 sat-lec-rec에 적용하여 일관되고 세련된 사용자 경험 제공

**기간**: 약 3-4일 (단계별 진행)

**작업 범위**:
- 디자인 토큰(색상, 타이포그래피, 간격, 그림자) 이식
- 공통 컴포넌트(버튼, 카드) 이식
- 기존 화면 3개(메인, 스케줄, 설정) 리디자인
- Material 3 디자인 시스템 완전 적용

---

## 🎯 디자인 철학

### eyebottlelee 디자인의 핵심 가치
1. **프로페셔널한 미니멀리즘**: 불필요한 장식 배제, 기능에 집중
2. **높은 가독성**: 충분한 간격, 명확한 계층 구조
3. **소프트 컬러**: 차분한 톤의 색상으로 눈의 피로 최소화
4. **둥근 모서리**: 모든 요소에 borderRadius 적용 (8~24px)
5. **Flat Design**: elevation 0~3 수준의 낮은 그림자

### sat-lec-rec에 맞게 조정할 부분
- **Primary 색상**: 아이보틀 블루(#1193D4) → 교육용 블루(#2196F3) 또는 청록색
- **아이콘**: 마이크 관련 → 강의/녹화 관련 아이콘
- **용어**: "진료녹음" → "강의녹화" 등 컨텍스트 조정

---

## 📁 새로운 파일 구조

```
lib/
  ├── ui/
  │   ├── style/                    ← 새로 생성
  │   │   ├── app_colors.dart       ← eyebottlelee에서 복사 + 색상 조정
  │   │   ├── app_typography.dart   ← eyebottlelee에서 복사 (그대로)
  │   │   ├── app_spacing.dart      ← eyebottlelee에서 복사 (그대로)
  │   │   ├── app_elevation.dart    ← eyebottlelee에서 복사 (그대로)
  │   │   └── app_theme.dart        ← eyebottlelee에서 복사 + 색상 조정
  │   │
  │   ├── widgets/
  │   │   ├── common/               ← 새로 생성
  │   │   │   ├── app_button.dart   ← eyebottlelee에서 복사 (그대로)
  │   │   │   ├── app_card.dart     ← eyebottlelee에서 복사 (그대로)
  │   │   │   └── status_badge.dart ← 새로 생성 (녹화 상태 표시)
  │   │   │
  │   │   └── recording_progress_widget.dart  ← 기존 유지, 스타일 업데이트
  │   │
  │   └── screens/
  │       ├── main_screen.dart      ← 리디자인 (현재 main.dart에서 분리)
  │       ├── schedule_screen.dart  ← 리디자인
  │       └── settings_screen.dart  ← 리디자인
  │
  └── main.dart                     ← 최소화 (MaterialApp 설정만)
```

---

## 🚀 단계별 마이그레이션 계획

### 🔵 Phase 1: 디자인 토큰 이식 (1일차)

#### 작업 내용
1. **디렉토리 생성**
   ```bash
   mkdir -p lib/ui/style
   mkdir -p lib/ui/widgets/common
   ```

2. **스타일 파일 복사 및 수정**
   - ✅ `app_colors.dart` 복사
     - Primary 색상 변경: `#1193D4` → `#2196F3`
     - Recording 관련 색상 그대로 유지
     - 주석 업데이트: "아이보틀 진료녹음" → "sat-lec-rec 강의녹화"

   - ✅ `app_typography.dart` 복사 (수정 없음)

   - ✅ `app_spacing.dart` 복사 (수정 없음)

   - ✅ `app_elevation.dart` 복사 (수정 없음)

   - ✅ `app_theme.dart` 생성 (추후 작업)

3. **pubspec.yaml 업데이트**
   ```yaml
   flutter:
     fonts:
       - family: Noto Sans KR
         fonts:
           - asset: fonts/NotoSansKR-Regular.ttf
             weight: 400
           - asset: fonts/NotoSansKR-Medium.ttf
             weight: 500
           - asset: fonts/NotoSansKR-SemiBold.ttf
             weight: 600
           - asset: fonts/NotoSansKR-Bold.ttf
             weight: 700

       - family: Inter
         fonts:
           - asset: fonts/Inter-Regular.ttf
             weight: 400
           - asset: fonts/Inter-SemiBold.ttf
             weight: 600
           - asset: fonts/Inter-Bold.ttf
             weight: 700
   ```

4. **폰트 파일 다운로드**
   - Noto Sans KR: https://fonts.google.com/noto/specimen/Noto+Sans+KR
   - Inter: https://fonts.google.com/specimen/Inter
   - `assets/fonts/` 디렉토리에 저장

5. **테스트**
   - 새로운 색상 시스템이 import되는지 확인
   - 컴파일 오류 없는지 확인

#### 예상 소요 시간
- 파일 복사 및 수정: 1시간
- 폰트 다운로드 및 설정: 30분
- 테스트: 30분
- **총 2시간**

---

### 🔵 Phase 2: 공통 컴포넌트 이식 (1일차 오후)

#### 작업 내용
1. **버튼 컴포넌트 복사**
   - ✅ `app_button.dart` 복사 (수정 없음)
   - 다양한 버튼 타입 제공:
     - `AppButton()` / `AppButton.primary()`: Filled 버튼
     - `AppButton.secondary()`: Outlined 버튼
     - `AppButton.text()`: Text 버튼
     - `AppButton.success()`: 성공 버튼
     - `AppButton.error()`: 오류 버튼
   - 크기 확장:
     - `AppButtonSize.small()`: 작은 버튼
     - `AppButtonSize.large()`: 큰 버튼

2. **카드 컴포넌트 복사**
   - ✅ `app_card.dart` 복사 (수정 없음)
   - 다양한 카드 타입 제공:
     - `AppCard()`: 기본 카드
     - `AppCard.level1()`: 일반 정보 카드
     - `AppCard.level2()`: 강조 카드
     - `AppCard.level3()`: 부상 카드
     - `SettingsCard`: 설정 항목용 카드
     - `StatCard`: 통계 표시용 카드

3. **테스트 화면 생성**
   ```dart
   // lib/ui/screens/test_components_screen.dart
   // 모든 컴포넌트를 시각적으로 확인할 수 있는 테스트 화면
   ```

4. **컴포넌트 동작 확인**
   - 버튼 클릭 이벤트
   - 카드 탭 이벤트
   - 호버 효과 (Windows 데스크탑)

#### 예상 소요 시간
- 파일 복사: 30분
- 테스트 화면 생성: 1시간
- 동작 확인: 30분
- **총 2시간**

---

### 🔵 Phase 3: 메인 화면 리디자인 (2일차)

#### 현재 구조 문제점
- `main.dart` 파일이 너무 큼 (400+ 줄)
- MaterialApp 설정과 화면 로직이 혼재
- 스타일이 인라인으로 하드코딩됨

#### 새로운 구조
```dart
// lib/main.dart (간소화)
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LoggerService().ensureInitialized();
  runApp(const SatLecRecApp());
}

class SatLecRecApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'sat-lec-rec',
      theme: AppTheme.lightTheme,  // ← 새로운 테마 시스템
      home: MainScreen(),
    );
  }
}

// lib/ui/screens/main_screen.dart (새로 생성)
class MainScreen extends StatefulWidget { ... }
```

#### 작업 내용
1. **MainScreen 분리**
   - `main.dart`에서 화면 로직을 `lib/ui/screens/main_screen.dart`로 이동
   - `main.dart`는 MaterialApp 설정만 유지

2. **레이아웃 재구성**
   - 현재: 수직 스크롤 Column
   - 변경: AppCard를 사용한 섹션별 카드 레이아웃
   ```
   [AppBar]
   [예약 입력 카드]       ← AppCard.level2
   [빠른 테스트 버튼]     ← AppButton 사용
   [녹화 진행률 위젯]     ← 스타일 업데이트
   [다음 예약 상태 카드]   ← AppCard.level1
   ```

3. **컴포넌트 교체**
   - 기존 ElevatedButton → AppButton.primary()
   - 기존 OutlinedButton → AppButton.secondary()
   - 기존 Container 카드 → AppCard

4. **색상 및 타이포그래피 적용**
   - Colors.blue → AppColors.primary
   - TextStyle(...) → AppTypography.titleMedium

5. **간격 시스템 적용**
   - 하드코딩된 숫자 → AppSpacing.md

#### 화면별 상세 설계

##### 1️⃣ 예약 입력 카드
```dart
AppCard.level2(
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('새 녹화 예약', style: AppTypography.titleMedium),
      SizedBox(height: AppSpacing.md),

      // Zoom 링크 입력
      TextField(
        decoration: InputDecoration(
          labelText: 'Zoom 링크',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      SizedBox(height: AppSpacing.md),

      // 시작 시간, 녹화 시간 입력...

      // 저장 버튼
      AppButton.primary(
        onPressed: _saveSchedule,
        child: Text('예약 저장'),
        icon: Icons.save,
      ),
    ],
  ),
)
```

##### 2️⃣ 빠른 테스트 섹션
```dart
Row(
  children: [
    Expanded(
      child: AppButton.secondary(
        onPressed: _testRecording,
        child: Text('10초 녹화 테스트'),
        icon: Icons.play_circle_outline,
      ),
    ),
    SizedBox(width: AppSpacing.sm),
    Expanded(
      child: AppButton.secondary(
        onPressed: _testZoom,
        child: Text('Zoom 실행 테스트'),
        icon: Icons.videocam,
      ),
    ),
  ],
)
```

##### 3️⃣ 상태 카드
```dart
AppCard.level1(
  child: Row(
    children: [
      Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.schedule, color: AppColors.primary),
      ),
      SizedBox(width: AppSpacing.md),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('다음 예약', style: AppTypography.labelMedium),
            Text('토요일 오전 11:42', style: AppTypography.titleMedium),
          ],
        ),
      ),
      Text('6일 23시간 후', style: AppTypography.bodySmall),
    ],
  ),
)
```

#### 예상 소요 시간
- MainScreen 분리: 1시간
- 레이아웃 재구성: 2시간
- 컴포넌트 교체: 2시간
- 테스트 및 미세 조정: 1시간
- **총 6시간**

---

### 🔵 Phase 4: 스케줄 화면 리디자인 (2일차 오후)

#### 현재 구조
- ListView로 스케줄 목록 표시
- Card 위젯 사용 (기본 Material)
- 수정/삭제 아이콘 버튼

#### 새로운 구조
```dart
AppCard.level1(
  child: Column(
    children: [
      // 스케줄 헤더
      Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: schedule.isEnabled
                ? AppColors.primaryContainer
                : AppColors.neutral100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.calendar_today),
          ),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(schedule.name, style: AppTypography.titleSmall),
                Text(schedule.weekday, style: AppTypography.bodySmall),
              ],
            ),
          ),
          // 활성화 스위치
          Switch(value: schedule.isEnabled),
        ],
      ),
      Divider(),
      // 스케줄 상세 정보...
    ],
  ),
)
```

#### 작업 내용
1. **리스트 아이템 재설계**
   - 기존 Card → AppCard.level1
   - ListTile → 커스텀 레이아웃
   - 아이콘 컨테이너 추가 (eyebottlelee 스타일)

2. **다이얼로그 리디자인**
   - 스케줄 추가/편집 다이얼로그 스타일 개선
   - borderRadius 24px
   - AppButton 사용

3. **빈 상태 화면 개선**
   - 아이콘 + 메시지 스타일 업데이트
   - AppTypography 적용

#### 예상 소요 시간
- 리스트 아이템 재설계: 2시간
- 다이얼로그 리디자인: 1.5시간
- 빈 상태 화면: 30분
- **총 4시간**

---

### 🔵 Phase 5: 설정 화면 리디자인 (3일차)

#### 현재 구조
- ListView로 설정 섹션 표시
- Card 위젯 사용
- 다양한 입력 위젯 (슬라이더, 스위치, ChoiceChip)

#### 새로운 구조
```dart
// SettingsCard 사용 (eyebottlelee 컴포넌트)
SettingsCard(
  icon: Icons.video_settings,
  title: '비디오 설정',
  description: '해상도, FPS, CRF 조정',
  onTap: () => _showVideoSettings(),
)
```

#### 작업 내용
1. **설정 섹션 재구성**
   - 각 섹션을 AppCard.level1로 감싸기
   - SettingsCard 활용 (아이콘 + 제목 + 설명)

2. **입력 위젯 스타일 업데이트**
   - Slider: activeColor → AppColors.primary
   - Switch: activeColor → AppColors.primary
   - ChoiceChip: 선택 시 AppColors.primaryContainer

3. **하단 버튼 영역 재설계**
   - AppButton.primary() / AppButton.text() 사용
   - 고정 하단 버튼 바 스타일 개선

#### 예상 소요 시간
- 설정 섹션 재구성: 2시간
- 입력 위젯 스타일 업데이트: 1.5시간
- 하단 버튼 영역: 30분
- **총 4시간**

---

### 🔵 Phase 6: 녹화 진행률 위젯 업데이트 (3일차 오후)

#### 작업 내용
1. **카드 스타일 업데이트**
   - Container → AppCard.level2
   - 그림자 및 테두리 자동 적용

2. **타이포그래피 적용**
   - 경과 시간: AppTypography.numberMedium
   - 라벨: AppTypography.labelMedium
   - 통계 값: AppTypography.titleSmall

3. **색상 시스템 적용**
   - 녹화 중 표시: AppColors.recordingActive
   - 오디오 레벨 바: AppColors.volumeLow/Medium/High

4. **애니메이션 추가 (선택 사항)**
   - 빨간 점 깜빡임 애니메이션 (eyebottlelee 스타일)
   ```dart
   TweenAnimationBuilder<double>(
     tween: Tween(begin: 0.4, end: 1.0),
     duration: Duration(milliseconds: 1000),
     builder: (context, value, child) {
       return Opacity(
         opacity: value,
         child: Container(
           width: 14,
           height: 14,
           decoration: BoxDecoration(
             color: AppColors.recordingActive,
             shape: BoxShape.circle,
           ),
         ),
       );
     },
   )
   ```

#### 예상 소요 시간
- 카드 스타일: 30분
- 타이포그래피: 30분
- 색상 시스템: 30분
- 애니메이션 (선택): 30분
- **총 2시간**

---

### 🔵 Phase 7: 최종 통합 및 테스트 (4일차)

#### 작업 내용
1. **테마 시스템 완성**
   ```dart
   // lib/ui/style/app_theme.dart
   class AppTheme {
     static ThemeData get lightTheme {
       return ThemeData(
         useMaterial3: true,
         colorScheme: ColorScheme.fromSeed(
           seedColor: AppColors.primary,
           brightness: Brightness.light,
         ),
         textTheme: AppTypography.createTextTheme(AppColors.textPrimary),
         scaffoldBackgroundColor: AppColors.background,
         cardTheme: CardTheme(
           elevation: 0,
           shape: RoundedRectangleBorder(
             borderRadius: BorderRadius.circular(20),
           ),
         ),
         elevatedButtonTheme: ElevatedButtonThemeData(
           style: ElevatedButton.styleFrom(
             elevation: 0,
             shape: RoundedRectangleBorder(
               borderRadius: BorderRadius.circular(12),
             ),
           ),
         ),
       );
     }
   }
   ```

2. **전체 화면 통합 테스트**
   - 메인 → 스케줄 → 설정 화면 전환
   - 모든 버튼 동작 확인
   - 다이얼로그 표시 확인

3. **반응형 테스트**
   - 최소 창 크기 (640x900) 테스트
   - 최대 창 크기 테스트
   - 텍스트 잘림 현상 확인

4. **접근성 검증**
   - 색상 대비 확인 (WCAG 기준)
   - 포커스 네비게이션 확인
   - 스크린 리더 테스트 (선택 사항)

5. **성능 최적화**
   - 불필요한 rebuild 제거
   - const 생성자 사용 확대

6. **문서 업데이트**
   - README.md에 새로운 UI 시스템 설명 추가
   - 스크린샷 업데이트

#### 예상 소요 시간
- 테마 시스템: 1시간
- 통합 테스트: 2시간
- 반응형 테스트: 1시간
- 접근성 검증: 1시간
- 성능 최적화: 1시간
- 문서 업데이트: 1시간
- **총 7시간**

---

## 📊 전체 일정 요약

| Phase | 작업 내용 | 소요 시간 | 누적 시간 |
|-------|----------|----------|----------|
| 1 | 디자인 토큰 이식 | 2시간 | 2시간 |
| 2 | 공통 컴포넌트 이식 | 2시간 | 4시간 |
| 3 | 메인 화면 리디자인 | 6시간 | 10시간 |
| 4 | 스케줄 화면 리디자인 | 4시간 | 14시간 |
| 5 | 설정 화면 리디자인 | 4시간 | 18시간 |
| 6 | 녹화 진행률 위젯 업데이트 | 2시간 | 20시간 |
| 7 | 최종 통합 및 테스트 | 7시간 | 27시간 |

**총 예상 소요 시간**: 27시간 (약 3-4일)

---

## 🎨 색상 변경 계획

### eyebottlelee → sat-lec-rec

| 항목 | eyebottlelee | sat-lec-rec (제안) |
|------|-------------|-------------------|
| Primary | `#1193D4` (아이보틀 블루) | `#2196F3` (Material Blue) |
| Primary Light | `#4DAEDF` | `#64B5F6` |
| Primary Dark | `#0C75A8` | `#1976D2` |
| Primary Container | `rgba(17, 147, 212, 0.1)` | `rgba(33, 150, 243, 0.1)` |

### 대안 색상 (선택 가능)

**옵션 A: 교육용 청록색**
- Primary: `#00ACC1` (Cyan 600)
- 차분하면서도 집중도를 높이는 색상
- 학습/교육 컨텐츠에 적합

**옵션 B: 신뢰감 있는 남색**
- Primary: `#3F51B5` (Indigo 500)
- 전문성과 신뢰를 전달
- 학술적인 느낌

**옵션 C: 현재 유지 (아이보틀 블루)**
- Primary: `#1193D4` (그대로)
- eyebottlelee와 통일감 유지

---

## ⚠️ 주의사항

### 1. 기능 유지
- UI만 변경, 기능 로직은 건드리지 않음
- 기존 서비스 레이어 (RecorderService, ScheduleService 등) 그대로 사용

### 2. 점진적 마이그레이션
- Phase별로 작업 후 커밋
- 각 Phase가 끝날 때마다 동작 테스트
- 문제 발생 시 이전 Phase로 롤백 가능

### 3. 호환성 확인
- Flutter 3.35.6 / Dart 3.9.2 호환성
- Windows Desktop 환경 최적화
- 기존 패키지와의 충돌 없는지 확인

### 4. 성능 고려
- const 생성자 최대한 활용
- 불필요한 rebuild 방지
- 큰 위젯 트리는 분리

### 5. 백업
- 각 Phase 시작 전 Git 커밋
- 주요 파일 백업본 유지

---

## 🔧 필요한 도구 및 리소스

### 폰트 다운로드
1. **Noto Sans KR**
   - URL: https://fonts.google.com/noto/specimen/Noto+Sans+KR
   - 필요한 Weight: 400, 500, 600, 700
   - 저장 위치: `assets/fonts/`

2. **Inter**
   - URL: https://fonts.google.com/specimen/Inter
   - 필요한 Weight: 400, 600, 700
   - 저장 위치: `assets/fonts/`

### Git 커밋 메시지 템플릿
```
refactor(ui): [Phase X] <작업 내용>

- eyebottlelee UI 시스템 적용
- <구체적인 변경 사항>

Related: UI_MIGRATION_PLAN.md Phase X
```

### 테스트 체크리스트
- [ ] 메인 화면 정상 표시
- [ ] 스케줄 화면 정상 표시
- [ ] 설정 화면 정상 표시
- [ ] 예약 저장 기능 정상 동작
- [ ] 녹화 테스트 기능 정상 동작
- [ ] 스케줄 추가/수정/삭제 정상 동작
- [ ] 설정 저장 기능 정상 동작
- [ ] 녹화 진행률 실시간 업데이트
- [ ] 창 크기 조절 시 레이아웃 깨지지 않음
- [ ] 모든 버튼 클릭 가능
- [ ] 모든 다이얼로그 정상 표시

---

## 📝 작업 시작 전 준비사항

### 1. 현재 상태 커밋
```bash
git add .
git commit -m "chore: UI 마이그레이션 시작 전 백업"
git tag ui-migration-before
```

### 2. 브랜치 생성 (선택 사항)
```bash
git checkout -b feature/ui-redesign
```

### 3. 폰트 파일 준비
- Noto Sans KR 다운로드
- Inter 다운로드
- `assets/fonts/` 디렉토리 생성
- 폰트 파일 복사

### 4. eyebottlelee 프로젝트 확인
- `/home/usereyebottle/projects/eyebottlelee/` 경로 확인
- 복사할 파일 목록 재확인

---

## 🎉 완료 후 기대 효과

1. **일관된 디자인 시스템**
   - 모든 화면이 통일된 스타일
   - 전문적이고 세련된 외관

2. **향상된 사용자 경험**
   - 명확한 계층 구조
   - 직관적인 인터랙션
   - 편안한 색상과 간격

3. **유지보수 용이성**
   - 중앙 집중식 스타일 관리
   - 재사용 가능한 컴포넌트
   - 명확한 파일 구조

4. **확장성**
   - 새로운 화면 추가 용이
   - 일관된 패턴 적용
   - 팀 협업 시 커뮤니케이션 개선

---

## 📚 참고 자료

- eyebottlelee 프로젝트: `/home/usereyebottle/projects/eyebottlelee/`
- Material Design 3: https://m3.material.io/
- Flutter 타이포그래피: https://api.flutter.dev/flutter/material/TextTheme-class.html
- 색상 대비 체크: https://webaim.org/resources/contrastchecker/

---

**작성일**: 2025-11-07
**작성자**: Claude Code
**버전**: 1.0
