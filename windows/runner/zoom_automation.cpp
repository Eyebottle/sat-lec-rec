// 무엇을 하는 코드인지: Zoom 회의 창에서 이름 입력·참가 버튼·상태 감지를 자동화하는 구현부
#include "zoom_automation.h"

#include <objbase.h>
#include <oleauto.h>
#include <uiautomation.h>
#include <wrl/client.h>

#include <algorithm>
#include <array>
#include <cwchar>
#include <cwctype>
#include <string>
#include <vector>

namespace {
using Microsoft::WRL::ComPtr;

ComPtr<IUIAutomation> g_automation;
bool g_com_initialized = false;

template <size_t N>
std::vector<std::wstring> ToVector(const std::array<std::wstring, N>& items) {
  return std::vector<std::wstring>(items.begin(), items.end());
}

std::wstring ToLower(std::wstring text) {
  std::transform(text.begin(), text.end(), text.begin(), [](wchar_t ch) {
    return static_cast<wchar_t>(std::towlower(ch));
  });
  return text;
}

bool ContainsKeyword(const std::wstring& haystack,
                     const std::vector<std::wstring>& keywords) {
  if (haystack.empty()) {
    return false;
  }
  const auto lowered = ToLower(haystack);
  for (const auto& keyword : keywords) {
    const auto lowered_keyword = ToLower(keyword);
    if (lowered.find(lowered_keyword) != std::wstring::npos) {
      return true;
    }
  }
  return false;
}

bool ElementNameMatches(IUIAutomationElement* element,
                        const std::vector<std::wstring>& keywords) {
  if (!element) {
    return false;
  }

  VARIANT name_variant;
  VariantInit(&name_variant);

  const HRESULT hr =
      element->GetCurrentPropertyValue(UIA_NamePropertyId, &name_variant);
  if (FAILED(hr) || name_variant.vt != VT_BSTR || name_variant.bstrVal == nullptr) {
    VariantClear(&name_variant);
    return false;
  }

  const std::wstring name_value(name_variant.bstrVal);
  VariantClear(&name_variant);

  return ContainsKeyword(name_value, keywords);
}

bool WindowHasKeyword(HWND window_handle,
                      const std::vector<std::wstring>& keywords) {
  if (!window_handle) {
    return false;
  }

  wchar_t buffer[512] = {0};
  GetWindowTextW(window_handle, buffer, static_cast<int>(std::size(buffer)));
  std::wstring title(buffer);
  if (ContainsKeyword(title, keywords)) {
    return true;
  }

  wchar_t class_name[256] = {0};
  GetClassNameW(window_handle, class_name,
                static_cast<int>(std::size(class_name)));
  std::wstring class_value(class_name);
  return ContainsKeyword(class_value, keywords);
}

BOOL CALLBACK EnumZoomWindowsProc(HWND hwnd, LPARAM lparam) {
  if (!IsWindowVisible(hwnd)) {
    return TRUE;
  }

  const std::array<std::wstring, 4> keywords = {
      L"zoom", L"줌", L"회의", L"meeting"};

  if (WindowHasKeyword(hwnd, ToVector(keywords))) {
    *reinterpret_cast<HWND*>(lparam) = hwnd;
    return FALSE;  // Stop enumeration, we found a match
  }

  return TRUE;
}

bool TryFindZoomWindow(HWND* out_window_handle) {
  if (!out_window_handle) {
    return false;
  }

  *out_window_handle = nullptr;
  EnumWindows(EnumZoomWindowsProc,
              reinterpret_cast<LPARAM>(out_window_handle));
  return *out_window_handle != nullptr;
}

bool FindElementByControlType(IUIAutomationElement* root,
                              long control_type_id,
                              const std::vector<std::wstring>& names,
                              ComPtr<IUIAutomationElement>* found) {
  if (!root || !found) {
    return false;
  }

  VARIANT control_type_variant;
  VariantInit(&control_type_variant);
  control_type_variant.vt = VT_I4;
  control_type_variant.lVal = control_type_id;

  ComPtr<IUIAutomationCondition> control_condition;
  HRESULT hr = g_automation->CreatePropertyCondition(
      UIA_ControlTypePropertyId, control_type_variant, &control_condition);
  VariantClear(&control_type_variant);

  if (FAILED(hr) || !control_condition) {
    return false;
  }

  ComPtr<IUIAutomationElementArray> elements;
  hr = root->FindAll(TreeScope_Subtree, control_condition.Get(), &elements);
  if (FAILED(hr) || !elements) {
    return false;
  }

  int length = 0;
  elements->get_Length(&length);
  for (int i = 0; i < length; ++i) {
    ComPtr<IUIAutomationElement> candidate;
    if (FAILED(elements->GetElement(i, &candidate)) || !candidate) {
      continue;
    }

    if (names.empty() || ElementNameMatches(candidate.Get(), names)) {
      *found = candidate;
      return true;
    }
  }

  return false;
}

bool SetNameFieldValue(IUIAutomationElement* root,
                       const wchar_t* user_name) {
  if (!root || !user_name || wcslen(user_name) == 0) {
    return false;
  }

  const std::array<std::wstring, 4> name_keywords = {
      L"이름", L"성명", L"your name", L"enter your name"};

  ComPtr<IUIAutomationElement> name_field;
  if (!FindElementByControlType(root, UIA_EditControlTypeId,
                                ToVector(name_keywords), &name_field)) {
    return false;
  }

  ComPtr<IUIAutomationValuePattern> value_pattern;
  if (FAILED(name_field->GetCurrentPatternAs(
          UIA_ValuePatternId, IID_PPV_ARGS(&value_pattern))) ||
      !value_pattern) {
    return false;
  }

  // wchar_t*를 BSTR로 변환
  BSTR bstr_name = SysAllocString(user_name);
  if (!bstr_name) {
    return false;
  }

  const HRESULT hr = value_pattern->SetValue(bstr_name);
  SysFreeString(bstr_name);

  return SUCCEEDED(hr);
}

bool ClickJoinButton(IUIAutomationElement* root) {
  if (!root) {
    return false;
  }

  const std::array<std::wstring, 4> join_keywords = {
      L"참가", L"입장", L"join", L"join meeting"};

  ComPtr<IUIAutomationElement> join_button;
  if (!FindElementByControlType(root, UIA_ButtonControlTypeId,
                                ToVector(join_keywords), &join_button)) {
    return false;
  }

  ComPtr<IUIAutomationInvokePattern> invoke_pattern;
  if (FAILED(join_button->GetCurrentPatternAs(
          UIA_InvokePatternId, IID_PPV_ARGS(&invoke_pattern))) ||
      !invoke_pattern) {
    return false;
  }

  return SUCCEEDED(invoke_pattern->Invoke());
}

bool SetPasswordFieldValue(IUIAutomationElement* root,
                           const wchar_t* password) {
  if (!root || !password || wcslen(password) == 0) {
    return false;
  }

  const std::array<std::wstring, 6> password_keywords = {
      L"password", L"암호", L"passcode", L"비밀번호", L"회의 암호", L"meeting password"};

  ComPtr<IUIAutomationElement> password_field;
  if (!FindElementByControlType(root, UIA_EditControlTypeId,
                                ToVector(password_keywords), &password_field)) {
    return false;
  }

  ComPtr<IUIAutomationValuePattern> value_pattern;
  if (FAILED(password_field->GetCurrentPatternAs(
          UIA_ValuePatternId, IID_PPV_ARGS(&value_pattern))) ||
      !value_pattern) {
    return false;
  }

  BSTR bstr_password = SysAllocString(password);
  if (!bstr_password) {
    return false;
  }

  const HRESULT hr = value_pattern->SetValue(bstr_password);
  SysFreeString(bstr_password);

  return SUCCEEDED(hr);
}

bool ClickPasswordConfirmButton(IUIAutomationElement* root) {
  if (!root) {
    return false;
  }

  const std::array<std::wstring, 4> confirm_keywords = {
      L"확인", L"ok", L"join", L"continue"};

  ComPtr<IUIAutomationElement> confirm_button;
  if (!FindElementByControlType(root, UIA_ButtonControlTypeId,
                                ToVector(confirm_keywords), &confirm_button)) {
    return false;
  }

  ComPtr<IUIAutomationInvokePattern> invoke_pattern;
  if (FAILED(confirm_button->GetCurrentPatternAs(
          UIA_InvokePatternId, IID_PPV_ARGS(&invoke_pattern))) ||
      !invoke_pattern) {
    return false;
  }

  return SUCCEEDED(invoke_pattern->Invoke());
}

bool WindowContainsText(IUIAutomationElement* root,
                        const std::vector<std::wstring>& keywords) {
  if (!root) {
    return false;
  }

  ComPtr<IUIAutomationCondition> text_condition;
  VARIANT control_type_variant;
  VariantInit(&control_type_variant);
  control_type_variant.vt = VT_I4;
  control_type_variant.lVal = UIA_TextControlTypeId;

  HRESULT hr = g_automation->CreatePropertyCondition(
      UIA_ControlTypePropertyId, control_type_variant, &text_condition);
  VariantClear(&control_type_variant);

  if (FAILED(hr) || !text_condition) {
    return false;
  }

  ComPtr<IUIAutomationElementArray> elements;
  hr = root->FindAll(TreeScope_Subtree, text_condition.Get(), &elements);
  if (FAILED(hr) || !elements) {
    return false;
  }

  int length = 0;
  elements->get_Length(&length);
  for (int i = 0; i < length; ++i) {
    ComPtr<IUIAutomationElement> text_element;
    if (FAILED(elements->GetElement(i, &text_element)) || !text_element) {
      continue;
    }

    if (ElementNameMatches(text_element.Get(), keywords)) {
      return true;
    }
  }

  return false;
}

BOOL EnsureAutomationReady() {
  if (g_automation) {
    return TRUE;
  }
  return ZoomAutomation_Initialize();
}

}  // namespace

extern "C" {

BOOL ZoomAutomation_Initialize() {
  // 입력: 없음 / 출력: 초기화 성공 여부 / 예외: COM 초기화에 실패하면 FALSE
  if (g_automation) {
    return TRUE;
  }

  const HRESULT co_result =
      CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
  if (SUCCEEDED(co_result)) {
    g_com_initialized = true;
  } else if (co_result == RPC_E_CHANGED_MODE) {
    // 이미 다른 스레드 모델로 초기화된 경우, COM은 계속 사용할 수 있다.
    g_com_initialized = false;
  } else {
    return FALSE;
  }

  HRESULT create_result = CoCreateInstance(
      CLSID_CUIAutomation, nullptr, CLSCTX_INPROC_SERVER,
      IID_PPV_ARGS(&g_automation));
  if (FAILED(create_result) || !g_automation) {
    ZoomAutomation_Cleanup();
    return FALSE;
  }

  return TRUE;
}

BOOL ZoomAutomation_FindZoomWindow(HWND* out_window_handle) {
  // 입력: out_window_handle에 HWND를 받아온다 / 출력: 찾으면 TRUE
  return TryFindZoomWindow(out_window_handle) ? TRUE : FALSE;
}

BOOL ZoomAutomation_EnterPassword(const wchar_t* password) {
  // 입력: password 문자열 / 출력: 암호 입력 및 확인 성공 여부
  if (!EnsureAutomationReady()) {
    return FALSE;
  }

  HWND zoom_window = nullptr;
  if (!TryFindZoomWindow(&zoom_window)) {
    return FALSE;
  }

  ComPtr<IUIAutomationElement> window_element;
  if (FAILED(g_automation->ElementFromHandle(zoom_window, &window_element)) ||
      !window_element) {
    return FALSE;
  }

  const bool password_ok = SetPasswordFieldValue(window_element.Get(), password);
  const bool confirm_clicked = ClickPasswordConfirmButton(window_element.Get());

  return (password_ok && confirm_clicked) ? TRUE : FALSE;
}

BOOL ZoomAutomation_EnterNameAndJoin(const wchar_t* user_name) {
  // 입력: user_name 문자열 / 출력: 이름 입력과 참가 버튼 클릭 성공 여부
  if (!EnsureAutomationReady()) {
    return FALSE;
  }

  HWND zoom_window = nullptr;
  if (!TryFindZoomWindow(&zoom_window)) {
    return FALSE;
  }

  ComPtr<IUIAutomationElement> window_element;
  if (FAILED(g_automation->ElementFromHandle(zoom_window, &window_element)) ||
      !window_element) {
    return FALSE;
  }

  const bool name_ok = SetNameFieldValue(window_element.Get(), user_name);
  const bool join_clicked = ClickJoinButton(window_element.Get());

  return (name_ok && join_clicked) ? TRUE : FALSE;
}

BOOL ZoomAutomation_CheckWaitingRoom() {
  // 입력: 없음 / 출력: 대기실 화면이면 TRUE
  if (!EnsureAutomationReady()) {
    return FALSE;
  }

  HWND zoom_window = nullptr;
  if (!TryFindZoomWindow(&zoom_window)) {
    return FALSE;
  }

  const std::array<std::wstring, 3> waiting_keywords = {
      L"대기실", L"waiting room", L"대기 중"};

  if (WindowHasKeyword(zoom_window, ToVector(waiting_keywords))) {
    return TRUE;
  }

  ComPtr<IUIAutomationElement> window_element;
  if (FAILED(g_automation->ElementFromHandle(zoom_window, &window_element)) ||
      !window_element) {
    return FALSE;
  }

  return WindowContainsText(window_element.Get(), ToVector(waiting_keywords))
             ? TRUE
             : FALSE;
}

BOOL ZoomAutomation_CheckHostNotStarted() {
  // 입력: 없음 / 출력: 호스트 미시작 메시지가 보이면 TRUE
  if (!EnsureAutomationReady()) {
    return FALSE;
  }

  HWND zoom_window = nullptr;
  if (!TryFindZoomWindow(&zoom_window)) {
    return FALSE;
  }

  const std::array<std::wstring, 4> host_keywords = {
      L"호스트", L"host", L"시작하지", L"has not started"};

  if (WindowHasKeyword(zoom_window, ToVector(host_keywords))) {
    return TRUE;
  }

  ComPtr<IUIAutomationElement> window_element;
  if (FAILED(g_automation->ElementFromHandle(zoom_window, &window_element)) ||
      !window_element) {
    return FALSE;
  }

  return WindowContainsText(window_element.Get(), ToVector(host_keywords))
             ? TRUE
             : FALSE;
}

BOOL ZoomAutomation_JoinWithAudio() {
  // 입력: 없음
  // 출력: "Join with Computer Audio" 버튼 클릭 성공 여부
  // 예외: UI Automation 초기화가 안 되어 있으면 FALSE
  if (!EnsureAutomationReady()) {
    return FALSE;
  }

  HWND zoom_window = nullptr;
  if (!TryFindZoomWindow(&zoom_window)) {
    return FALSE;
  }

  ComPtr<IUIAutomationElement> window_element;
  if (FAILED(g_automation->ElementFromHandle(zoom_window, &window_element)) ||
      !window_element) {
    return FALSE;
  }

  // "Join with Computer Audio" 또는 "컴퓨터 오디오로 참가" 버튼 찾기
  const std::array<std::wstring, 6> audio_join_keywords = {
      L"computer audio", L"join audio", L"컴퓨터 오디오",
      L"오디오로 참가", L"join with", L"audio로 참가"};

  ComPtr<IUIAutomationElement> audio_button;
  if (!FindElementByControlType(window_element.Get(), UIA_ButtonControlTypeId,
                                ToVector(audio_join_keywords), &audio_button)) {
    return FALSE;
  }

  ComPtr<IUIAutomationInvokePattern> invoke_pattern;
  if (FAILED(audio_button->GetCurrentPatternAs(
          UIA_InvokePatternId, IID_PPV_ARGS(&invoke_pattern))) ||
      !invoke_pattern) {
    return FALSE;
  }

  return SUCCEEDED(invoke_pattern->Invoke());
}

BOOL ZoomAutomation_SetVideoEnabled(BOOL enable) {
  // 입력: enable (TRUE=비디오 켜기, FALSE=비디오 끄기)
  // 출력: 비디오 체크박스 또는 버튼 설정 성공 여부
  // 예외: UI Automation 초기화가 안 되어 있으면 FALSE
  if (!EnsureAutomationReady()) {
    return FALSE;
  }

  HWND zoom_window = nullptr;
  if (!TryFindZoomWindow(&zoom_window)) {
    return FALSE;
  }

  ComPtr<IUIAutomationElement> window_element;
  if (FAILED(g_automation->ElementFromHandle(zoom_window, &window_element)) ||
      !window_element) {
    return FALSE;
  }

  // 비디오 관련 키워드 (참가 전 체크박스 또는 회의 중 버튼)
  const std::array<std::wstring, 8> video_keywords = {
      L"video", L"비디오", L"camera", L"카메라",
      L"start video", L"stop video", L"비디오 시작", L"비디오 중지"};

  // 먼저 체크박스 찾기 (참가 전 화면)
  ComPtr<IUIAutomationElement> video_checkbox;
  if (FindElementByControlType(window_element.Get(), UIA_CheckBoxControlTypeId,
                               ToVector(video_keywords), &video_checkbox)) {
    ComPtr<IUIAutomationTogglePattern> toggle_pattern;
    if (SUCCEEDED(video_checkbox->GetCurrentPatternAs(
            UIA_TogglePatternId, IID_PPV_ARGS(&toggle_pattern))) &&
        toggle_pattern) {
      ToggleState current_state;
      if (SUCCEEDED(toggle_pattern->get_CurrentToggleState(&current_state))) {
        BOOL is_on = (current_state == ToggleState_On);
        if (is_on != enable) {
          // 상태가 다르면 토글
          return SUCCEEDED(toggle_pattern->Toggle());
        }
        return TRUE;  // 이미 원하는 상태
      }
    }
  }

  // 체크박스가 없으면 버튼 찾기 (회의 중 화면)
  ComPtr<IUIAutomationElement> video_button;
  if (FindElementByControlType(window_element.Get(), UIA_ButtonControlTypeId,
                               ToVector(video_keywords), &video_button)) {
    ComPtr<IUIAutomationInvokePattern> invoke_pattern;
    if (SUCCEEDED(video_button->GetCurrentPatternAs(
            UIA_InvokePatternId, IID_PPV_ARGS(&invoke_pattern))) &&
        invoke_pattern) {
      return SUCCEEDED(invoke_pattern->Invoke());
    }
  }

  return FALSE;
}

BOOL ZoomAutomation_ClickBrowserDialog() {
  // 입력: 없음 / 출력: 브라우저 다이얼로그의 "Zoom Meetings 열기" 버튼 클릭 성공 여부
  if (!EnsureAutomationReady()) {
    return FALSE;
  }

  // 브라우저 창 찾기 (Chrome, Edge, Firefox 등)
  HWND browser_window = nullptr;
  EnumWindows([](HWND hwnd, LPARAM lparam) -> BOOL {
    if (!IsWindowVisible(hwnd)) {
      return TRUE;
    }

    wchar_t class_name[256] = {0};
    GetClassNameW(hwnd, class_name, static_cast<int>(std::size(class_name)));
    std::wstring class_str(class_name);

    // Chrome, Edge, Firefox 등 브라우저 클래스명
    const std::array<std::wstring, 4> browser_classes = {
        L"Chrome_WidgetWin_1", L"Chrome_WidgetWin_0",
        L"MozillaWindowClass", L"ApplicationFrameWindow"};

    for (const auto& browser_class : browser_classes) {
      if (class_str.find(browser_class) != std::wstring::npos) {
        *reinterpret_cast<HWND*>(lparam) = hwnd;
        return FALSE;  // Stop enumeration
      }
    }

    return TRUE;
  }, reinterpret_cast<LPARAM>(&browser_window));

  if (!browser_window) {
    return FALSE;
  }

  ComPtr<IUIAutomationElement> browser_element;
  if (FAILED(g_automation->ElementFromHandle(browser_window, &browser_element)) ||
      !browser_element) {
    return FALSE;
  }

  // "Zoom Meetings 열기", "허용", "열기" 등의 버튼 찾기
  const std::array<std::wstring, 8> dialog_button_keywords = {
      L"zoom meetings 열기", L"zoom meetings", L"열기", L"open",
      L"허용", L"allow", L"확인", L"ok"};

  ComPtr<IUIAutomationElement> dialog_button;
  if (!FindElementByControlType(browser_element.Get(), UIA_ButtonControlTypeId,
                                ToVector(dialog_button_keywords), &dialog_button)) {
    return FALSE;
  }

  ComPtr<IUIAutomationInvokePattern> invoke_pattern;
  if (FAILED(dialog_button->GetCurrentPatternAs(
          UIA_InvokePatternId, IID_PPV_ARGS(&invoke_pattern))) ||
      !invoke_pattern) {
    return FALSE;
  }

  return SUCCEEDED(invoke_pattern->Invoke());
}

BOOL ZoomAutomation_SetMuted(BOOL mute) {
  // 입력: mute (TRUE=음소거, FALSE=음소거 해제)
  // 출력: 음소거 버튼 클릭 성공 여부
  // 예외: UI Automation 초기화가 안 되어 있으면 FALSE
  if (!EnsureAutomationReady()) {
    return FALSE;
  }

  HWND zoom_window = nullptr;
  if (!TryFindZoomWindow(&zoom_window)) {
    return FALSE;
  }

  ComPtr<IUIAutomationElement> window_element;
  if (FAILED(g_automation->ElementFromHandle(zoom_window, &window_element)) ||
      !window_element) {
    return FALSE;
  }

  // 음소거 관련 키워드
  const std::array<std::wstring, 8> mute_keywords = {
      L"mute", L"unmute", L"음소거", L"음소거 해제",
      L"audio", L"오디오", L"microphone", L"마이크"};

  ComPtr<IUIAutomationElement> mute_button;
  if (!FindElementByControlType(window_element.Get(), UIA_ButtonControlTypeId,
                                ToVector(mute_keywords), &mute_button)) {
    return FALSE;
  }

  // 버튼 이름으로 현재 상태 확인
  VARIANT name_variant;
  VariantInit(&name_variant);
  BOOL should_click = FALSE;

  if (SUCCEEDED(mute_button->GetCurrentPropertyValue(
          UIA_NamePropertyId, &name_variant)) &&
      name_variant.vt == VT_BSTR && name_variant.bstrVal != nullptr) {
    std::wstring button_name(name_variant.bstrVal);
    std::wstring lower_name = ToLower(button_name);

    // "Mute" 버튼이면 현재 음소거 해제 상태
    // "Unmute" 버튼이면 현재 음소거 상태
    BOOL is_muted = (lower_name.find(L"unmute") != std::wstring::npos ||
                     lower_name.find(L"음소거 해제") != std::wstring::npos);

    should_click = (is_muted != mute);
  } else {
    // 버튼 이름을 알 수 없으면 일단 클릭
    should_click = TRUE;
  }

  VariantClear(&name_variant);

  if (!should_click) {
    return TRUE;  // 이미 원하는 상태
  }

  ComPtr<IUIAutomationInvokePattern> invoke_pattern;
  if (FAILED(mute_button->GetCurrentPatternAs(
          UIA_InvokePatternId, IID_PPV_ARGS(&invoke_pattern))) ||
      !invoke_pattern) {
    return FALSE;
  }

  return SUCCEEDED(invoke_pattern->Invoke());
}

void ZoomAutomation_Cleanup() {
  // 입력: 없음 / 출력: 없음 / 예외: 없음 (자원만 정리)
  if (g_automation) {
    g_automation.Reset();
  }

  if (g_com_initialized) {
    CoUninitialize();
    g_com_initialized = false;
  }
}

}  // extern "C"
