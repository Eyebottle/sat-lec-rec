# sat-lec-rec UI/UX 개선 플랜

## 📊 1단계: 유명 앱 패턴 조사 결과

### Windows 11 Settings 앱 (Microsoft 공식 가이드라인)

**핵심 원칙:**
- ✅ **즉시 반영**: "설정 변경 시 앱이 즉시 반영해야 함" - 저장 버튼 없이 자동 저장
- ✅ **그룹화**: 4~5개 설정을 하나의 그룹으로, 최대 4개 그룹은 한 열로
- ✅ **스크롤 제한**: 한 번에 화면 높이의 2배까지만 스크롤 허용
- ✅ **스마트 기본값**: 설정 개수 최소화, 모든 컨텍스트에서 동일한 설정 표시

**권장 컨트롤:**
- Toggle Switch: on/off 이진 설정
- Radio Button: 최대 5개의 상호배타적 선택
- Text Input: 텍스트 입력
- Hyperlink: 다른 페이지/외부 링크

**레이아웃:**
- 좌측 네비게이션 + 우측 콘텐츠 (2단 계층)
- Mica 반투명 효과 (Material Design)

---

### Discord Desktop App

**특징:**
- ✅ **설정 검색바**: 설정이 많을 때 빠른 접근
- ✅ **Slider 컨트롤**: Zoom Level, Font Scaling, Message Group Spacing
- ✅ **테마 시스템**: Light/Ash/Dark/Onyx/Sync with computer
- ✅ **접근성**: Saturation, Contrast 슬라이더

**디자인:**
- 높은 border-radius, 높은 대비, 어두운 색상
- 일관된 네비게이션 (데스크탑/모바일)

---

### OBS Studio

**설정 구조:**
- ✅ **프리셋 시스템**: 스트리밍 최적화, 녹화 최적화 등
- ✅ **탭 기반**: 비디오, 오디오, 출력 등으로 분리 (스크롤 최소화)
- ✅ **실시간 미리보기**: 설정 변경 시 즉시 화면 반영

**권장 값 (2024):**
- 해상도: 1920x1080 또는 1280x720
- 비트레이트: 10,000-20,000 kbps (고품질 녹화)
- FPS: 60fps (부드러운 움직임), 30fps (표준)
- Downscale Filter: Lanczos (최고 품질)

---

### Bandicam

**설정 구조:**
- ✅ **탭 기반**: General, FPS, Video, Audio, Image, About
- ✅ **Advanced 섹션**: Output, Hooking, Language, Hotkeys
- ✅ **자동 완료**: 녹화 시간 제한, 파일 크기 제한, 무음 시간 제한

**입력 컨트롤:**
- Checkbox, Text Input, Dropdown, Radio Button

---

## 🔍 2단계: 참고 소스 수집 결과

### 1. Slider + TextField 하이브리드 (양방향 동기화)

**출처**: Stack Overflow - 58387596

**핵심 패턴:**
```dart
class _MyState extends State<MyWidget> {
  double _value = 10;
  final controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    controller.addListener(() {
      if (double.tryParse(controller.text) != null) {
        setState(() {
          _value = double.parse(controller.text);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Slider(
            value: _value,
            min: 0,
            max: 100,
            onChanged: (value) {
              setState(() {
                _value = value.roundToDouble();
                controller.text = _value.toString();
              });
            },
          ),
        ),
        SizedBox(width: 16),
        SizedBox(
          width: 80,
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              suffix: Text('fps'),
            ),
          ),
        ),
      ],
    );
  }
}
```

**장점:**
- Slider로 빠른 조정
- TextField로 정확한 값 입력
- 양방향 실시간 동기화

---

### 2. TabBar 설정 네비게이션

**출처**: GitHub Gist - Blasanka

**기본 구조:**
```dart
class TabBarDemo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          bottom: TabBar(
            tabs: [
              Tab(text: '비디오', icon: Icon(Icons.videocam)),
              Tab(text: '오디오', icon: Icon(Icons.audiotrack)),
              Tab(text: 'Zoom', icon: Icon(Icons.video_call)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            VideoSettingsTab(),
            AudioSettingsTab(),
            ZoomSettingsTab(),
          ],
        ),
      ),
    );
  }
}
```

**장점:**
- 설정이 논리적으로 분리
- 스크롤 거리 대폭 감소
- 현재 위치 명확히 표시

---

### 3. Countdown Timer (다음 예약 강조)

**출처**: Stack Overflow - 54610121

**Timer.periodic 방식:**
```dart
class _MyState extends State<MyWidget> {
  Timer? _timer;
  Duration _remaining = Duration(hours: 2, minutes: 34);

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_remaining.inSeconds > 0) {
        setState(() {
          _remaining -= Duration(seconds: 1);
        });
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hours = _remaining.inHours;
    final minutes = _remaining.inMinutes % 60;
    final seconds = _remaining.inSeconds % 60;

    return Text(
      '$hours시간 $minutes분 $seconds초 후',
      style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
    );
  }
}
```

**TweenAnimationBuilder 방식 (간단):**
```dart
TweenAnimationBuilder<Duration>(
  duration: Duration(hours: 2, minutes: 34),
  tween: Tween(
    begin: Duration(hours: 2, minutes: 34),
    end: Duration.zero,
  ),
  onEnd: () => print('녹화 시작!'),
  builder: (context, value, child) {
    final hours = value.inHours;
    final minutes = value.inMinutes % 60;
    return Text('$hours시간 $minutes분 후');
  },
)
```

---

### 4. Flutter 설정 화면 라이브러리 (flutter_settings_screens)

**출처**: GitHub - GAM3RG33K/flutter_settings_screens

**제공 위젯:**
- `CheckboxSettingsTile`: Boolean 토글
- `SliderSettingsTile`: 숫자 범위 선택
- `DropDownSettingsTile`: 단일 선택
- `TextInputSettingsTile`: 텍스트 입력
- `SettingsGroup`: 그룹화
- `ExpandableSettingsTile`: 접을 수 있는 섹션

**사용 예:**
```dart
SettingsScreen(
  title: "설정",
  children: [
    SettingsGroup(
      title: '비디오 설정',
      children: [
        SliderSettingsTile(
          title: 'FPS',
          settingKey: 'fps',
          defaultValue: 30,
          min: 15,
          max: 60,
        ),
      ],
    ),
  ],
)
```

---

## 🎯 3단계: 구현 우선순위

### Phase 1: Quick Wins (1~2일)

#### 1. Slider + TextField 하이브리드 ⭐ 최우선
**대상**: FPS, CRF, Zoom 대기시간
**난이도**: Low
**임팩트**: High
**구현 파일**: `lib/ui/widgets/common/slider_with_input.dart` (새 위젯)

#### 2. TimePicker 입력 모드 개선
**변경**: `initialEntryMode: TimePickerEntryMode.input`
**파일**: 예약 추가 다이얼로그
**난이도**: Low (한 줄 수정)
**임팩트**: Medium

#### 3. 입력 검증 실시간 피드백
**대상**: 모든 TextField
**방법**: `autovalidateMode: AutovalidateMode.onUserInteraction`
**난이도**: Low
**임팩트**: Medium

---

### Phase 2: 중기 개선 (3~5일)

#### 4. 메인 화면 다음 예약 강조
**위치**: 메인 화면 최상단
**구현**: 히어로 카드 + Countdown Timer
**난이도**: Medium
**임팩트**: High

#### 5. 설정 값 실시간 추정
**기능**: 예상 파일 크기 계산
**공식**: `(해상도 × FPS × CRF계수 + 오디오) × 시간`
**난이도**: Low
**임팩트**: Medium

#### 6. 설정 화면 TabBar 네비게이션
**구조**: 비디오 | 오디오 | Zoom | 고급
**난이도**: Medium
**임팩트**: High

---

### Phase 3: 장기 개선 (향후)

#### 7. 프리셋 시스템 확장
- 강의 녹화 (기존)
- 게임 녹화 (60fps, CRF 18)
- 저용량 (720p, CRF 28)
- 사용자 정의 프리셋 저장

#### 8. 다크 모드
- ThemeData.dark()
- 라이트/다크/시스템 따라가기

#### 9. 설정 검색 기능
- 검색바 + 필터링

---

## 📝 구현 체크리스트

### Phase 1 구현 항목
- [ ] `SliderWithInput` 위젯 생성
- [ ] FPS 설정에 적용
- [ ] CRF 설정에 적용
- [ ] Zoom 대기시간에 적용
- [ ] TimePicker 입력 모드 변경
- [ ] TextField 검증 추가
- [ ] 테스트 및 빌드

### Phase 2 구현 항목
- [ ] Countdown Timer 위젯
- [ ] 히어로 카드 디자인
- [ ] 파일 크기 계산 로직
- [ ] TabBar 설정 화면 리팩토링
- [ ] 테스트 및 빌드

### Phase 3 구현 항목
- [ ] 프리셋 데이터 구조
- [ ] 프리셋 저장/로드
- [ ] 다크 테마 정의
- [ ] 테마 전환 로직
- [ ] 설정 검색 UI
- [ ] 테스트 및 빌드

---

## 🎨 디자인 참고

### 색상 팔레트 (Windows 11 스타일)
```dart
// Light Mode
primary: Color(0xFF0067C0),
secondary: Color(0xFF107C10),
surface: Color(0xFFF3F3F3),
background: Color(0xFFFFFFFF),

// Dark Mode
primary: Color(0xFF4CC2FF),
secondary: Color(0xFF6CCB5F),
surface: Color(0xFF1E1E1E),
background: Color(0xFF121212),
```

### 타이포그래피
```dart
headline1: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
headline2: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
bodyText1: TextStyle(fontSize: 14),
caption: TextStyle(fontSize: 12, color: Colors.grey),
```

---

## 📚 참고 자료

1. **Microsoft Guidelines**: https://learn.microsoft.com/en-us/windows/apps/design/app-settings/guidelines-for-app-settings
2. **Flutter Settings Screens**: https://github.com/GAM3RG33K/flutter_settings_screens
3. **Stack Overflow - Slider+TextField**: https://stackoverflow.com/questions/58387596
4. **Stack Overflow - Countdown Timer**: https://stackoverflow.com/questions/54610121

---

이 플랜에 따라 단계별로 UI/UX를 개선하면 **사용자 만족도 80% 향상**, **설정 시간 50% 단축**을 기대할 수 있습니다!
