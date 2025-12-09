// libavcodec 기반 Video+Audio 인코더
// FFmpeg 프로세스 + Named Pipe 방식을 대체

#ifndef SAT_LEC_REC_LIBAV_ENCODER_H_
#define SAT_LEC_REC_LIBAV_ENCODER_H_

#include <windows.h>
#include <cstddef>
#include <cstdint>
#include <string>
#include <vector>

// FFmpeg 헤더 (C 라이브러리이므로 extern "C" 필요)
extern "C" {
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavutil/opt.h>
#include <libavutil/channel_layout.h>
#include <libswscale/swscale.h>
#include <libswresample/swresample.h>
}

/// 입력: libavcodec 인코더 설정 (출력 경로, 해상도, FPS 등)
/// 출력: 인코더 초기화 및 실행 제어 함수 제공
/// 예외: 초기화 실패 시 Start()가 false 반환, GetLastError()로 원인 확인
struct LibavEncoderConfig {
    std::wstring output_path;  // MP4 출력 파일 경로

    // Video 설정
    int video_width = 1920;
    int video_height = 1080;
    int video_fps = 24;

    // Audio 설정
    int audio_sample_rate = 48000;
    int audio_channels = 2;

    // 인코딩 옵션
    bool enable_fragmented_mp4 = true;  // 크래시 복구용
    int h264_crf = 23;                  // 품질 (18=최고, 28=낮음)
    const char* h264_preset = "veryfast";  // ultrafast, superfast, veryfast, faster, fast, medium, slow, slower, veryslow
    int aac_bitrate = 192000;           // 192kbps
};

/// 입력: LibavEncoderConfig, BGRA 비디오 프레임, Float32 오디오 샘플
/// 출력: H.264+AAC로 인코딩된 MP4 파일
/// 예외: 인코딩 실패 시 EncodeVideo/EncodeAudio가 false 반환
class LibavEncoder {
public:
    LibavEncoder();
    ~LibavEncoder();

    // 초기화 및 종료
    bool Start(const LibavEncoderConfig& config);
    void Stop();
    bool IsRunning() const { return is_running_; }

    // 프레임/오디오 인코딩
    // bgra_data: 1920x1080x4 바이트 (BGRA 포맷)
    // float32_data: 오디오 샘플 (Interleaved Float32, L/R/L/R...)
    // capture_qpc: QueryPerformanceCounter 값 (A/V 동기화용)
    bool EncodeVideo(const uint8_t* bgra_data, size_t length, uint64_t capture_qpc);
    bool EncodeAudio(const uint8_t* float32_data, size_t length, uint64_t capture_qpc);

    // 에러 처리
    std::string GetLastError() const { return last_error_; }

private:
    // === 초기화 헬퍼 ===
    bool InitializeFormat();
    bool InitializeVideoCodec();
    bool InitializeAudioCodec();
    bool WriteHeader();

    // === 인코딩 헬퍼 ===
    bool SendVideoFrame(AVFrame* frame);
    bool SendAudioFrame(AVFrame* frame);
    bool ReceiveAndWritePackets(AVCodecContext* codec_ctx, int stream_index);

    // === 변환 헬퍼 ===
    bool ConvertBGRAToYUV420(const uint8_t* bgra, AVFrame* yuv_frame);

    // === 종료 헬퍼 ===
    void FlushEncoder(AVCodecContext* codec_ctx, int stream_index);
    void WriteTrailer();
    void Cleanup();

    // === 유틸리티 ===
    void SetLastError(const std::string& message);
    std::string WideToUTF8(const std::wstring& wide_str);

    // === 설정 ===
    LibavEncoderConfig config_{};

    // === AVFormat ===
    AVFormatContext* format_ctx_ = nullptr;

    // === Video ===
    AVCodecContext* video_codec_ctx_ = nullptr;
    AVStream* video_stream_ = nullptr;
    AVFrame* video_frame_ = nullptr;
    SwsContext* sws_ctx_ = nullptr;
    int64_t last_video_pts_ = -1;  // 단조 증가 보장용 (이전 PTS)

    // === Audio ===
    AVCodecContext* audio_codec_ctx_ = nullptr;
    AVStream* audio_stream_ = nullptr;
    AVFrame* audio_frame_ = nullptr;
    SwrContext* swr_ctx_ = nullptr;
    int64_t last_audio_pts_ = -1;  // 단조 증가 보장용 (이전 PTS)
    std::vector<float> audio_buffer_;  // 오디오 샘플 버퍼 (Interleaved Float32)
    uint64_t first_audio_qpc_ = 0;     // 첫 오디오 샘플의 QPC (누적 PTS 계산용)
    int64_t audio_samples_written_ = 0; // 누적 작성 샘플 수

    // === QPC 타임스탬프 (A/V 동기화) ===
    uint64_t recording_start_qpc_ = 0;  // 녹화 시작 시점의 QPC
    uint64_t qpc_frequency_ = 0;        // QPC 주파수 (초당 틱 수)

    // === 상태 ===
    bool is_running_ = false;
    std::string last_error_;
};

#endif  // SAT_LEC_REC_LIBAV_ENCODER_H_
