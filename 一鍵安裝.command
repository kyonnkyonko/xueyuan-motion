#!/bin/bash
# 學園好食 motion 工具：一鍵檢查＆安裝（macOS）
# 在 Finder 裡雙擊這個檔案就會打開終端機執行。
# 會先檢查全部，列出缺什麼，問過你之後才安裝。
# 只檢查不安裝：bash 一鍵安裝.command --check

cd "$(dirname "$0")" || exit 1
CHECK_ONLY=0
[ "$1" = "--check" ] && CHECK_ONLY=1

ok()   { printf "  \033[32m✔\033[0m %s\n" "$1"; }
bad()  { printf "  \033[31m✘\033[0m %s\n" "$1"; }
# 開放授權字型：思源黑體（全部頁面）、思源宋體（剪貼字卡）、jf open 粉圓（剪貼字卡）
FONTS=(
  "NotoSansTC|NotoSansTC-VariableFont_wght.ttf|https://github.com/google/fonts/raw/main/ofl/notosanstc/NotoSansTC%5Bwght%5D.ttf|Noto Sans TC 字型"
  "NotoSerifTC|NotoSerifTC-VariableFont_wght.ttf|https://github.com/google/fonts/raw/main/ofl/notoseriftc/NotoSerifTC%5Bwght%5D.ttf|Noto Serif TC 字型"
  "jf-openhuninn|jf-openhuninn-2.1.ttf|https://github.com/justfont/open-huninn-font/releases/download/v2.1/jf-openhuninn-2.1.ttf|jf open 粉圓 字型"
)

# 讓剛裝好的 Homebrew 也找得到（Apple 晶片和 Intel 的位置不同）
load_brew() {
  for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    [ -x "$b" ] && eval "$("$b" shellenv)" && return 0
  done
  return 1
}

has_font() {
  for f in "$HOME"/Library/Fonts/"$1"* /Library/Fonts/"$1"*; do
    [ -e "$f" ] && return 0
  done
  return 1
}

check_all() {
  MISSING=()
  echo ""
  echo "檢查中…"
  load_brew
  if command -v brew >/dev/null; then ok "Homebrew"; else bad "Homebrew（用來安裝其他工具）"; MISSING+=(brew); fi
  if command -v node >/dev/null; then ok "Node.js $(node -v)"; else bad "Node.js"; MISSING+=(node); fi
  if command -v ffmpeg >/dev/null && ffmpeg -hide_banner -encoders 2>/dev/null | grep -q prores_ks; then
    ok "ffmpeg"
  else
    bad "ffmpeg"; MISSING+=(ffmpeg)
  fi
  if command -v python3 >/dev/null; then
    ok "Python $(python3 -V 2>&1 | cut -d' ' -f2)"
    if python3 -c "import numpy" 2>/dev/null; then ok "numpy"; else bad "numpy（音效用）"; MISSING+=(numpy); fi
  else
    bad "Python 3"; MISSING+=(python numpy)
  fi
  for e in "${FONTS[@]}"; do
    IFS='|' read -r pre file url label <<< "$e"
    if has_font "$pre"; then ok "$label"; else bad "$label"; need font || MISSING+=(font); fi
  done
  if [ -d node_modules/playwright-core ]; then ok "輸出工具（playwright-core）"; else bad "輸出工具（playwright-core）"; MISSING+=(npm); fi
  if [ -d node_modules/playwright-core ] && command -v node >/dev/null && node render.mjs --check >/dev/null 2>&1; then
    ok "瀏覽器"
  else
    bad "瀏覽器（或還不能測試）"; MISSING+=(browser)
  fi
}

need() { [[ " ${MISSING[*]} " == *" $1 "* ]]; }

install_missing() {
  if need brew; then
    echo ""; echo "▶ 安裝 Homebrew（過程中會要你輸入這台電腦的登入密碼）"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    load_brew || { echo "Homebrew 沒有裝成功，請到 https://brew.sh 照說明安裝後再執行一次。"; return 1; }
  fi
  need node   && { echo ""; echo "▶ 安裝 Node.js"; brew install node; }
  need ffmpeg && { echo ""; echo "▶ 安裝 ffmpeg"; brew install ffmpeg; }
  need python && { echo ""; echo "▶ 安裝 Python"; brew install python; }
  if need numpy; then
    echo ""; echo "▶ 安裝 numpy"
    python3 -m pip install --user numpy 2>/dev/null || brew install numpy
  fi
  if need font; then
    mkdir -p "$HOME/Library/Fonts"
    for e in "${FONTS[@]}"; do
      IFS='|' read -r pre file url label <<< "$e"
      has_font "$pre" && continue
      echo ""; echo "▶ 下載 $label（開放授權）"
      curl -fL -o "$HOME/Library/Fonts/$file" "$url" || echo "$label 下載失敗，請把這個網址貼給協助你的人：$url"
    done
  fi
  if need npm || need node; then
    echo ""; echo "▶ 安裝輸出工具（npm install）"
    npm install
  fi
  if ! node render.mjs --check >/dev/null 2>&1; then
    echo ""; echo "▶ 下載輸出用的瀏覽器"
    npx playwright-core install chromium
  fi
}

echo "=== 學園好食 motion 工具：環境檢查 ==="
check_all

if [ ${#MISSING[@]} -eq 0 ]; then
  echo ""; echo "全部都準備好了，可以直接用 node render.mjs 輸出。"
  [ $CHECK_ONLY -eq 0 ] && read -r -p "按 Enter 關閉…"
  exit 0
fi

if [ $CHECK_ONLY -eq 1 ]; then
  echo ""; echo "有 ${#MISSING[@]} 項還沒準備好。"
  exit 1
fi

echo ""
read -r -p "要現在安裝缺少的項目嗎？(y/n) " ans
if [ "$ans" != "y" ] && [ "$ans" != "Y" ]; then
  echo "沒有安裝任何東西。"; read -r -p "按 Enter 關閉…"; exit 1
fi

install_missing
echo ""; echo "=== 安裝完成，再檢查一次 ==="
check_all
echo ""
if [ ${#MISSING[@]} -eq 0 ]; then
  echo "全部都準備好了！"
else
  echo "還有 ${#MISSING[@]} 項沒成功，請把上面的畫面截圖給協助你的人看。"
fi
read -r -p "按 Enter 關閉…"
