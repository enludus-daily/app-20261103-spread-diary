# 見開き英日記（SpreadDiary）

英語で毎日 1〜3 文の日記を書き、**自分の英文（左のページ）と、直した英文（右のページ）を見開きで比べる** iOS アプリ。enludus-daily の 2026-11-03 のアプリ（記録: https://github.com/enludus-daily/daily-ideas/issues/3 ）。

## だれの・何のため

語学アプリで毎日学んでいるが、**自分で文を書いて直してもらう練習**が足りない人のため。直した文で置き換えるのではなく、元の文と並べて「どこが変わったか」を残し、あとで見返せる。

## 使い方

1. 「今日の英文を書く」で、左のページに英語で書く
2. 右のページ：
   - **Apple Intelligence が使えるとき**：「Apple Intelligence で直す」で、端末の中のモデル（Foundation Models）が直した文と日本語の短い説明を書く。通信しない。提案なので誤ることがある
   - **使えないとき**（非対応の端末・設定でオフ・準備中・英語に未対応）：理由を表示する。右のページに自分で直した文を書ける
3. 「変わった所」に、消えた単語（取り消し線）と増えた単語（太字）が出る
4. 一覧で、続けて書いた日数が分かる

## iPhone Duo

- 内側の画面（horizontal size class が regular）では、左右のページを**横に並べる**（本の見開き）
- 外側の画面・ほかの iPhone（compact）では、上下に重ねる
- 機種・向き・画面の大きさではなく size class で決める（Apple Tech Talk「Prepare your app for iPhone Duo」 https://developer.apple.com/videos/play/tech-talks/111461/ ）

## 作らなかったもの

音声、英語以外の言語、同期・共有・バックアップ、通知、課金、単語帳、ログイン。データは端末の UserDefaults だけ。

## 中身

| パス | 役割 |
|---|---|
| `App/Sources/DiaryEntry.swift` | 1 日分の日記（文字数の上限 600） |
| `App/Sources/DiaryStore.swift` | 保存（UserDefaults）、続けた日数、直す流れ |
| `App/Sources/WordDiff.swift` | 単語ごとの差分（最長共通部分列） |
| `App/Sources/Streak.swift` | 続けて書いた日数 |
| `App/Sources/SentenceCorrector.swift` | 直す役のプロトコルと、モデルの答えの読み取り |
| `App/Sources/OnDeviceCorrector.swift` | Foundation Models を使う本物（`SystemLanguageModel.availability` で確かめる） |
| `App/Sources/ContentView.swift`, `SpreadView.swift` | 一覧と見開きの画面 |
| `Tests/SpreadDiaryTests.swift` | 振る舞いのテスト（モデルは偽物に差し替える） |

## 版

- iOS 26.0 以降（Foundation Models が iOS 26 から。https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel ）、iPhone だけ、Swift 6
- CI：Xcode 27.1、iPhone Duo のシミュレータ（`.github/workflows/ci.yml`）

## 手元（Mac）で開く

```sh
brew install xcodegen
xcodegen generate
open SpreadDiary.xcodeproj
```
