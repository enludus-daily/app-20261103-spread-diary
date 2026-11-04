# App Store 提出の準備

> 名前・説明・キーワードなどの正本は `docs/app-store.json`（daily-actions の asc が App Store Connect に API で入れる）。ここは審査の危険と、本人がすることの記録。

| 項目 | 内容 |
|---|---|
| Bundle ID | com.enludus.daily.001 |
| アプリ名 | 言いたい英語ドリル（ホーム画面の表示名は「言いたい英語」） |
| サブタイトル | 日本語から英作文と復習ドリル |
| カテゴリ | 教育（サブ：仕事効率化） |
| サポート URL | https://github.com/enludus-daily/app-20261103-spread-diary/issues |
| プライバシーポリシー URL | https://github.com/enludus-daily/app-20261103-spread-diary/blob/main/PRIVACY.md |
| 年齢区分の答え | 暴力・性的表現・ギャンブル・Web 閲覧・利用者どうしの交流：すべてなし。生成 AI で文章を作る機能あり（端末の中のモデル。英語の言い方と単語だけ）→ 4+ の想定 |
| 輸出コンプライアンス | `ITSAppUsesNonExemptEncryption = NO`（標準の暗号だけ） |

## 審査の危険

- 4.3(b) の種類に当たらない理由：懐中電灯・効果音・壁紙・単純なタイマー・占い・出会いのどれでもない。自分の文から教材を作る英語学習の道具。
- 既存のアプリとの意味のある違い：決まった教材ではなく、自分が言いたい日本語から英語・単語カード・3 段階のドリルを作り、間隔をあけて復習できる。通信しない。
- 長く使える価値（4.2）：自分のフレーズ集がたまり、覚えるまで復習が続く。
- 他社の名前・商標・見た目：使っていない。「Apple Intelligence」「iPhone Duo」は機能の説明としてだけ書く（表記は本人が確かめる）。
- Apple Intelligence が使えない端末：Apple の翻訳（端末の中）で英文にし、単語は文からタップして作る。翻訳も使えないときは英語を手で書ける。ドリルはどの端末でも同じ。

## 収益の道筋（本人が選ぶ）

- 勧める：買い切り（StoreKit 2）で「フレーズ数の上限なし」または「英語以外の言語」。続けて使う学習アプリなので、価値が分かってから払う形が合う。
- ほか：投げ銭。広告は勧めない（集中を妨げ、データの収集なしを保てなくなる）。

## App プライバシーの答え（下書き。申告は本人）

- データの収集：**なし**（根拠：通信しない、解析・広告 SDK なし、保存は端末の UserDefaults だけ。英語を作る処理は端末の中の Foundation Models / Translation）
- トラッキング：なし
- Privacy manifest：`App/Resources/PrivacyInfo.xcprivacy`（UserDefaults: CA92.1）

## スクリーンショット

CI の artifact `screenshots`（iPhone Duo のシミュレータ）。最初に開いたときの見本のフレーズ 2 つが出る。ドリルの画面は本人が TestFlight で撮る。

## 本人がすること

- [ ] App プライバシーを申告する（API がないため）
- [ ] TestFlight で動作を確かめる（Apple Intelligence に対応する iPhone と、対応しない iPhone の両方で）
- [ ] スクリーンショットを確かめる
- [ ] 審査に提出する
