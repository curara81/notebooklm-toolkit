#!/bin/bash
# ============================================================
# Apple Watch Meeting Recorder - 빌드 셋업
# 맥미니(Xcode 설치됨)에서 한 번 실행하면:
#   1) XcodeGen 설치 확인 (없으면 Homebrew로 설치)
#   2) .xcodeproj 생성
#   3) Xcode 로 열기
#
# 사용법:  cd apple-watch-app && ./build-setup.sh
# ============================================================

set -euo pipefail
cd "$(dirname "$0")"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; RED='\033[0;31m'; NC='\033[0m'

# 0) Xcode 확인
if ! xcode-select -p >/dev/null 2>&1; then
    echo -e "${RED}❌ Xcode(또는 Command Line Tools)가 없습니다. App Store에서 Xcode를 먼저 설치하세요.${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Xcode: $(xcode-select -p)${NC}"

# 1) XcodeGen 확인/설치
if ! command -v xcodegen >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  XcodeGen이 없습니다. 설치를 시도합니다...${NC}"
    if command -v brew >/dev/null 2>&1; then
        brew install xcodegen
    else
        echo -e "${RED}❌ Homebrew가 없습니다. 먼저 https://brew.sh 에서 설치 후 다시 실행하세요.${NC}"
        echo -e "${YELLOW}   설치 명령: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"${NC}"
        exit 1
    fi
fi
echo -e "${GREEN}✅ XcodeGen: $(xcodegen --version)${NC}"

# 2) 프로젝트 생성
echo -e "${BLUE}🛠  .xcodeproj 생성 중...${NC}"
xcodegen generate
echo -e "${GREEN}✅ MeetingRecorder.xcodeproj 생성 완료${NC}"

# 3) Xcode 로 열기
echo -e "${BLUE}📂 Xcode 로 여는 중...${NC}"
open MeetingRecorder.xcodeproj

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  다음 단계 (Xcode 에서):"
echo -e "  1. 좌측 프로젝트 > ${GREEN}MeetingRecorder${NC} 타깃 > Signing & Capabilities"
echo -e "     → ${GREEN}Team${NC} 에 본인 Apple ID 선택 (자동 서명)"
echo -e "  2. ${GREEN}MeetingRecorderWatch${NC} 타깃도 동일하게 Team 선택"
echo -e "  3. 상단에서 연결한 ${GREEN}아이폰${NC} 선택 후 ▶︎ (Cmd+R) 실행"
echo -e "  4. 앱 첫 실행 > ⚙️ 설정 > OpenAI / Anthropic API 키 입력"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
