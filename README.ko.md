<p align="center">
  <img src="docs/images/limi-512.png" width="160" alt="Limi 아이콘: 사용량 막대 셋">
</p>

<h1 align="center">Limi</h1>

<h3 align="center">AI 구독 한도, 메뉴 막대 하나에.</h3>

<p align="center">
  Claude Code와 Codex 계정 여러 개의 5시간·주간 한도를 메뉴 막대에서 바로 봅니다.<br>
  한도에 걸리기 전에 계정을 바꾸세요. 계정 정보는 이 맥에만 둡니다.
</p>

<p align="center">
  <a href="https://github.com/kalti-lab/limi/releases/latest/download/Limi.zip"><img src="https://img.shields.io/badge/Download_for_Mac-Limi.zip-3b82f6?style=for-the-badge&logo=apple&logoColor=white&labelColor=0f1115" alt="맥용 Limi.zip 내려받기"></a>
</p>

<p align="center">
  <a href="https://kalti.co.kr/ko/limi/"><b>웹사이트</b></a> &nbsp;·&nbsp; <a href="https://kalti.co.kr/ko/"><b>KALTI</b></a> &nbsp;·&nbsp; <a href="README.md">English</a> | <b>한국어</b>
</p>

<p align="center">
  <a href="https://github.com/kalti-lab/limi/releases/latest"><img src="https://img.shields.io/github/v/release/kalti-lab/limi" alt="최신 릴리스"></a>
  <img src="https://img.shields.io/badge/macOS-14%2B-555?logo=apple" alt="macOS 14 이상">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="MIT 라이선스"></a>
</p>

<p align="center">
  <img src="docs/images/readme-hero-ko.jpg" width="840" alt="메뉴 막대의 Limi와 Claude 계정 창: 5시간·주간 한도와 초기화까지 남은 시간">
</p>

## IN ACTION<br>실제 화면

<table>
  <tr>
    <td align="center" valign="top" width="50%">
      <img src="docs/images/settings-accounts.png" width="400" alt="Limi 설정의 계정 탭: Claude 둘과 Codex 하나"><br>
      <b>계정 여러 개</b><br><sub>Claude Code와 Codex 계정을 함께 등록</sub>
    </td>
    <td align="center" valign="top" width="50%">
      <img src="docs/images/settings-general.png" width="400" alt="Limi 설정의 일반 탭: 새로 고침 간격, 언어, 로그인 시 열기"><br>
      <b>일반 설정</b><br><sub>새로 고침 간격, 언어, 로그인 시 열기</sub>
    </td>
  </tr>
  <tr>
    <td align="center" valign="top">
      <img src="docs/images/settings-menubar.png" width="340" alt="Limi 설정의 메뉴 막대 탭: 그룹, 모양, 사용량 줄"><br>
      <b>메뉴 막대 꾸미기</b><br><sub>그룹과 모양, 보여 줄 한도를 원하는 대로</sub>
    </td>
    <td align="center" valign="top">
      <img src="docs/images/readme-popover-claude2.png" width="320" alt="Limi 창: 두 번째 Claude 계정 탭"><br>
      <b>탭으로 계정 바꿔 보기</b><br><sub>한 그룹에 넣은 여러 계정</sub>
    </td>
  </tr>
</table>

## KEY CAPABILITIES<br>할 수 있는 일

<table>
  <tr>
    <td valign="top" width="50%">
      <img src="docs/images/cap-accounts.svg" width="52" height="52" alt=""><br>
      <b>계정 여러 개를 한눈에</b><br>
      Claude Code와 Codex 계정을 함께 넣고, 계정마다 5시간·주간 한도를 봅니다.
    </td>
    <td valign="top" width="50%">
      <img src="docs/images/cap-style.svg" width="52" height="52" alt=""><br>
      <b>원하는 모양으로</b><br>
      멀티 바, 링 게이지, 캡슐 채우기, 텍스트만 가운데서 고르고, 계정을 그룹으로 묶습니다. 90%를 넘으면 빨간색이 됩니다.
    </td>
  </tr>
  <tr>
    <td valign="top">
      <img src="docs/images/cap-private.svg" width="52" height="52" alt=""><br>
      <b>계정 정보는 이 맥에만</b><br>
      로그인 정보는 이 맥에만 두고, 칼티로는 아무것도 보내지 않습니다.
    </td>
    <td valign="top">
      <img src="docs/images/cap-language.svg" width="52" height="52" alt=""><br>
      <b>한국어와 영어</b><br>
      처음에는 영어로 보이고, 설정에서 한국어로 바꿀 수 있습니다.
    </td>
  </tr>
</table>

그 밖에 이런 것도 됩니다.

- **Antigravity**(실험 기능): 이 맥의 `agy`나 Antigravity 앱에 로그인된 계정 하나를 봅니다.
- 서비스가 알려 주면 Claude의 모델별 주간 한도와 Antigravity의 모델 그룹별 한도도 보여 줍니다.
- 메뉴 막대 그룹 하나에 어느 계정의 어느 한도든 세 줄까지 넣습니다(링 게이지는 한 줄, 텍스트만은 줄 수 제한 없음). 그룹·줄·계정은 끌어다 놓아 순서를 바꿉니다.
- 읽지 못한 값은 0%가 아니라 `--`로 보여 주고, 지난 값을 보여 줄 때는 저장된 값이라고 표시합니다.
- 1, 2, 5, 10분 중 고른 간격으로 새로 고치고, 바로 새로 고칠 수도 있습니다. 메뉴 막대에 보이는 계정만 새로 고칩니다.
- 맥에 로그인할 때 Limi를 자동으로 열 수 있습니다.

## DOWNLOAD<br>내려받기

<table>
  <tr>
    <td>
      <h3>OPEN SOURCE &nbsp;<sub>무료</sub></h3>
      <ul>
        <li>계정 여러 개</li>
        <li>그룹 추가, 모양 바꾸기, 줄 편집</li>
        <li>언어 선택, 다시 연결, 오류 안내</li>
        <li>MIT 라이선스 오픈소스</li>
      </ul>
      <p><b>0원</b> / 계속 무료</p>
      <p>
        <a href="https://github.com/kalti-lab/limi/releases/latest/download/Limi.zip"><img src="https://img.shields.io/badge/Download-0f1115?style=for-the-badge&logo=apple&logoColor=white" alt="내려받기"></a>
        <a href="https://kalti.co.kr/ko/limi/"><img src="https://img.shields.io/badge/kalti.co.kr%2Flimi-eef1f5?style=for-the-badge" alt="kalti.co.kr의 Limi 소개 페이지"></a>
      </p>
    </td>
  </tr>
</table>

Apple Silicon 맥, macOS 14 이상에서 쓸 수 있습니다.

1. [kalti.co.kr/limi](https://kalti.co.kr/ko/limi/)나 [GitHub 최신 릴리스](https://github.com/kalti-lab/limi/releases/latest)에서 **Limi.zip**을 내려받습니다.
2. 압축을 풀고 **Limi.app**을 응용 프로그램 폴더로 옮긴 뒤 엽니다.

Developer ID로 서명하고 Apple의 공증을 받은 앱입니다. [Sparkle](https://sparkle-project.org)로 스스로 업데이트하며, 새 버전은 하루에 한 번쯤 확인합니다.

## REQUIREMENTS<br>필요한 것

<p>
  <img src="docs/images/need-mac.svg" width="22" height="22" align="absmiddle" alt=""> &nbsp;Apple Silicon 맥, macOS 14(Sonoma) 이상<br>
  <img src="docs/images/need-cli.svg" width="22" height="22" align="absmiddle" alt=""> &nbsp;Claude Code나 Codex 공식 명령줄 도구(Homebrew로 설치하길 권장)<br>
  <img src="docs/images/need-api.svg" width="22" height="22" align="absmiddle" alt=""> &nbsp;계정마다 구독 로그인이 필요합니다. API 키로 쓴 사용량은 보지 않습니다.
</p>

## GETTING STARTED<br>처음 쓰기

Limi를 처음 열면 계정이 없으므로 **설정 › 계정**이 열립니다. **계정 추가…**를 누르고 서비스를 고르세요. 추가하는 서비스마다 공식 명령줄 도구가 있어야 합니다.

| 서비스 | 필요한 것 | 로그인하는 방법 |
|---|---|---|
| Claude | [Claude Code](https://code.claude.com/docs/en/setup) (`claude`) | Limi가 그 계정용 폴더를 따로 두고 `claude auth login --claudeai`를 실행해, 브라우저에 Claude 로그인 페이지를 엽니다. |
| Codex | [Codex CLI](https://github.com/openai/codex) (`codex`) | Limi가 그 계정용 폴더를 따로 두고 `codex app-server`를 띄워, ChatGPT 로그인 페이지를 엽니다. |
| Antigravity (실험 기능) | 로그인해 둔 [`agy`](https://antigravity.google/cli) | 터미널에서 `agy`를 한 번 실행해 로그인해 두세요. Limi는 거기 로그인된 계정을 읽습니다. `agy`가 없으면 Antigravity 앱이 열려 있는 동안 앱에서 읽습니다. |

- 처음 Claude 계정을 추가하기 전에 Limi가 Claude 로그인을 어떻게 보관하는지 설명하고 동의를 받습니다([Claude와 Anthropic 약관](#claude와-anthropic-약관) 참고).
- 브라우저에 로그인된 계정 말고 다른 계정을 추가하려면, Claude 승인 페이지에서는 **Switch account**를(claude.ai 로그인도 함께 바뀝니다), ChatGPT 페이지에서는 **Sign in with another account**를 고르세요. Limi에서 **비공개 창으로 로그인**을 누르면 평소 브라우저 로그인과 섞이지 않는 비공개 창에서 로그인합니다.
- Limi에서 로그인해도 평소 쓰는 `claude`, `codex`의 로그인은 바뀌지 않습니다.
- Limi는 셸의 `PATH`를 쓰지 않고, 아래 폴더에서 도구를 찾습니다.
  - `claude`: `/opt/homebrew/bin`, `/usr/local/bin`, `~/.local/bin`, `~/.bun/bin`
  - `codex`: `/opt/homebrew/bin`, `/usr/local/bin`, `~/.bun/bin`
  - `agy`: `~/.local/bin` (또는 `/Applications`에 있는 Antigravity 앱)
- Limi는 이 도구들을 `/usr/bin/python3`로 실행합니다. `/usr/bin/python3`는 Xcode Command Line Tools(`xcode-select --install`)에 들어 있습니다.

그다음 **설정 › 메뉴 막대**에서 그룹을 만들고, 모양을 고르고, 그룹마다 보여 줄 한도를 정합니다. 메뉴 막대의 그룹을 누르면 자세한 내용이 나옵니다. 응용 프로그램 폴더에서 Limi를 다시 열면 설정 창이 다시 열립니다.

## BUILD FROM SOURCE<br>소스로 빌드하기

macOS 14 이상과 Swift 6.2 이상(Xcode 26 이상)이 필요합니다.

```sh
git clone https://github.com/kalti-lab/limi.git
cd limi
swift test
./scripts/build-app.sh
open Limi.app
```

처음 빌드할 때 [Sparkle](https://github.com/sparkle-project/Sparkle)을 내려받고, 정해 둔 SHA-256 값과 맞는지 확인합니다. 옵션은 `./scripts/build-app.sh --help`로 볼 수 있습니다. 서명은 하지 않아도 됩니다. 서명할 인증서를 따로 주지 않으면 임시(ad hoc) 서명을 하고, 내 맥에서 돌리기에는 이것으로 충분합니다.

## HOW IT WORKS AND PRIVACY<br>동작 방식과 개인정보

Limi에는 서버가 없고, Limi에 따로 가입할 필요도 없습니다. 이 맥에 저장된 로그인 정보를 읽어 각 서비스에 직접 묻습니다.

- **로그인 정보.** 추가한 계정마다 `~/.agentbar/multi-account-v1/` 안에 내 macOS 사용자만 읽을 수 있는 폴더가 생기고, Limi는 거기 둔 로그인 정보를 읽습니다. 평소 쓰는 `claude`, `codex`, `agy`의 로그인을 가져오거나 바꾸지 않습니다. 설정에서 계정을 지우면 그 계정의 로그인 정보와 저장된 사용량도 지워집니다.
- **Claude.** Limi가 계정 토큰으로 Anthropic OAuth 사용량 API(`api.anthropic.com/api/oauth/usage`)를 직접 부르고, 요청에는 `Limi/<버전>`이라고 Limi 이름을 밝힙니다. 토큰이 만료되면 Limi가 리프레시 토큰으로 직접 갱신하는데, Limi가 관리하는 계정만 갱신합니다. 로그인 직후 Claude Code가 키체인에 저장한 로그인 정보를 계정 폴더에 한 번 복사하고, 그 뒤로는 그 파일만 읽습니다.
- **Codex.** 공식 `codex app-server`(`account/read`, `account/rateLimits/read`)로 읽습니다. 계정마다 `CODEX_HOME`을 따로 두고 띄우며, 네트워크 요청은 Codex CLI가 합니다.
- **Antigravity.** Antigravity 로그인 정보는 Limi가 갖고 있지 않습니다. Limi는 `agy -p /usage`를 실행해 읽는데, 이 명령은 모델을 돌리지 않고 한도 보고만 출력하므로 한도를 쓰지 않습니다. 터미널 없이, 브라우저를 열 수 없는 상태로 실행하므로 `agy`가 로그인되어 있지 않으면 바로 멈추고 계정에 로그인하라는 안내가 뜹니다. `agy`가 없으면 Antigravity 앱이 열려 있는 동안 앱의 로컬 서버(`127.0.0.1`)에 묻습니다.
- **칼티로 보내는 정보는 없습니다.** 분석 도구나 사용 통계 수집도 없습니다. kalti.co.kr에는 업데이트를 확인할 때만 접속하고, 업데이트 파일은 GitHub 릴리스에서 받습니다.

### Claude와 Anthropic 약관

Anthropic의 [Claude Code 약관](https://code.claude.com/docs/en/legal-and-compliance)은 Claude 로그인을 보관하는 앱을 제한합니다. 그래서 Anthropic이 언제든 이 방식을 막을 수 있습니다. Limi는 처음 Claude 계정을 추가하기 전에 이 점을 알리고 한 번 동의를 받습니다. Anthropic이 막으면 다시 연결해도 소용이 없으므로, 다시 연결하라고 하지 않고 막혔다고 알려 줍니다.

### Antigravity와 Google 약관

Google의 [Antigravity 약관](https://antigravity.google/terms)은 다른 소프트웨어가 Antigravity 로그인을 쓰지 못하게 합니다. 그래서 Limi는 로그인 정보를 쓰지 않고 `agy`나 앱에 묻습니다. 둘 다 문서로 공개된 방식이 아니어서, Antigravity가 업데이트되면 멈출 수 있습니다.

## DISCLAIMER<br>알림

Limi는 비공식 앱입니다. Anthropic, OpenAI, Google과 관계가 없고, 이 회사들이 승인하거나 후원한 앱도 아닙니다. 이 회사들이 언제든 바꾸거나 막을 수 있는 방식으로 사용량을 읽으므로, 그렇게 되면 Limi가 멈출 수 있습니다. Claude, Claude Code, ChatGPT, Codex, Antigravity 같은 제품 이름은 각 회사의 상표입니다.

## CREDITS<br>만든 사람

Limi는 [jsiksn](https://github.com/jsiksn)이 만들었습니다. [chenjingdev](https://github.com/chenjingdev)의 [AgentBar](https://github.com/chenjingdev/agent-bar)에서 시작했습니다.

## LICENSE<br>라이선스

[MIT](LICENSE)

<br>

<p align="center">
  <a href="https://kalti.co.kr/ko/"><picture><source media="(prefers-color-scheme: dark)" srcset="docs/images/kalti-wordmark-dark.svg"><img src="docs/images/kalti-wordmark.svg" height="26" alt="KALTI"></picture></a>
</p>
<p align="center">
  <sub>Made by KALTI — <a href="https://kalti.co.kr/ko/">kalti.co.kr</a> · <a href="mailto:support@kalti.co.kr">support@kalti.co.kr</a></sub>
</p>
