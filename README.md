# 學園好食 motion：轉場動畫產生器

用網頁畫動畫，再一格一格截圖輸出成影片。拿來做影片裡的片頭、章節標題、紙條標題和金句卡。
改文字、改時間只要編輯一個設定檔，不用開剪輯軟體做動畫。

![動畫預覽](docs/preview.jpg)

- 透明背景的動畫輸出成 `.mov`（ProRes 4444），可以直接疊在 DaVinci Resolve 的正片上面
- 全版背景的動畫輸出成高畫質 `.mp4`
- 音效是程式自己合成的，已經封在影片裡，沒有用到外部音效素材
- Mac 和 Windows 都能用，各有一鍵安裝

## 能做哪些動畫

| 類別 | 頁面 | 樣式 |
|---|---|---|
| 片頭 | `index.html` | A 畫碗、C 斜切、E 左右 |
| 章節標題 | `index.html` | A 有號碼、B 置中（四種音效可選）、C 膠囊 |
| 紙張標題 | `titles.html` | 撕紙條或多層拼貼；重點句或小標題條；橫排或直排；透明、全版紙張或筆記本背景 |
| 全版金句卡 | `quote.html` | 撕紙條（原版、筆記本）、乾淨排版、撕開露字、立體書（夜晚城市）、剪紙景深（夜晚山丘、海浪）、信封（明信片、三張小卡） |
| 剪貼字卡 | `collage.html` | 每個字一張紙片，鏡頭先近後遠 |
| 名畫介紹 | `painting.html` | 羊皮紙書，右頁名畫、左頁手寫介紹 |

金句卡可以配合台詞速度，指定每一句出現的秒數。

## 下載

**不會用 git：** 在這個頁面上方按綠色的 **Code** →「**Download ZIP**」，下載後解壓縮。

**會用 git：**

```bash
git clone https://github.com/kyonnkyonko/xueyuan-motion.git
```

## 安裝

需要：Node.js、ffmpeg、Python 加 numpy、三套開放授權字型（Noto Sans TC、Noto Serif TC、jf open 粉圓）、瀏覽器。
一鍵安裝會先檢查這些，列出缺什麼，問過你才安裝。

### Mac

在 Finder 裡雙擊 **`一鍵安裝.command`**。

- 第一次裝 Homebrew 時會要你輸入電腦的登入密碼
- 如果 Mac 說「無法打開」：對檔案按右鍵 → 打開 → 再按一次打開

### Windows 10／11

在檔案總管裡雙擊 **`一鍵安裝_Windows.bat`**（`windows-setup.ps1` 要放在同一個資料夾）。

- 如果跳出「Windows 已保護您的電腦」：按「其他資訊」→「仍要執行」
- 工具用 Windows 內建的 winget 安裝。找不到 winget 的話，到 Microsoft Store 安裝或更新「應用程式安裝程式」
- 裝好後先關掉視窗，再打開新的終端機來輸出

看到「全部都準備好了」就完成了。只想檢查不安裝：Mac 用 `bash 一鍵安裝.command --check`，Windows 用 `.\一鍵安裝_Windows.bat --check`。

## 使用

### 1. 在瀏覽器裡預覽

直接用瀏覽器打開 `index.html`、`titles.html`、`quote.html`、`collage.html` 或 `painting.html`，下方可以切換樣式、改文字，馬上看到效果。預覽不會播音效。

### 2. 寫進設定檔

打開 `jobs.json`，一行是一支影片。例如：

```json
  {"name": "ep3_ch2", "scene": "chapter2", "title": "怎樣成為好朋友", "sfx": "4"},
  {"name": "金句卡_海浪", "page": "quote.html", "style": "layers", "v": "3", "title": "#友誼不進則退\n單看你願意主動多少\n主動的人必有收穫！"},
```

- `name`：輸出的檔名
- `page`：用哪個頁面，不寫就是 `index.html`（片頭和章節）
- 其他欄位會原樣傳給頁面，每種動畫可以填什麼，請看 [使用說明.md](使用說明.md)
- 每行最後要有逗號，只有最後一行不用

### 3. 輸出

在這個資料夾打開終端機（Mac：終端機 `cd` 到這裡；Windows：在資料夾空白處按右鍵 →「在終端機中開啟」），然後輸入：

```bash
node render.mjs ep3_ch2
```

- `node render.mjs` 後面接的字：只輸出名稱裡有這段字的項目，不接就全部輸出
- 名稱前面加 `=`：只輸出名稱完全一樣的那一個，例如 `node render.mjs =ep3_ch2`
- 做好的影片在 `output/` 資料夾

## 資料夾內容

| 檔案 | 用途 |
|---|---|
| `index.html` | 片頭、章節標題 |
| `titles.html` | 紙張標題（撕紙條、多層拼貼） |
| `quote.html` | 全版金句卡 |
| `collage.html` | 剪貼字卡 |
| `painting.html` | 名畫介紹 |
| `render.mjs` | 逐格截圖並輸出影片 |
| `sfx.py` | 合成音效 |
| `logo.js` | 學園好食 logo 的向量路徑 |
| `jobs.json` | 要輸出哪些影片 |
| `textures/` | 紙張材質照片 |
| `images/` | 名畫圖片 |
| `使用說明.md` | 每種動畫的詳細設定 |

## 授權

**程式碼**使用 [MIT 授權](LICENSE)，可以自由使用、修改。

以下內容**不在** MIT 授權範圍內：

- 「學園好食」名稱、logo（`logo.js` 裡的向量路徑），以及品牌色彩組合，屬於學園好食所有。使用這套程式做自己的影片時，請換成你自己的品牌

其他素材：

- `textures/` 的紙張照片：[ambientCG](https://ambientcg.com/)，CC0 公眾領域，可商用、免標註
- `images/praying_hands.jpg`：阿爾布雷希特·杜勒《禱告的手》（1508），公有領域作品。圖片來自 [Wikimedia Commons](https://commons.wikimedia.org/wiki/File:Albrecht_D%C3%BCrer_-_Praying_Hands,_1508_-_Google_Art_Project.jpg)（Google Arts & Culture），已調成咖啡色調
- 字型不包含在這裡，由一鍵安裝從原始來源下載：Noto Sans TC、Noto Serif TC（SIL Open Font License），jf open 粉圓（SIL Open Font License）
- 音效全部由 `sfx.py` 合成，沒有使用外部音效檔
