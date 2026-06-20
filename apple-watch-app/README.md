# Apple Watch Meeting Recorder

애플워치 버튼으로 회의 녹음을 시작/정지하면, **아이폰이 녹음**하고 회의가 끝나는 즉시
**받아쓰기(OpenAI Whisper) → 회의록 자동 정리(Claude)** 까지 끝내주는 iOS + watchOS 앱입니다.

```
[Apple Watch]  녹음 버튼 ●
      │  WatchConnectivity 로 start/stop 전송
      ▼
[iPhone 앱]  AVAudioRecorder 로 녹음 (16kHz mono, 작은 m4a)
      │  정지하면 자동 실행
      ▼
[OpenAI Whisper API]  한국어 받아쓰기
      ▼
[Claude API]  회의록 정리 (핵심요약·결정사항·액션아이템)
      ▼
[iPhone 앱]  회의록 목록에 저장 · Markdown 공유
```

워치는 **녹음 시작/정지 리모컨 + 상태 표시** 역할을 하고, 실제 녹음·AI 처리는 아이폰이 담당합니다
(워치 단독 녹음보다 음질·배터리·안정성이 좋습니다).

## 구성

| 파일 | 역할 |
|---|---|
| `Shared/WatchMessage.swift` | 워치↔폰 메시지 규약 |
| `Shared/MeetingRecord.swift` | 회의록 데이터 모델 |
| `Shared/APIConfig.swift` | API 키·옵션 보관 |
| `iOS/AudioRecorder.swift` | 아이폰 녹음 (AVAudioRecorder) |
| `iOS/TranscriptionService.swift` | Whisper 받아쓰기 |
| `iOS/SummaryService.swift` | Claude 회의록 요약 |
| `iOS/RecorderViewModel.swift` | 녹음→받아쓰기→요약 전체 흐름 조율 |
| `iOS/PhoneConnectivity.swift` | 폰 쪽 WatchConnectivity |
| `iOS/ContentView / SettingsView / MeetingDetailView` | 아이폰 화면 |
| `Watch/WatchConnectivityProvider.swift` | 워치 쪽 WatchConnectivity |
| `Watch/WatchContentView.swift` | 워치 녹음 버튼 화면 |

## 빌드 방법 (맥에서)

손으로 관리하기 까다로운 `.xcodeproj` 대신 [XcodeGen](https://github.com/yonaskolb/XcodeGen)으로 생성합니다.

```bash
brew install xcodegen
cd apple-watch-app
xcodegen generate
open MeetingRecorder.xcodeproj
```

Xcode에서:
1. `project.yml` 의 `com.example.*` 번들 ID를 본인 것으로 변경 (또는 Xcode Signing 탭에서 팀 선택)
2. **MeetingRecorder**(iOS) 타깃과 **MeetingRecorderWatch** 타깃 각각 Signing & Capabilities에서 본인 팀 지정
3. 아이폰 실기기에 빌드 → 실행 → 워치 앱은 페어링된 워치에 자동 설치

> 실기기 설치에는 **Apple Developer Program(연 $99)** 또는 무료 개인 팀(7일 제한)이 필요합니다.

## 사용 방법

1. 아이폰 앱 첫 실행 → 우상단 ⚙️ **설정**에서 OpenAI / Anthropic **API 키 입력**
2. (선택) 회의 제목 입력
3. **워치 또는 아이폰의 ● 버튼**으로 녹음 시작 → 회의 진행 → 같은 버튼으로 정지
4. 자동으로 받아쓰기 + 회의록 생성 → 아이폰 목록에 저장, **공유** 버튼으로 내보내기

## 알아둘 점 / 한계 (MVP)

- **녹음 길이:** 한 파일을 통째로 Whisper에 보내므로 25MB(≈25~30분) 한도가 있습니다.
  더 긴 회의는 저장소의 **`nlm-meeting-minutes.sh`**(맥용, 자동 15분 분할)을 쓰면 길이 제한이 없습니다.
- **API 키 보안:** MVP는 키를 기기(UserDefaults)에 저장합니다. 실배포 시 Keychain 또는
  본인 서버 프록시로 키를 클라이언트에서 분리하는 것을 권장합니다.
- **백그라운드 녹음:** `UIBackgroundModes: audio` 를 켜 두었지만, 장시간 안정 녹음을 위해서는
  화면을 켜 두거나 아이폰을 가까이 두는 것이 안전합니다.
- **비용:** Whisper(분당 약 $0.006) + Claude 요약(토큰당 과금)이 호출당 발생합니다.

## 다음 개선 아이디어

- 긴 회의 자동 분할(앱 내 ffmpeg/AVAssetExportSession) 처리
- 화자 분리(speaker diarization)
- 회의록 NotebookLM/Notion 자동 업로드
- 워치 단독 녹음 모드(아이폰 없을 때 폴백)
