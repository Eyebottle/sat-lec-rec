# libavcodec 기반 인코더 설계 문서

**작성일**: 2025-01-04
**목적**: FFmpeg Named Pipe 방식을 libavcodec 직접 사용 방식으로 전환
**참고**: OBS Studio 아키텍처, FFmpeg muxing.c 예제

---

## 1. 배경 및 목표

### 현재 문제
- **FFmpeg 프로세스 + Named Pipe 2개** 방식 사용 중
- Named Pipe는 **1개만 안정적**, 2개 동시 사용 시 두 번째 파이프 연결 실패
- 현재 Video-only 모드로 임시 해결 (Audio 비활성화)

### 목표
- **libavcodec/libavformat 라이브러리 직접 링크**
- Video (H.264) + Audio (AAC)를 **메모리**에서 인코딩 및 muxing
- OBS, Zoom 등 전문 녹화 프로그램과 동일한 방식
- Named Pipe 완전 제거

---

## 2. 아키텍처 개요

### 2.1 전체 구조

```
┌─────────────────────────────────────────────────────────────┐
│                   NativeRecorder (C++)                      │
│                                                             │
│  ┌──────────────┐          ┌───────────────┐               │
│  │ DXGI Desktop │          │ WASAPI Audio  │               │
│  │ Duplication  │          │ Loopback      │               │
│  │ (24 fps)     │          │ (48kHz)       │               │
│  └──────┬───────┘          └───────┬───────┘               │
│         │                          │                        │
│         v                          v                        │
│  ┌────────────┐          ┌────────────────┐                │
│  │ Video Queue│          │  Audio Queue   │                │
│  │ (BGRA)     │          │  (float32)     │                │
│  └──────┬─────┘          └───────┬────────┘                │
│         │                        │                          │
│         └────────┬───────────────┘                          │
│                  │                                          │
│                  v                                          │
│         ┌────────────────┐                                  │
│         │ LibavEncoder   │  ← 새로 구현                     │
│         │  (New Class)   │                                  │
│         └────────┬───────┘                                  │
│                  │                                          │
│    ┌─────────────┼─────────────┐                           │
│    v             v              v                           │
│ ┌──────┐   ┌──────┐   ┌──────────┐                         │
│ │H.264 │   │ AAC  │   │   MP4    │                         │
│ │Encode│   │Encode│   │  Muxer   │                         │
│ └──┬───┘   └──┬───┘   └────┬─────┘                         │
│    └─────────┬┘            │                               │
│              v             v                                │
│    ┌─────────────────────────┐                             │
│    │ Interleaving Queue      │                             │
│    │ (DTS sorted)            │                             │
│    └───────────┬─────────────┘                             │
│                v                                            │
│    ┌─────────────────────────┐                             │
│    │  MP4 File (.recording)  │                             │
│    │  (Fragmented)           │                             │
│    └─────────────────────────┘                             │
└─────────────────────────────────────────────────────────────┘
```

### 2.2 데이터 흐름

1. **캡처 (Capture Thread)**
   ```cpp
   DXGI → BGRA Frame → g_frame_queue
   WASAPI → Float32 Audio → g_audio_queue
   ```

2. **인코딩 (Encoder Thread)**
   ```cpp
   while (recording || has_data) {
       // Video 처리
       if (!g_frame_queue.empty()) {
           frame = g_frame_queue.pop();
           libav_encoder->EncodeVideo(frame.data);
       }

       // Audio 처리
       if (!g_audio_queue.empty()) {
           audio = g_audio_queue.pop();
           libav_encoder->EncodeAudio(audio.data);
       }
   }
   ```

3. **Muxing (LibavEncoder 내부)**
   ```cpp
   avcodec_send_frame() → avcodec_receive_packet()
   → av_packet_rescale_ts() → av_interleaved_write_frame()
   ```

---

## 3. LibavEncoder 클래스 설계

### 3.1 인터페이스 (libav_encoder.h)

```cpp
#ifndef LIBAV_ENCODER_H_
#define LIBAV_ENCODER_H_

#include <string>
#include <cstdint>

extern "C" {
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavutil/opt.h>
#include <libswscale/swscale.h>
#include <libswresample/swresample.h>
}

struct LibavEncoderConfig {
    std::wstring output_path;

    // Video 설정
    int video_width = 1920;
    int video_height = 1080;
    int video_fps = 24;

    // Audio 설정
    int audio_sample_rate = 48000;
    int audio_channels = 2;

    // 인코딩 설정
    bool enable_fragmented_mp4 = true;
    int h264_crf = 23;              // 품질 (18-28 권장)
    const char* h264_preset = "veryfast";
    int aac_bitrate = 192000;       // 192kbps
};

class LibavEncoder {
public:
    LibavEncoder();
    ~LibavEncoder();

    // 초기화 및 종료
    bool Start(const LibavEncoderConfig& config);
    void Stop();
    bool IsRunning() const { return is_running_; }

    // 프레임/오디오 인코딩
    bool EncodeVideo(const uint8_t* bgra_data, size_t length);
    bool EncodeAudio(const uint8_t* float32_data, size_t length);

    // 에러 처리
    std::string GetLastError() const { return last_error_; }

private:
    // 초기화 헬퍼
    bool InitializeFormat();
    bool InitializeVideoCodec();
    bool InitializeAudioCodec();
    bool WriteHeader();
    bool WriteTrailer();

    // 인코딩 헬퍼
    bool SendVideoFrame(AVFrame* frame);
    bool SendAudioFrame(AVFrame* frame);
    bool ReceiveAndWritePackets(AVCodecContext* codec_ctx, int stream_index);

    // 변환 헬퍼
    bool ConvertBGRAToYUV420(const uint8_t* bgra, AVFrame* yuv_frame);
    bool ConvertFloat32ToPlanar(const uint8_t* float32, AVFrame* audio_frame);

    // 리소스 정리
    void Cleanup();
    void SetLastError(const std::string& message);

    // 설정
    LibavEncoderConfig config_{};

    // AVFormat
    AVFormatContext* format_ctx_ = nullptr;

    // Video
    AVCodecContext* video_codec_ctx_ = nullptr;
    AVStream* video_stream_ = nullptr;
    AVFrame* video_frame_ = nullptr;
    SwsContext* sws_ctx_ = nullptr;
    int64_t next_video_pts_ = 0;

    // Audio
    AVCodecContext* audio_codec_ctx_ = nullptr;
    AVStream* audio_stream_ = nullptr;
    AVFrame* audio_frame_ = nullptr;
    SwrContext* swr_ctx_ = nullptr;
    int64_t next_audio_pts_ = 0;

    // 상태
    bool is_running_ = false;
    std::string last_error_;
};

#endif  // LIBAV_ENCODER_H_
```

### 3.2 핵심 메서드 설명

#### 3.2.1 Start() - 초기화

```cpp
bool LibavEncoder::Start(const LibavEncoderConfig& config) {
    config_ = config;

    // 1. AVFormatContext 생성
    if (!InitializeFormat()) return false;

    // 2. Video 스트림 생성
    if (!InitializeVideoCodec()) return false;

    // 3. Audio 스트림 생성
    if (!InitializeAudioCodec()) return false;

    // 4. MP4 파일 열기 및 헤더 작성
    if (!WriteHeader()) return false;

    is_running_ = true;
    return true;
}
```

**세부 구현**:

```cpp
bool LibavEncoder::InitializeFormat() {
    // MP4 muxer용 AVFormatContext 할당
    int ret = avformat_alloc_output_context2(
        &format_ctx_,
        nullptr,
        "mp4",
        WideToUTF8(config_.output_path).c_str()
    );

    if (ret < 0) {
        SetLastError("avformat_alloc_output_context2 실패");
        return false;
    }

    // Fragmented MP4 옵션 설정
    if (config_.enable_fragmented_mp4) {
        av_dict_set(&format_ctx_->metadata, "movflags",
                   "frag_keyframe+empty_moov+default_base_moof", 0);
    }

    return true;
}

bool LibavEncoder::InitializeVideoCodec() {
    // 1. H.264 인코더 찾기
    const AVCodec* codec = avcodec_find_encoder(AV_CODEC_ID_H264);
    if (!codec) {
        SetLastError("H.264 인코더를 찾을 수 없음");
        return false;
    }

    // 2. 스트림 생성
    video_stream_ = avformat_new_stream(format_ctx_, nullptr);
    if (!video_stream_) {
        SetLastError("Video 스트림 생성 실패");
        return false;
    }
    video_stream_->id = 0;

    // 3. 코덱 컨텍스트 할당
    video_codec_ctx_ = avcodec_alloc_context3(codec);
    if (!video_codec_ctx_) {
        SetLastError("Video 코덱 컨텍스트 할당 실패");
        return false;
    }

    // 4. 코덱 파라미터 설정
    video_codec_ctx_->codec_id = AV_CODEC_ID_H264;
    video_codec_ctx_->codec_type = AVMEDIA_TYPE_VIDEO;
    video_codec_ctx_->width = config_.video_width;
    video_codec_ctx_->height = config_.video_height;
    video_codec_ctx_->pix_fmt = AV_PIX_FMT_YUV420P;
    video_codec_ctx_->time_base = {1, config_.video_fps};
    video_codec_ctx_->framerate = {config_.video_fps, 1};
    video_codec_ctx_->gop_size = config_.video_fps;  // 1초마다 키프레임

    // CRF 품질 설정
    char crf_str[8];
    snprintf(crf_str, sizeof(crf_str), "%d", config_.h264_crf);
    av_opt_set(video_codec_ctx_->priv_data, "crf", crf_str, 0);
    av_opt_set(video_codec_ctx_->priv_data, "preset", config_.h264_preset, 0);
    av_opt_set(video_codec_ctx_->priv_data, "tune", "zerolatency", 0);

    // 5. 인코더 열기
    int ret = avcodec_open2(video_codec_ctx_, codec, nullptr);
    if (ret < 0) {
        SetLastError("Video 인코더 열기 실패");
        return false;
    }

    // 6. 스트림에 파라미터 복사
    avcodec_parameters_from_context(video_stream_->codecpar, video_codec_ctx_);
    video_stream_->time_base = video_codec_ctx_->time_base;

    // 7. AVFrame 할당
    video_frame_ = av_frame_alloc();
    video_frame_->format = AV_PIX_FMT_YUV420P;
    video_frame_->width = config_.video_width;
    video_frame_->height = config_.video_height;
    av_frame_get_buffer(video_frame_, 0);

    // 8. SwsContext 생성 (BGRA → YUV420P 변환용)
    sws_ctx_ = sws_getContext(
        config_.video_width, config_.video_height, AV_PIX_FMT_BGRA,
        config_.video_width, config_.video_height, AV_PIX_FMT_YUV420P,
        SWS_BILINEAR, nullptr, nullptr, nullptr
    );

    return true;
}

bool LibavEncoder::InitializeAudioCodec() {
    // 1. AAC 인코더 찾기
    const AVCodec* codec = avcodec_find_encoder(AV_CODEC_ID_AAC);
    if (!codec) {
        SetLastError("AAC 인코더를 찾을 수 없음");
        return false;
    }

    // 2. 스트림 생성
    audio_stream_ = avformat_new_stream(format_ctx_, nullptr);
    if (!audio_stream_) {
        SetLastError("Audio 스트림 생성 실패");
        return false;
    }
    audio_stream_->id = 1;

    // 3. 코덱 컨텍스트 할당
    audio_codec_ctx_ = avcodec_alloc_context3(codec);
    if (!audio_codec_ctx_) {
        SetLastError("Audio 코덱 컨텍스트 할당 실패");
        return false;
    }

    // 4. 코덱 파라미터 설정
    audio_codec_ctx_->codec_id = AV_CODEC_ID_AAC;
    audio_codec_ctx_->codec_type = AVMEDIA_TYPE_AUDIO;
    audio_codec_ctx_->sample_rate = config_.audio_sample_rate;
    audio_codec_ctx_->ch_layout = AV_CHANNEL_LAYOUT_STEREO;
    audio_codec_ctx_->sample_fmt = AV_SAMPLE_FMT_FLTP;  // Planar float
    audio_codec_ctx_->bit_rate = config_.aac_bitrate;
    audio_codec_ctx_->time_base = {1, config_.audio_sample_rate};

    // 5. 인코더 열기
    int ret = avcodec_open2(audio_codec_ctx_, codec, nullptr);
    if (ret < 0) {
        SetLastError("Audio 인코더 열기 실패");
        return false;
    }

    // 6. 스트림에 파라미터 복사
    avcodec_parameters_from_context(audio_stream_->codecpar, audio_codec_ctx_);
    audio_stream_->time_base = audio_codec_ctx_->time_base;

    // 7. AVFrame 할당 (AAC는 1024 샘플/프레임)
    audio_frame_ = av_frame_alloc();
    audio_frame_->format = AV_SAMPLE_FMT_FLTP;
    audio_frame_->ch_layout = AV_CHANNEL_LAYOUT_STEREO;
    audio_frame_->sample_rate = config_.audio_sample_rate;
    audio_frame_->nb_samples = audio_codec_ctx_->frame_size;  // 보통 1024
    av_frame_get_buffer(audio_frame_, 0);

    // 8. SwrContext 생성 (Interleaved Float → Planar Float 변환용)
    swr_alloc_set_opts2(
        &swr_ctx_,
        &audio_codec_ctx_->ch_layout,
        audio_codec_ctx_->sample_fmt,
        audio_codec_ctx_->sample_rate,
        &audio_codec_ctx_->ch_layout,
        AV_SAMPLE_FMT_FLT,  // 입력은 Interleaved float
        config_.audio_sample_rate,
        0, nullptr
    );
    swr_init(swr_ctx_);

    return true;
}

bool LibavEncoder::WriteHeader() {
    // 1. 파일 열기
    int ret = avio_open(&format_ctx_->pb,
                       WideToUTF8(config_.output_path).c_str(),
                       AVIO_FLAG_WRITE);
    if (ret < 0) {
        SetLastError("출력 파일 열기 실패");
        return false;
    }

    // 2. MP4 헤더 작성
    ret = avformat_write_header(format_ctx_, nullptr);
    if (ret < 0) {
        SetLastError("avformat_write_header 실패");
        return false;
    }

    return true;
}
```

#### 3.2.2 EncodeVideo() - 비디오 인코딩

```cpp
bool LibavEncoder::EncodeVideo(const uint8_t* bgra_data, size_t length) {
    if (!is_running_) return false;

    // 1. BGRA → YUV420P 변환
    const uint8_t* src_data[1] = { bgra_data };
    int src_linesize[1] = { config_.video_width * 4 };  // BGRA = 4 bytes/pixel

    sws_scale(
        sws_ctx_,
        src_data, src_linesize, 0, config_.video_height,
        video_frame_->data, video_frame_->linesize
    );

    // 2. PTS 설정
    video_frame_->pts = next_video_pts_++;

    // 3. 인코더에 전송
    return SendVideoFrame(video_frame_);
}

bool LibavEncoder::SendVideoFrame(AVFrame* frame) {
    // 1. 프레임을 인코더에 전송
    int ret = avcodec_send_frame(video_codec_ctx_, frame);
    if (ret < 0) {
        SetLastError("avcodec_send_frame(video) 실패");
        return false;
    }

    // 2. 패킷 수신 및 muxing
    return ReceiveAndWritePackets(video_codec_ctx_, video_stream_->index);
}
```

#### 3.2.3 EncodeAudio() - 오디오 인코딩

```cpp
bool LibavEncoder::EncodeAudio(const uint8_t* float32_data, size_t length) {
    if (!is_running_) return false;

    // 1. Interleaved Float32 → Planar Float 변환
    const uint8_t* src_data[1] = { float32_data };
    swr_convert(
        swr_ctx_,
        audio_frame_->data,
        audio_frame_->nb_samples,
        src_data,
        audio_frame_->nb_samples
    );

    // 2. PTS 설정
    audio_frame_->pts = next_audio_pts_;
    next_audio_pts_ += audio_frame_->nb_samples;

    // 3. 인코더에 전송
    return SendAudioFrame(audio_frame_);
}

bool LibavEncoder::SendAudioFrame(AVFrame* frame) {
    // 1. 프레임을 인코더에 전송
    int ret = avcodec_send_frame(audio_codec_ctx_, frame);
    if (ret < 0) {
        SetLastError("avcodec_send_frame(audio) 실패");
        return false;
    }

    // 2. 패킷 수신 및 muxing
    return ReceiveAndWritePackets(audio_codec_ctx_, audio_stream_->index);
}
```

#### 3.2.4 ReceiveAndWritePackets() - Interleaving 및 Muxing

```cpp
bool LibavEncoder::ReceiveAndWritePackets(AVCodecContext* codec_ctx, int stream_index) {
    AVPacket* pkt = av_packet_alloc();

    while (true) {
        // 1. 인코딩된 패킷 수신
        int ret = avcodec_receive_packet(codec_ctx, pkt);

        if (ret == AVERROR(EAGAIN) || ret == AVERROR_EOF) {
            // 더 이상 패킷 없음
            break;
        } else if (ret < 0) {
            SetLastError("avcodec_receive_packet 실패");
            av_packet_free(&pkt);
            return false;
        }

        // 2. 타임스탬프 변환 (codec time_base → stream time_base)
        AVStream* stream = format_ctx_->streams[stream_index];
        av_packet_rescale_ts(pkt, codec_ctx->time_base, stream->time_base);
        pkt->stream_index = stream_index;

        // 3. Interleaved write (자동으로 DTS 순서 정렬)
        ret = av_interleaved_write_frame(format_ctx_, pkt);
        if (ret < 0) {
            SetLastError("av_interleaved_write_frame 실패");
            av_packet_free(&pkt);
            return false;
        }
    }

    av_packet_free(&pkt);
    return true;
}
```

#### 3.2.5 Stop() - 종료

```cpp
void LibavEncoder::Stop() {
    if (!is_running_) return;

    // 1. 남은 프레임 플러시
    avcodec_send_frame(video_codec_ctx_, nullptr);  // Flush
    ReceiveAndWritePackets(video_codec_ctx_, video_stream_->index);

    avcodec_send_frame(audio_codec_ctx_, nullptr);  // Flush
    ReceiveAndWritePackets(audio_codec_ctx_, audio_stream_->index);

    // 2. MP4 트레일러 작성
    av_write_trailer(format_ctx_);

    // 3. 리소스 정리
    Cleanup();

    is_running_ = false;
}

void LibavEncoder::Cleanup() {
    // Video
    if (sws_ctx_) {
        sws_freeContext(sws_ctx_);
        sws_ctx_ = nullptr;
    }
    if (video_frame_) {
        av_frame_free(&video_frame_);
    }
    if (video_codec_ctx_) {
        avcodec_free_context(&video_codec_ctx_);
    }

    // Audio
    if (swr_ctx_) {
        swr_free(&swr_ctx_);
    }
    if (audio_frame_) {
        av_frame_free(&audio_frame_);
    }
    if (audio_codec_ctx_) {
        avcodec_free_context(&audio_codec_ctx_);
    }

    // Format
    if (format_ctx_) {
        if (format_ctx_->pb) {
            avio_closep(&format_ctx_->pb);
        }
        avformat_free_context(format_ctx_);
        format_ctx_ = nullptr;
    }
}
```

---

## 4. NativeRecorder 통합

### 4.1 기존 코드 변경 사항

**파일**: `native_screen_recorder.cpp`

```cpp
// 전역 변수
static LibavEncoder g_libav_encoder;  // FFmpegPipeline 대체

// StartRecording 함수 수정
NATIVE_RECORDER_EXPORT int32_t NativeRecorder_StartRecording(...) {
    // ... (기존 초기화 코드)

    // FFmpegPipeline 대신 LibavEncoder 사용
    LibavEncoderConfig encoder_config;
    encoder_config.output_path = w_output_path;
    encoder_config.video_width = width;
    encoder_config.video_height = height;
    encoder_config.video_fps = fps;
    encoder_config.audio_sample_rate = g_wave_format->nSamplesPerSec;
    encoder_config.audio_channels = g_wave_format->nChannels;
    encoder_config.enable_fragmented_mp4 = true;
    encoder_config.h264_crf = 23;
    encoder_config.h264_preset = "veryfast";
    encoder_config.aac_bitrate = 192000;

    if (!g_libav_encoder.Start(encoder_config)) {
        SetLastError(g_libav_encoder.GetLastError());
        return -1;
    }

    // ... (나머지 코드)
}

// ProcessNextVideoFrame 수정
static bool ProcessNextVideoFrame() {
    FrameData frame;
    {
        std::lock_guard<std::mutex> lock(g_queue_mutex);
        if (g_frame_queue.empty()) return false;
        frame = g_frame_queue.front();
        g_frame_queue.pop();
    }

    // Named Pipe 쓰기 대신 LibavEncoder 호출
    bool success = g_libav_encoder.EncodeVideo(
        frame.data.data(),
        frame.data.size()
    );

    if (success) {
        g_total_video_frames++;
    }

    return success;
}

// ProcessNextAudioSample 수정
static bool ProcessNextAudioSample() {
    AudioSample sample;
    {
        std::lock_guard<std::mutex> lock(g_audio_queue_mutex);
        if (g_audio_queue.empty()) return false;
        sample = g_audio_queue.front();
        g_audio_queue.pop();
    }

    // Named Pipe 쓰기 대신 LibavEncoder 호출
    bool success = g_libav_encoder.EncodeAudio(
        sample.data.data(),
        sample.data.size()
    );

    if (success) {
        g_total_audio_samples += sample.data.size() / sizeof(float) / g_wave_format->nChannels;
    }

    return success;
}

// StopRecording 수정
NATIVE_RECORDER_EXPORT int32_t NativeRecorder_StopRecording() {
    // ... (기존 코드)

    // FFmpegPipeline Stop 대신
    g_libav_encoder.Stop();

    // ... (나머지 정리 코드)
}
```

### 4.2 제거되는 코드

- `ffmpeg_pipeline.h` (전체)
- `ffmpeg_pipeline.cpp` (전체)
- Named Pipe 관련 모든 로직
- FFmpeg 프로세스 실행 로직

---

## 5. 빌드 시스템 변경

### 5.1 FFmpeg 라이브러리 링크

**파일**: `windows/runner/CMakeLists.txt`

```cmake
# FFmpeg 라이브러리 경로
set(FFMPEG_DIR "${CMAKE_SOURCE_DIR}/third_party/ffmpeg")

# Include 디렉토리 추가
include_directories(${FFMPEG_DIR}/include)

# 라이브러리 링크
link_directories(${FFMPEG_DIR}/lib)

target_link_libraries(${BINARY_NAME} PRIVATE
    # 기존 라이브러리들...

    # FFmpeg 라이브러리 추가
    avcodec
    avformat
    avutil
    swscale
    swresample
)
```

### 5.2 FFmpeg 바이너리 준비

**필요한 파일** (`third_party/ffmpeg/`):

```
third_party/ffmpeg/
├── include/
│   ├── libavcodec/
│   ├── libavformat/
│   ├── libavutil/
│   ├── libswscale/
│   └── libswresample/
├── lib/
│   ├── avcodec.lib
│   ├── avformat.lib
│   ├── avutil.lib
│   ├── swscale.lib
│   └── swresample.lib
└── bin/
    ├── avcodec-*.dll
    ├── avformat-*.dll
    ├── avutil-*.dll
    ├── swscale-*.dll
    └── swresample-*.dll
```

**다운로드 소스**: https://github.com/BtbN/FFmpeg-Builds/releases

---

## 6. 타임라인

| Phase | 작업 | 예상 시간 |
|-------|------|-----------|
| **Phase 1** | FFmpeg 라이브러리 다운로드 및 빌드 설정 | 0.5일 |
| **Phase 2** | LibavEncoder 클래스 구현 (Video만) | 2일 |
| **Phase 3** | Video 인코딩 테스트 및 디버깅 | 1일 |
| **Phase 4** | Audio 인코더 추가 | 1.5일 |
| **Phase 5** | Video+Audio 통합 테스트 | 1일 |
| **Phase 6** | NativeRecorder 통합 | 1일 |
| **Phase 7** | 30분 장시간 테스트 및 안정화 | 2일 |
| **Phase 8** | 문서화 및 코드 정리 | 1일 |
| **총합** | | **10일** |

---

## 7. 주요 고려사항

### 7.1 성능 최적화

- **Zero-copy 최대화**: SwsContext, SwrContext 재사용
- **메모리 풀링**: AVFrame, AVPacket 재사용
- **비동기 I/O**: avio_open2의 AVIO_FLAG_NONBLOCK 옵션 (필요시)

### 7.2 에러 처리

- **인코더 실패**: 프레임 스킵 후 계속 진행
- **Muxing 실패**: 즉시 녹화 중지 및 사용자 알림
- **디스크 부족**: avio_write 반환값 체크

### 7.3 타임스탬프 동기화

- **Video PTS**: `next_video_pts_++` (프레임 단위)
- **Audio PTS**: `next_audio_pts_ += nb_samples` (샘플 단위)
- **Drift 보정**: 필요시 Audio PTS를 Video 기준으로 조정

### 7.4 Fragmented MP4

- **movflags**: `frag_keyframe+empty_moov+default_base_moof`
- **장점**: 크래시 시에도 기록된 부분 재생 가능
- **주의**: 일부 플레이어에서 seeking 제한

---

## 8. 테스트 계획

### 8.1 단위 테스트

1. **LibavEncoder::InitializeFormat()** - AVFormatContext 생성 확인
2. **LibavEncoder::InitializeVideoCodec()** - H.264 인코더 초기화
3. **LibavEncoder::InitializeAudioCodec()** - AAC 인코더 초기화
4. **LibavEncoder::EncodeVideo()** - 단일 프레임 인코딩
5. **LibavEncoder::EncodeAudio()** - 단일 오디오 샘플 인코딩

### 8.2 통합 테스트

1. **10초 녹화** - 기본 동작 확인
2. **30초 녹화** - A/V 동기화 확인
3. **5분 녹화** - 메모리 누수 확인
4. **30분 녹화** - CPU 안정성 확인
5. **크래시 테스트** - 중간에 강제 종료 후 파일 재생 가능 여부

### 8.3 검증 기준

- ✅ **파일 재생**: VLC, Windows Media Player에서 정상 재생
- ✅ **A/V 동기화**: ffprobe로 drift < 100ms 확인
- ✅ **CPU 사용률**: 평균 50% 이하
- ✅ **메모리**: 30분 녹화 후 증가량 < 500MB
- ✅ **드롭 프레임**: ffprobe로 < 1% 확인

---

## 9. 참고 자료

- **FFmpeg 공식 문서**: https://ffmpeg.org/doxygen/trunk/
- **FFmpeg 예제**: https://github.com/FFmpeg/FFmpeg/tree/master/doc/examples
- **OBS Studio 소스**: https://github.com/obsproject/obs-studio
- **H.264 설정 가이드**: https://trac.ffmpeg.org/wiki/Encode/H.264
- **AAC 설정 가이드**: https://trac.ffmpeg.org/wiki/Encode/AAC

---

## 10. 마이그레이션 체크리스트

- [ ] FFmpeg 라이브러리 다운로드 (BtbN builds)
- [ ] CMakeLists.txt 수정
- [ ] libav_encoder.h 생성
- [ ] libav_encoder.cpp 구현 (Video)
- [ ] Video-only 테스트 (10초)
- [ ] libav_encoder.cpp 구현 (Audio)
- [ ] Video+Audio 테스트 (30초)
- [ ] native_screen_recorder.cpp 수정
- [ ] ProcessNextVideoFrame 수정
- [ ] ProcessNextAudioSample 수정
- [ ] 통합 테스트 (5분)
- [ ] ffmpeg_pipeline.{h,cpp} 삭제
- [ ] 장시간 테스트 (30분)
- [ ] 문서 업데이트
- [ ] Git 커밋

---

**작성자**: Claude Code
**검토자**: TBD
**승인**: TBD
