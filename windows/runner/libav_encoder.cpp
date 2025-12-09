// libavcodec 기반 Video+Audio 인코더 구현

#include "libav_encoder.h"

#include <cstdio>
#include <vector>

// ==============================================================================
// 생성자 / 소멸자
// ==============================================================================

LibavEncoder::LibavEncoder() {
    // FFmpeg 라이브러리 초기화는 불필요 (FFmpeg 4.x 이후)
}

LibavEncoder::~LibavEncoder() {
    if (is_running_) {
        Stop();
    }
}

// ==============================================================================
// 유틸리티 함수
// ==============================================================================

void LibavEncoder::SetLastError(const std::string& message) {
    last_error_ = message;
    printf("[LibavEncoder] ERROR: %s\n", message.c_str());
    fflush(stdout);
}

std::string LibavEncoder::WideToUTF8(const std::wstring& wide_str) {
    if (wide_str.empty()) return std::string();

    int size_needed = WideCharToMultiByte(CP_UTF8, 0, wide_str.c_str(),
                                          (int)wide_str.size(), NULL, 0, NULL, NULL);
    std::string utf8_str(size_needed, 0);
    WideCharToMultiByte(CP_UTF8, 0, wide_str.c_str(), (int)wide_str.size(),
                       &utf8_str[0], size_needed, NULL, NULL);
    return utf8_str;
}

// ==============================================================================
// 초기화
// ==============================================================================

bool LibavEncoder::Start(const LibavEncoderConfig& config) {
    if (is_running_) {
        SetLastError("이미 실행 중입니다");
        return false;
    }

    config_ = config;

    printf("[LibavEncoder] 초기화 시작...\n");
    fflush(stdout);

    // QPC 주파수 및 시작 시점 초기화 (A/V 동기화의 핵심)
    // ⚠️ 중요: 오디오/비디오 모두 이 시점을 기준으로 PTS를 계산함
    LARGE_INTEGER freq, start;
    QueryPerformanceFrequency(&freq);
    QueryPerformanceCounter(&start);
    qpc_frequency_ = freq.QuadPart;
    recording_start_qpc_ = start.QuadPart;

    printf("[LibavEncoder] QPC 초기화: freq=%llu, start=%llu\n",
           qpc_frequency_, recording_start_qpc_);
    fflush(stdout);

    // 1. AVFormatContext 생성
    if (!InitializeFormat()) {
        Cleanup();
        return false;
    }

    // 2. Video 스트림 생성
    if (!InitializeVideoCodec()) {
        Cleanup();
        return false;
    }

    // 3. Audio 스트림 생성
    if (!InitializeAudioCodec()) {
        Cleanup();
        return false;
    }

    // 4. MP4 파일 열기 및 헤더 작성
    if (!WriteHeader()) {
        Cleanup();
        return false;
    }

    is_running_ = true;
    printf("[LibavEncoder] ✅ 초기화 완료\n");
    fflush(stdout);
    return true;
}

bool LibavEncoder::InitializeFormat() {
    std::string utf8_path = WideToUTF8(config_.output_path);

    // MP4 muxer용 AVFormatContext 할당
    int ret = avformat_alloc_output_context2(&format_ctx_, nullptr, "mp4", utf8_path.c_str());
    if (ret < 0) {
        char err_buf[128];
        av_strerror(ret, err_buf, sizeof(err_buf));
        SetLastError(std::string("avformat_alloc_output_context2 실패: ") + err_buf);
        return false;
    }

    // Fragmented MP4 옵션 설정 (크래시 복구용)
    if (config_.enable_fragmented_mp4) {
        av_dict_set(&format_ctx_->metadata, "movflags",
                   "frag_keyframe+empty_moov+default_base_moof", 0);
    }

    printf("[LibavEncoder] ✅ AVFormatContext 생성 완료\n");
    fflush(stdout);
    return true;
}

bool LibavEncoder::InitializeVideoCodec() {
    // 1. H.264 인코더 찾기
    const AVCodec* codec = avcodec_find_encoder(AV_CODEC_ID_H264);
    if (!codec) {
        SetLastError("H.264 인코더를 찾을 수 없습니다");
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
    video_codec_ctx_->time_base = AVRational{1, config_.video_fps};
    video_codec_ctx_->framerate = AVRational{config_.video_fps, 1};
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
        char err_buf[128];
        av_strerror(ret, err_buf, sizeof(err_buf));
        SetLastError(std::string("Video 인코더 열기 실패: ") + err_buf);
        return false;
    }

    // 6. 스트림에 파라미터 복사
    avcodec_parameters_from_context(video_stream_->codecpar, video_codec_ctx_);
    video_stream_->time_base = video_codec_ctx_->time_base;

    // 7. AVFrame 할당
    video_frame_ = av_frame_alloc();
    if (!video_frame_) {
        SetLastError("Video AVFrame 할당 실패");
        return false;
    }
    video_frame_->format = AV_PIX_FMT_YUV420P;
    video_frame_->width = config_.video_width;
    video_frame_->height = config_.video_height;
    ret = av_frame_get_buffer(video_frame_, 0);
    if (ret < 0) {
        char err_buf[128];
        av_strerror(ret, err_buf, sizeof(err_buf));
        SetLastError(std::string("Video Frame 버퍼 할당 실패: ") + err_buf);
        return false;
    }

    // 8. SwsContext 생성 (BGRA → YUV420P 변환용)
    sws_ctx_ = sws_getContext(
        config_.video_width, config_.video_height, AV_PIX_FMT_BGRA,
        config_.video_width, config_.video_height, AV_PIX_FMT_YUV420P,
        SWS_BILINEAR, nullptr, nullptr, nullptr
    );
    if (!sws_ctx_) {
        SetLastError("SwsContext 생성 실패");
        return false;
    }

    printf("[LibavEncoder] ✅ Video 인코더 초기화 완료 (%dx%d@%dfps, CRF=%d)\n",
           config_.video_width, config_.video_height, config_.video_fps, config_.h264_crf);
    fflush(stdout);
    return true;
}

bool LibavEncoder::InitializeAudioCodec() {
    // 1. AAC 인코더 찾기
    const AVCodec* codec = avcodec_find_encoder(AV_CODEC_ID_AAC);
    if (!codec) {
        SetLastError("AAC 인코더를 찾을 수 없습니다");
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

    // FFmpeg 6.1+ API: AVChannelLayout 사용
    audio_codec_ctx_->ch_layout = AV_CHANNEL_LAYOUT_STEREO;

    audio_codec_ctx_->sample_fmt = AV_SAMPLE_FMT_FLTP;  // Planar float
    audio_codec_ctx_->bit_rate = config_.aac_bitrate;
    audio_codec_ctx_->time_base = AVRational{1, config_.audio_sample_rate};

    // 5. 인코더 열기
    int ret = avcodec_open2(audio_codec_ctx_, codec, nullptr);
    if (ret < 0) {
        char err_buf[128];
        av_strerror(ret, err_buf, sizeof(err_buf));
        SetLastError(std::string("Audio 인코더 열기 실패: ") + err_buf);
        return false;
    }

    // 6. 스트림에 파라미터 복사
    avcodec_parameters_from_context(audio_stream_->codecpar, audio_codec_ctx_);
    audio_stream_->time_base = audio_codec_ctx_->time_base;

    // 7. AVFrame 할당 (AAC는 보통 1024 샘플/프레임)
    audio_frame_ = av_frame_alloc();
    if (!audio_frame_) {
        SetLastError("Audio AVFrame 할당 실패");
        return false;
    }
    audio_frame_->format = AV_SAMPLE_FMT_FLTP;
    audio_frame_->ch_layout = AV_CHANNEL_LAYOUT_STEREO;
    audio_frame_->sample_rate = config_.audio_sample_rate;
    audio_frame_->nb_samples = audio_codec_ctx_->frame_size;  // 보통 1024

    ret = av_frame_get_buffer(audio_frame_, 0);
    if (ret < 0) {
        char err_buf[128];
        av_strerror(ret, err_buf, sizeof(err_buf));
        SetLastError(std::string("Audio Frame 버퍼 할당 실패: ") + err_buf);
        return false;
    }

    // 8. SwrContext 생성 (Interleaved Float → Planar Float 변환용)
    ret = swr_alloc_set_opts2(
        &swr_ctx_,
        &audio_codec_ctx_->ch_layout,
        audio_codec_ctx_->sample_fmt,
        audio_codec_ctx_->sample_rate,
        &audio_codec_ctx_->ch_layout,
        AV_SAMPLE_FMT_FLT,  // 입력은 Interleaved float
        config_.audio_sample_rate,
        0, nullptr
    );
    if (ret < 0) {
        char err_buf[128];
        av_strerror(ret, err_buf, sizeof(err_buf));
        SetLastError(std::string("SwrContext 할당 실패: ") + err_buf);
        return false;
    }

    ret = swr_init(swr_ctx_);
    if (ret < 0) {
        char err_buf[128];
        av_strerror(ret, err_buf, sizeof(err_buf));
        SetLastError(std::string("SwrContext 초기화 실패: ") + err_buf);
        return false;
    }

    printf("[LibavEncoder] ✅ Audio 인코더 초기화 완료 (%dHz, %dkbps, frame_size=%d)\n",
           config_.audio_sample_rate, config_.aac_bitrate / 1000, audio_codec_ctx_->frame_size);
    fflush(stdout);
    return true;
}

bool LibavEncoder::WriteHeader() {
    std::string utf8_path = WideToUTF8(config_.output_path);

    // 1. 파일 열기
    int ret = avio_open(&format_ctx_->pb, utf8_path.c_str(), AVIO_FLAG_WRITE);
    if (ret < 0) {
        char err_buf[128];
        av_strerror(ret, err_buf, sizeof(err_buf));
        SetLastError(std::string("출력 파일 열기 실패: ") + err_buf);
        return false;
    }

    // 2. MP4 헤더 작성
    ret = avformat_write_header(format_ctx_, nullptr);
    if (ret < 0) {
        char err_buf[128];
        av_strerror(ret, err_buf, sizeof(err_buf));
        SetLastError(std::string("avformat_write_header 실패: ") + err_buf);
        return false;
    }

    printf("[LibavEncoder] ✅ MP4 헤더 작성 완료\n");
    fflush(stdout);
    return true;
}

// ==============================================================================
// 인코딩
// ==============================================================================

bool LibavEncoder::EncodeVideo(const uint8_t* bgra_data, size_t length, uint64_t capture_qpc) {
    if (!is_running_) {
        SetLastError("인코더가 실행 중이 아닙니다");
        return false;
    }

    // 예상 크기 검증
    size_t expected_size = config_.video_width * config_.video_height * 4;
    if (length != expected_size) {
        SetLastError("Video 프레임 크기 불일치");
        return false;
    }

    // 1. BGRA → YUV420P 변환
    if (!ConvertBGRAToYUV420(bgra_data, video_frame_)) {
        return false;
    }

    // 2. QPC 기반 PTS 계산 (A/V 동기화 핵심)
    // ⚠️ 중요: 카운터 기반(next_video_pts_++)이 아닌 실제 경과 시간 사용
    // 이렇게 해야 정적 화면에서도 오디오와 동기화됨
    int64_t pts = 0;
    if (qpc_frequency_ > 0 && capture_qpc >= recording_start_qpc_) {
        // 경과 시간(초) = (현재 QPC - 시작 QPC) / QPC 주파수
        double elapsed_seconds = static_cast<double>(capture_qpc - recording_start_qpc_)
                                / static_cast<double>(qpc_frequency_);

        // PTS = 경과 시간 × time_base.den (fps)
        // time_base = 1/fps 이므로 time_base.den = fps
        pts = static_cast<int64_t>(elapsed_seconds * video_codec_ctx_->time_base.den);

        // 단조 증가 보장: PTS가 이전보다 작거나 같으면 직전+1 사용
        if (pts <= last_video_pts_) {
            pts = last_video_pts_ + 1;
        }
        last_video_pts_ = pts;
    } else {
        // QPC 미초기화 시 폴백 (이론상 발생 안함)
        pts = (last_video_pts_ < 0) ? 0 : last_video_pts_ + 1;
        last_video_pts_ = pts;
    }

    video_frame_->pts = pts;

    // 3. 인코더에 전송
    return SendVideoFrame(video_frame_);
}

bool LibavEncoder::ConvertBGRAToYUV420(const uint8_t* bgra, AVFrame* yuv_frame) {
    const uint8_t* src_data[1] = { bgra };
    int src_linesize[1] = { config_.video_width * 4 };  // BGRA = 4 bytes/pixel

    int ret = sws_scale(
        sws_ctx_,
        src_data, src_linesize, 0, config_.video_height,
        yuv_frame->data, yuv_frame->linesize
    );

    if (ret != config_.video_height) {
        SetLastError("sws_scale 실패");
        return false;
    }

    return true;
}

bool LibavEncoder::SendVideoFrame(AVFrame* frame) {
    // 1. 프레임을 인코더에 전송
    int ret = avcodec_send_frame(video_codec_ctx_, frame);
    if (ret < 0) {
        char err_buf[128];
        av_strerror(ret, err_buf, sizeof(err_buf));
        SetLastError(std::string("avcodec_send_frame(video) 실패: ") + err_buf);
        return false;
    }

    // 2. 패킷 수신 및 muxing
    return ReceiveAndWritePackets(video_codec_ctx_, video_stream_->index);
}

bool LibavEncoder::EncodeAudio(const uint8_t* float32_data, size_t length, uint64_t capture_qpc) {
    if (!is_running_) {
        SetLastError("인코더가 실행 중이 아닙니다");
        return false;
    }

    // 1. 입력 데이터를 버퍼에 추가
    const float* samples = reinterpret_cast<const float*>(float32_data);
    size_t sample_count = length / sizeof(float);  // Interleaved 샘플 수 (L+R+L+R...)
    audio_buffer_.insert(audio_buffer_.end(), samples, samples + sample_count);

    // 2. 버퍼에서 frame_size 프레임을 추출하여 인코딩
    int frame_size = audio_codec_ctx_->frame_size;  // 1024
    int channels = config_.audio_channels;          // 2
    size_t samples_per_frame = frame_size * channels;  // 2048 (Interleaved)

    while (audio_buffer_.size() >= samples_per_frame) {
        // 2.1. frame_size 프레임만큼 추출
        std::vector<float> frame_data(audio_buffer_.begin(),
                                      audio_buffer_.begin() + samples_per_frame);

        // 2.2. Interleaved Float32 → Planar Float 변환
        const uint8_t* src_data[1] = { reinterpret_cast<const uint8_t*>(frame_data.data()) };
        int ret = swr_convert(
            swr_ctx_,
            audio_frame_->data,
            audio_frame_->nb_samples,
            src_data,
            frame_size  // 주의: 채널 수가 아닌 프레임 수
        );

        if (ret < 0) {
            char err_buf[128];
            av_strerror(ret, err_buf, sizeof(err_buf));
            SetLastError(std::string("swr_convert 실패: ") + err_buf);
            return false;
        }

        // 2.3. 샘플 카운터 기반 PTS 계산
        // ⚠️ 수정: QPC 기반 계산에서 audio_samples_written_을 또 더해서 2배가 되는 버그 수정
        // 오디오는 연속적인 샘플 스트림이므로 단순히 누적 샘플 수를 PTS로 사용
        // time_base = 1/sample_rate 이므로 PTS = 샘플 수
        int64_t pts = audio_samples_written_;

        // 단조 증가 보장
        if (pts <= last_audio_pts_) {
            pts = last_audio_pts_ + 1;
        }
        last_audio_pts_ = pts;

        audio_frame_->pts = pts;
        audio_samples_written_ += frame_size;

        // 2.4. 인코더에 전송
        if (!SendAudioFrame(audio_frame_)) {
            return false;
        }

        // 2.5. 버퍼에서 제거
        audio_buffer_.erase(audio_buffer_.begin(),
                           audio_buffer_.begin() + samples_per_frame);
    }

    return true;
}

bool LibavEncoder::SendAudioFrame(AVFrame* frame) {
    // 1. 프레임을 인코더에 전송
    int ret = avcodec_send_frame(audio_codec_ctx_, frame);
    if (ret < 0) {
        char err_buf[128];
        av_strerror(ret, err_buf, sizeof(err_buf));
        SetLastError(std::string("avcodec_send_frame(audio) 실패: ") + err_buf);
        return false;
    }

    // 2. 패킷 수신 및 muxing
    return ReceiveAndWritePackets(audio_codec_ctx_, audio_stream_->index);
}

bool LibavEncoder::ReceiveAndWritePackets(AVCodecContext* codec_ctx, int stream_index) {
    AVPacket* pkt = av_packet_alloc();
    if (!pkt) {
        SetLastError("AVPacket 할당 실패");
        return false;
    }

    bool success = true;

    while (true) {
        // 1. 인코딩된 패킷 수신
        int ret = avcodec_receive_packet(codec_ctx, pkt);

        if (ret == AVERROR(EAGAIN) || ret == AVERROR_EOF) {
            // 더 이상 패킷 없음
            break;
        } else if (ret < 0) {
            char err_buf[128];
            av_strerror(ret, err_buf, sizeof(err_buf));
            SetLastError(std::string("avcodec_receive_packet 실패: ") + err_buf);
            success = false;
            break;
        }

        // 2. 타임스탬프 변환 (codec time_base → stream time_base)
        AVStream* stream = format_ctx_->streams[stream_index];
        av_packet_rescale_ts(pkt, codec_ctx->time_base, stream->time_base);
        pkt->stream_index = stream_index;

        // 3. Interleaved write (자동으로 DTS 순서 정렬)
        ret = av_interleaved_write_frame(format_ctx_, pkt);
        if (ret < 0) {
            char err_buf[128];
            av_strerror(ret, err_buf, sizeof(err_buf));
            SetLastError(std::string("av_interleaved_write_frame 실패: ") + err_buf);
            success = false;
            break;
        }

        av_packet_unref(pkt);
    }

    av_packet_free(&pkt);
    return success;
}

// ==============================================================================
// 종료
// ==============================================================================

void LibavEncoder::Stop() {
    if (!is_running_) return;

    printf("[LibavEncoder] 인코더 종료 중...\n");
    fflush(stdout);

    // 1. 남은 프레임 플러시
    if (video_codec_ctx_) {
        FlushEncoder(video_codec_ctx_, video_stream_->index);
    }

    if (audio_codec_ctx_) {
        FlushEncoder(audio_codec_ctx_, audio_stream_->index);
    }

    // 2. MP4 트레일러 작성
    WriteTrailer();

    // 3. 리소스 정리
    Cleanup();

    is_running_ = false;
    printf("[LibavEncoder] ✅ 인코더 종료 완료\n");
    fflush(stdout);
}

void LibavEncoder::FlushEncoder(AVCodecContext* codec_ctx, int stream_index) {
    // EOF 신호 전송
    avcodec_send_frame(codec_ctx, nullptr);

    // 남은 패킷 수신
    ReceiveAndWritePackets(codec_ctx, stream_index);
}

void LibavEncoder::WriteTrailer() {
    if (format_ctx_) {
        av_write_trailer(format_ctx_);
    }
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
    audio_buffer_.clear();  // 오디오 샘플 버퍼 정리

    // Format
    if (format_ctx_) {
        if (format_ctx_->pb) {
            avio_closep(&format_ctx_->pb);
        }
        avformat_free_context(format_ctx_);
        format_ctx_ = nullptr;
    }

    // 스트림 포인터는 format_ctx가 관리하므로 별도 해제 불필요
    video_stream_ = nullptr;
    audio_stream_ = nullptr;

    // PTS 및 QPC 상태 초기화
    last_video_pts_ = -1;
    last_audio_pts_ = -1;
    first_audio_qpc_ = 0;
    audio_samples_written_ = 0;
    recording_start_qpc_ = 0;
    qpc_frequency_ = 0;
}
