# 言いたい英語ドリル（SpreadDiary）

**日本語で言いたいことを書くと、英語の言い方・単語カード・練習ドリルができる** iOS アプリ。自分が本当に言いたいことが、そのまま毎日の復習の材料になる。enludus-daily の 2026-11-03 のアプリ（記録: https://github.com/enludus-daily/daily-ideas/issues/3 ）。

> 最初は「見開き英日記」（英文の添削を見開きで比べる）として作ったが、本人の評価（「淡白」）を受けて 2026-11-04 に作り直した。リポジトリ名とスキーム名（SpreadDiary）はそのとき のまま。

## だれの・何のため

英語を学んでいるが、教材の例文は自分の生活と関係がなく、**自分が言いたいこと**を英語で言えるようにならない人のため。語学アプリのレビューにも「自分の文を作る機会がない」という声がある（daily-ideas #3）。

## 使い方

1. 「日本語で言いたいこと」に書く（例：明日の会議、少し遅らせてもらえますか？）
2. 「英語にしてドリルを作る」
   - **Apple Intelligence が使えるとき**：端末の中のモデル（Foundation Models の guided generation）が、自然な英文・丁寧な言い方・くだけた言い方・単語と意味を作る
   - **使えないとき**：Apple の翻訳（Translation。端末の中）で英文にする。単語は文の中からタップしてカードにする
   - どちらも、保存の前に英語と単語の意味を直せる。翻訳もできないときは、英語を自分で書ける
3. 「ドリルを始める」：覚えた度合いに合わせて、**並べ替え → 穴埋め → 日本語を見て英語を言う** の順に難しくなる
4. 間違えたフレーズはすぐまた出し、できたフレーズは 1・2・4・7・15・30 日後に出す（間隔をあけた復習）
5. 英文は読み上げられる（端末の音声）。続けた日数・覚えた数が分かる

## iPhone Duo

- ホームは `NavigationSplitView`：内側の画面では左に入力と一覧、右にフレーズの中身。閉じると 1 列に重なる
- ドリルは size class で並べ方を変える：regular では左に問題、右に答える所。compact では上下
- 機種・向き・画面の大きさでは決めない（Apple Tech Talk「Prepare your app for iPhone Duo」 https://developer.apple.com/videos/play/tech-talks/111461/ ）

## 作らなかったもの

英語以外の言語、同期・共有・バックアップ、通知、課金、ログイン、音声認識（「言ってみる」は自分で判定する）。データは端末の UserDefaults だけ。

## 中身

| パス | 役割 |
|---|---|
| `App/Sources/Phrase.swift` | フレーズ・単語カード・言い方の違い・復習の状態（箱と次に出す日） |
| `App/Sources/Drill.swift` | 単語に分ける、並べ替え・穴埋めの問題を作る、今日のドリルを選ぶ |
| `App/Sources/PhraseGenerator.swift` | 英語を作る役のプロトコル、出力を整える |
| `App/Sources/OnDeviceGenerator.swift` | Foundation Models を使う本物（`@Generable` で形を決める） |
| `App/Sources/PhraseStore.swift` | 保存（UserDefaults）、答えの記録、続けた日数 |
| `App/Sources/ContentView.swift` ほか | 画面（ホーム、下書きの確認、フレーズの中身、ドリル） |
| `Tests/SpreadDiaryTests.swift` | 振る舞いのテスト（モデルは偽物に差し替える） |
| `docs/app-store.json` | App Store Connect に API で入れる情報（daily-actions の asc が読む） |
| `PRIVACY.md` | プライバシーポリシー |

## 版

- iOS 26.0 以降（Foundation Models が iOS 26 から）、iPhone だけ、Swift 6
- 一次資料：Foundation Models https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel 、guided generation https://developer.apple.com/documentation/foundationmodels/generating-swift-data-structures-with-guided-generation 、Translation https://developer.apple.com/documentation/translation/translationsession
- CI：Xcode 27.1、iPhone Duo のシミュレータ（`.github/workflows/ci.yml`）

## 手元（Mac）で開く

```sh
brew install xcodegen
xcodegen generate
open SpreadDiary.xcodeproj
```
