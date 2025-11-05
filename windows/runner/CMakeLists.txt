cmake_minimum_required(VERSION 3.14)
project(runner LANGUAGES CXX)

# Define the application target. To change its name, change BINARY_NAME in the
# top-level CMakeLists.txt, not the value here, or `flutter run` will no longer
# work.
#
# Any new source files that you add to the application should be added here.
add_executable(${BINARY_NAME} WIN32
  "flutter_window.cpp"
  "main.cpp"
  "utils.cpp"
  "win32_window.cpp"
  "native_screen_recorder.cpp"
  "libav_encoder.cpp"
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
  "Runner.rc"
  "runner.exe.manifest"
)

# Apply the standard set of build settings. This can be removed for applications
# that need different build settings.
apply_standard_settings(${BINARY_NAME})

# Enable symbol exports from the executable for Flutter FFI
# This allows DynamicLibrary.executable() to find native functions
set_target_properties(${BINARY_NAME} PROPERTIES ENABLE_EXPORTS ON)

# C++/WinRT 지원을 위한 C++17 설정
set_target_properties(${BINARY_NAME} PROPERTIES CXX_STANDARD 17)
set_target_properties(${BINARY_NAME} PROPERTIES CXX_STANDARD_REQUIRED ON)

# Add preprocessor definitions for the build version.
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION=\"${FLUTTER_VERSION}\"")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_MAJOR=${FLUTTER_VERSION_MAJOR}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_MINOR=${FLUTTER_VERSION_MINOR}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_PATCH=${FLUTTER_VERSION_PATCH}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_BUILD=${FLUTTER_VERSION_BUILD}")

# Disable Windows macros that collide with C++ standard library functions.
target_compile_definitions(${BINARY_NAME} PRIVATE "NOMINMAX")

# Force UTF-8 encoding for source files (fixes Korean comments issue)
if(MSVC)
  target_compile_options(${BINARY_NAME} PRIVATE /utf-8)
endif()

# FFmpeg 라이브러리 설정
# CMAKE_SOURCE_DIR은 windows/ 디렉토리이므로, 프로젝트 루트로 가려면 한 단계 위로
set(FFMPEG_DIR "${CMAKE_SOURCE_DIR}/../third_party/ffmpeg")

# Add dependency libraries and include directories. Add any application-specific
# dependencies here.
target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")
target_include_directories(${BINARY_NAME} PRIVATE "${FFMPEG_DIR}/include")

target_link_libraries(${BINARY_NAME} PRIVATE flutter flutter_wrapper_app)
target_link_libraries(${BINARY_NAME} PRIVATE "dwmapi.lib")

# FFmpeg 라이브러리 링크
target_link_libraries(${BINARY_NAME} PRIVATE
  "${FFMPEG_DIR}/lib/avcodec.lib"
  "${FFMPEG_DIR}/lib/avformat.lib"
  "${FFMPEG_DIR}/lib/avutil.lib"
  "${FFMPEG_DIR}/lib/swscale.lib"
  "${FFMPEG_DIR}/lib/swresample.lib"
)

# Run the Flutter tool portions of the build. This must not be removed.
add_dependencies(${BINARY_NAME} flutter_assemble)
