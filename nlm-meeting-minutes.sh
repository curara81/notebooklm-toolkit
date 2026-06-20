#!/bin/bash
# ============================================================
# NotebookLM Meeting Minutes Generator
# 회의 녹음(오디오) → 받아쓰기(STT) → AI 회의록 자동 생성
#
#   1) 오디오 파일을 16kHz mono mp3로 변환하고 길면 분할 (ffmpeg)
#   2) OpenAI Whisper API로 한국어 받아쓰기 (정확도 우선, 클라우드)
#   3) Claude API로 회의록 자동 정리 (안건/결정사항/액션아이템)
#   4) (선택) 결과를 NotebookLM 노트북에 소스로 추가
#
# 사용법:
#   nlm-meeting-minutes.sh <audio_file> [옵션]
#
# 옵션:
#   --title <제목>        회의 제목 (기본: 파일명)
#   --lang <code>         받아쓰기 언어 (기본: ko)
#   --output <path>       회의록 markdown 출력 경로 (기본: <파일명>.minutes.md)
#   --transcript <path>   받아쓰기 원문 저장 경로 (기본: 저장 안 함)
#   --model <id>          Claude 모델 (기본: claude-sonnet-4-6)
#   --attendees "이름,.." 참석자 명단 (요약 품질 향상)
#   --notebook <id>       완성된 회의록을 NotebookLM 노트북에 추가
#   --keep-temp           중간 오디오 청크 파일 유지 (디버깅)
#
# 환경변수:
#   OPENAI_API_KEY        Whisper 받아쓰기에 필요 (필수)
#   ANTHROPIC_API_KEY     Claude 회의록 요약에 필요 (필수)
# ============================================================

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

usage() {
    echo "사용법:"
    echo "  $0 <audio_file> [옵션]"
    echo ""
    echo "옵션:"
    echo "  --title <제목>        회의 제목 (기본: 파일명)"
    echo "  --lang <code>         받아쓰기 언어 (기본: ko)"
    echo "  --output <path>       회의록 markdown 출력 경로"
    echo "  --transcript <path>   받아쓰기 원문 저장 경로"
    echo "  --model <id>          Claude 모델 (기본: claude-sonnet-4-6)"
    echo "  --attendees \"이름,..\" 참석자 명단"
    echo "  --notebook <id>       완성된 회의록을 NotebookLM에 추가"
    echo "  --keep-temp           중간 오디오 청크 파일 유지"
    echo ""
    echo "환경변수: OPENAI_API_KEY, ANTHROPIC_API_KEY (둘 다 필수)"
    exit 1
}

[[ $# -lt 1 ]] && usage

# ---- 인자 파싱 ----
AUDIO=""
TITLE=""
LANG="ko"
OUTPUT=""
TRANSCRIPT_OUT=""
MODEL="claude-sonnet-4-6"
ATTENDEES=""
NOTEBOOK=""
KEEP_TEMP=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --title) TITLE="$2"; shift 2 ;;
        --lang) LANG="$2"; shift 2 ;;
        --output) OUTPUT="$2"; shift 2 ;;
        --transcript) TRANSCRIPT_OUT="$2"; shift 2 ;;
        --model) MODEL="$2"; shift 2 ;;
        --attendees) ATTENDEES="$2"; shift 2 ;;
        --notebook) NOTEBOOK="$2"; shift 2 ;;
        --keep-temp) KEEP_TEMP=true; shift ;;
        -h|--help) usage ;;
        *)
            if [[ -z "$AUDIO" ]]; then AUDIO="$1"; fi
            shift ;;
    esac
done

# ---- 사전 점검 ----
if [[ -z "$AUDIO" ]]; then
    echo -e "${RED}❌ 오디오 파일을 지정하세요.${NC}"; usage
fi
if [[ ! -f "$AUDIO" ]]; then
    echo -e "${RED}❌ 파일을 찾을 수 없습니다: $AUDIO${NC}"; exit 1
fi
if [[ -z "${OPENAI_API_KEY:-}" ]]; then
    echo -e "${RED}❌ OPENAI_API_KEY 환경변수가 필요합니다 (Whisper 받아쓰기).${NC}"; exit 1
fi
if [[ -z "${ANTHROPIC_API_KEY:-}" ]]; then
    echo -e "${RED}❌ ANTHROPIC_API_KEY 환경변수가 필요합니다 (Claude 요약).${NC}"; exit 1
fi
for bin in ffmpeg curl python3; do
    if ! command -v "$bin" >/dev/null 2>&1; then
        echo -e "${RED}❌ '$bin' 이 설치되어 있어야 합니다.${NC}"
        echo -e "${YELLOW}   macOS: brew install ffmpeg${NC}"
        exit 1
    fi
done

# 기본값 채우기
BASENAME=$(basename "$AUDIO")
STEM="${BASENAME%.*}"
[[ -z "$TITLE" ]] && TITLE="$STEM"
[[ -z "$OUTPUT" ]] && OUTPUT="${STEM}.minutes.md"
MEETING_DATE=$(date '+%Y-%m-%d %H:%M')

TMPDIR=$(mktemp -d)
cleanup() {
    if [[ "$KEEP_TEMP" == true ]]; then
        echo -e "${YELLOW}🧹 임시 파일 유지: $TMPDIR${NC}"
    else
        rm -rf "$TMPDIR"
    fi
}
trap cleanup EXIT

# ============================================================
# 1) 오디오 정규화 + 분할
#    16kHz mono mp3(64k)로 변환 → 분당 ~0.5MB, Whisper 25MB 한도 안전
#    15분(900초) 단위로 분할
# ============================================================
echo -e "${BLUE}🎙  오디오 변환 중: ${BASENAME}${NC}"
ffmpeg -hide_banner -loglevel error -y -i "$AUDIO" \
    -ar 16000 -ac 1 -c:a libmp3lame -b:a 64k \
    -f segment -segment_time 900 \
    "$TMPDIR/chunk_%03d.mp3"

CHUNKS=$(find "$TMPDIR" -name 'chunk_*.mp3' | sort)
CHUNK_COUNT=$(echo "$CHUNKS" | grep -c . || true)
if [[ "$CHUNK_COUNT" -eq 0 ]]; then
    echo -e "${RED}❌ 오디오 변환 실패. 파일 형식을 확인하세요.${NC}"; exit 1
fi
echo -e "${GREEN}✅ ${CHUNK_COUNT}개 구간으로 분할${NC}"

# ============================================================
# 2) Whisper 받아쓰기 (구간별 → 합치기)
# ============================================================
RAW_TRANSCRIPT="$TMPDIR/transcript.txt"
: > "$RAW_TRANSCRIPT"

IDX=0
while IFS= read -r chunk; do
    [[ -z "$chunk" ]] && continue
    IDX=$((IDX + 1))
    echo -e "${BLUE}📝 받아쓰기 ${IDX}/${CHUNK_COUNT} ...${NC}"

    HTTP_CODE=$(curl -s -w "%{http_code}" -o "$TMPDIR/stt_resp.txt" \
        https://api.openai.com/v1/audio/transcriptions \
        -H "Authorization: Bearer ${OPENAI_API_KEY}" \
        -F "file=@${chunk}" \
        -F "model=whisper-1" \
        -F "language=${LANG}" \
        -F "response_format=text")

    if [[ "$HTTP_CODE" != "200" ]]; then
        echo -e "${RED}❌ Whisper API 오류 (HTTP $HTTP_CODE):${NC}"
        cat "$TMPDIR/stt_resp.txt"
        exit 1
    fi

    cat "$TMPDIR/stt_resp.txt" >> "$RAW_TRANSCRIPT"
    echo "" >> "$RAW_TRANSCRIPT"
done <<< "$CHUNKS"

WORD_COUNT=$(wc -w < "$RAW_TRANSCRIPT" | tr -d ' ')
echo -e "${GREEN}✅ 받아쓰기 완료 (${WORD_COUNT} 단어)${NC}"

if [[ -n "$TRANSCRIPT_OUT" ]]; then
    cp "$RAW_TRANSCRIPT" "$TRANSCRIPT_OUT"
    echo -e "${GREEN}✅ 받아쓰기 원문 저장: $TRANSCRIPT_OUT${NC}"
fi

# ============================================================
# 3) Claude 회의록 요약
# ============================================================
echo -e "${BLUE}🤖 회의록 정리 중 (Claude: ${MODEL}) ...${NC}"

SYSTEM_PROMPT="당신은 전문 회의록 작성자입니다. 음성 받아쓰기 원문(오타·중복·구어체 포함)을 입력받아, 깔끔하고 구조화된 한국어 회의록을 Markdown으로 작성합니다.

반드시 아래 형식을 지키세요:

# {회의 제목}

- **일시:** {일시}
- **참석자:** {참석자, 모르면 '미기재'}

## 📌 핵심 요약
3~5문장으로 회의 전체를 요약.

## 🗣 주요 논의 내용
안건별로 소제목(###)을 만들고, 각 안건의 논의 내용을 불릿으로 정리.

## ✅ 결정 사항
확정된 결정만 번호 매겨 정리. 없으면 '결정된 사항 없음'.

## 📋 액션 아이템
| 담당자 | 할 일 | 기한 |
|---|---|---|
담당자·기한이 불명확하면 '미정'으로 표기. 없으면 표 대신 '없음'.

## ❓ 미해결/후속 논의 필요
다음 회의로 넘어간 사항. 없으면 생략 가능.

규칙:
- 받아쓰기 오류로 보이는 단어는 문맥상 자연스럽게 보정.
- 원문에 없는 내용을 지어내지 말 것.
- 군더더기 없이 간결하게."

# JSON 페이로드를 python3로 안전하게 생성 (받아쓰기 본문 escape)
PAYLOAD="$TMPDIR/payload.json"
TITLE="$TITLE" MEETING_DATE="$MEETING_DATE" ATTENDEES="$ATTENDEES" \
MODEL="$MODEL" SYSTEM_PROMPT="$SYSTEM_PROMPT" RAW_TRANSCRIPT="$RAW_TRANSCRIPT" \
python3 <<'PY' > "$PAYLOAD"
import os, json
title = os.environ["TITLE"]
date = os.environ["MEETING_DATE"]
attendees = os.environ["ATTENDEES"].strip() or "미기재"
model = os.environ["MODEL"]
system = os.environ["SYSTEM_PROMPT"]
with open(os.environ["RAW_TRANSCRIPT"], encoding="utf-8") as f:
    transcript = f.read()

user_msg = (
    f"회의 제목: {title}\n"
    f"일시: {date}\n"
    f"참석자: {attendees}\n\n"
    f"아래는 회의 녹음 받아쓰기 원문입니다. 이를 회의록으로 정리해 주세요.\n\n"
    f"=== 받아쓰기 원문 시작 ===\n{transcript}\n=== 받아쓰기 원문 끝 ==="
)

payload = {
    "model": model,
    "max_tokens": 4096,
    "system": system,
    "messages": [{"role": "user", "content": user_msg}],
}
print(json.dumps(payload, ensure_ascii=False))
PY

HTTP_CODE=$(curl -s -w "%{http_code}" -o "$TMPDIR/claude_resp.json" \
    https://api.anthropic.com/v1/messages \
    -H "x-api-key: ${ANTHROPIC_API_KEY}" \
    -H "anthropic-version: 2023-06-01" \
    -H "content-type: application/json" \
    --data-binary "@${PAYLOAD}")

if [[ "$HTTP_CODE" != "200" ]]; then
    echo -e "${RED}❌ Claude API 오류 (HTTP $HTTP_CODE):${NC}"
    cat "$TMPDIR/claude_resp.json"
    exit 1
fi

# 응답에서 본문 추출
MINUTES_BODY=$(CLAUDE_RESP="$TMPDIR/claude_resp.json" python3 <<'PY'
import json, os, sys
with open(os.environ["CLAUDE_RESP"], encoding="utf-8") as f:
    data = json.load(f)
parts = [b.get("text", "") for b in data.get("content", []) if b.get("type") == "text"]
sys.stdout.write("\n".join(parts).strip())
PY
)

if [[ -z "$MINUTES_BODY" ]]; then
    echo -e "${RED}❌ Claude 응답에서 회의록을 추출하지 못했습니다.${NC}"
    cat "$TMPDIR/claude_resp.json"
    exit 1
fi

# ============================================================
# 4) 저장
# ============================================================
{
    echo "$MINUTES_BODY"
    echo ""
    echo "---"
    echo ""
    echo "_원본 오디오: ${BASENAME} · 자동 생성: $(date '+%Y-%m-%d %H:%M') · STT: Whisper · 요약: ${MODEL}_"
} > "$OUTPUT"

echo -e "${GREEN}✅ 회의록 저장: $OUTPUT${NC}"

# ============================================================
# 5) (선택) NotebookLM에 추가
# ============================================================
if [[ -n "$NOTEBOOK" ]]; then
    if command -v notebooklm >/dev/null 2>&1; then
        echo -e "${BLUE}📓 NotebookLM 노트북에 추가 중 ...${NC}"
        if notebooklm source add "$NOTEBOOK" --file "$OUTPUT" 2>/dev/null \
           || notebooklm add-source "$NOTEBOOK" "$OUTPUT" 2>/dev/null; then
            echo -e "${GREEN}✅ NotebookLM 추가 완료${NC}"
        else
            echo -e "${YELLOW}⚠️  자동 추가 실패. 수동으로 업로드하세요: $OUTPUT${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  notebooklm CLI 없음. 수동으로 업로드하세요: $OUTPUT${NC}"
    fi
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  회의록:   ${GREEN}${OUTPUT}${NC}"
[[ -n "$TRANSCRIPT_OUT" ]] && echo -e "  받아쓰기: ${GREEN}${TRANSCRIPT_OUT}${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
