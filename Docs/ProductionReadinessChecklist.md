# Poco 本番公開チェックリスト

最終更新: 2026-08-03

この文書は、Pocoを本番公開するまでの作業を、依存関係順に「オーナーが行う作業」「Codexが行う作業」「共同確認」へ分けたものです。

ステータス:

- `[x]` 完了
- `[~]` コードまたは設計はあるが、外部設定・実機確認が未完了
- `[ ]` 未着手
- `[!]` 公開ブロッカー

## 0. 直ちに行うセキュリティ対応

### オーナー

- [!] 過去にチャットへ貼り付けたGitHub Personal Access TokenをGitHubの設定画面で直ちに失効し、必要なら最小権限・短い有効期限で再発行する。新しいTokenはチャット、Git、Swift、xcconfigへ貼らない。
- [ ] GitHubとApple IDで2要素認証を有効化し、復旧コードを安全な場所へ保存する。
- [ ] Supabase、Apple、広告サービスの管理者を必要最小限にする。

### Codex

- [x] `Config/Secrets.xcconfig`をGit対象外にし、公開可能なexample設定だけを管理する。
- [x] 追跡ファイルとGit履歴へ秘密情報が混入していないか、値を表示しない方式の自動検査を追加する。
- [~] Supabaseの公開RPC、RLS、GRANT、`SECURITY DEFINER`、Storage Policyを静的監査済み。全iOS呼び出しRPCの明示GRANTを確認済みで、Staging適用後の実効権限確認が残る。

### 共同確認

- [ ] 漏洩疑いのある鍵は「Gitから消した」だけで済ませず、発行元で失効済みであることを確認する。

## 1. Apple・App Store Connectの準備

### オーナー

- [ ] Apple Developer Programの契約状態を確認する。
- [ ] App Store ConnectでBundle ID `com.fumiakiMogi777.poco`のアプリを作成する。
- [ ] Paid Applications Agreement、税務情報、入金口座を登録する。
- [ ] App IDへSign in with Apple、Associated Domains、Push Notifications、Sensitive Content Analysisを設定する。
- [ ] 本番用Development／Distribution証明書とProvisioning Profileを更新する。
- [ ] App Storeの商品名、サブタイトル、説明、キーワード、サポートURL、Privacy Policy URL、スクリーンショットを準備する。
- [ ] 年齢レーティング、UGC、広告、課金、データ収集の質問へ実態どおり回答する。

### Codex

- [x] iOS 17.0、Swift 6、Bundle ID、Entitlementsのコード側基盤を維持する。
- [~] `PrivacyInfo.xcprivacy`へUserDefaultsのRequired Reasonを追加済み。収集データ宣言、広告SDK、Capabilitiesとの最終一致は本番SDK確定後に再検査する。
- [~] iOS 17指定のDebug／Releaseビルドを検証済み。Archive Validationと審査用の動作説明が残る。

## 2. Webページ・QR・Universal Links

### オーナー

- [ ] GitHub Pagesで `https://ben-kei-create.github.io` を公開する。
- [ ] `Web/.well-known/apple-app-site-association`を正しいTeam ID／Bundle IDで配信する。
- [ ] 利用規約、Privacy Policy、サポート、権利者向け削除申請窓口をWebで公開する。
- [ ] App Store公開後、未インストール時にApp Storeへ遷移する案内ページを公開する。
- [ ] 将来独自ドメインへ移行しても、印刷済みQRのGitHub Pages URLはリダイレクト元として維持する。

### Codex

- [x] `poco://project/{projectID}`とHTTPS Project URLの解析基盤を実装済み。
- [~] GitHub Pages用AASAと案内ページの素材を用意済み。実際の配信・実機検証は未完了。
- [ ] iPhone実機で「インストール済み」「未インストール」「無効ID」「非公開作品」「削除済み作品」を検証する。

## 3. Supabase本番・ステージング環境

### オーナー

- [!] Supabaseで本番Projectと、可能なら別のStaging Projectを作成する。
- [!] `Config/Secrets.example.xcconfig`をコピーしてローカルの`Config/Secrets.xcconfig`を作り、実際のProject URLと公開用Keyを設定する。
- [ ] Supabase CLIをインストールし、Projectをlinkする。秘密情報をコマンド履歴へ直書きしない。
- [ ] Anonymous Sign-In、Sign in with Apple、CAPTCHA、Auth rate limitを設定する。
- [ ] `project-images`、`profile-avatars`、画像検疫用の非公開Bucketを設定する。
- [ ] Daily BackupまたはPITRを有効化し、復元手順を確認する。
- [ ] DB容量、CPU、接続数、5xx、RPC p95、Auth失敗、Realtime接続のアラートを設定する。

### Codex

- [~] Domain Model、DTO、Repository、Realtime、Storage、RLS Migrationを実装済み。
- [~] 全Migrationを静的監査し、iOSが呼ぶ全RPCの明示的な実行GRANTを確認済み。StagingでSecurity Advisorと実効RLSを確認してから本番へ適用する。
- [ ] 最新MigrationをStagingへ適用し、Security Advisor／Performance Advisorの指摘を解消する。
- [ ] Feedback、Home、活動履歴をカーソルページングし、大量データ時の描画上限を確定する。
- [ ] App Attest Assertion、JWT、nonce、時刻、レート制限を検証するEdge Function Gatewayを実装する。
- [ ] 画像を検疫Bucketへ上げ、再decode・容量・寸法・NSFW検査後に公開する処理を実装する。

### 共同確認

- [ ] Mockデータと本番データを混同しないことを、Debug／Release／TestFlightで確認する。
- [ ] 2台以上の実機で投稿、Like、作者Like、削除、通報、ブロック、Q&A、Realtime競合を確認する。

## 4. 認証・会員化・アカウント削除

### オーナー

- [ ] Apple DeveloperとSupabase DashboardでSign in with Appleを接続する。
- [ ] 初回ログイン時にAppleが返すメール情報を保存する運用とPrivacy Policyを確認する。
- [ ] アカウント削除時の問い合わせ・復旧不可の案内を確定する。

### Codex

- [~] Guest／無料会員／Poco ProのUI・Repository境界、Guest→会員のIdentity Link、削除導線を実装済み。
- [~] アカウント削除Edge Functionは実装済み。本番deployとStorage削除の実機確認が未完了。
- [ ] Guest→無料会員→Poco Pro、復元、再インストール、Apple連携解除の回帰テストを追加する。

## 5. StoreKit・Poco Pro

### オーナー

- [!] App Store Connectで月額／年額商品、価格、無料体験、ローカライズを作成する。
- [ ] App Store Server Notifications V2の通知先を設定する。
- [ ] 月額480円・年額3,900円・14日無料体験の初期案を、原価と提供価値を見て最終決定する。
- [ ] Sandbox Testerを作成し、購入・更新・解約・返金・猶予期間を試す。

### Codex

- [x] StoreKit 2の購入／復元とサーバー同期境界を実装済み。
- [!] Apple JWSをサーバー検証する`sync-storekit-membership` Edge Function本体を実装する。現在は契約READMEのみ。
- [ ] Notifications V2も同じ検証・冪等更新経路へ接続する。
- [ ] Product ID、Bundle ID、Environment、期限、取消、Original Transactionの所有者をサーバーで検証する。
- [ ] Pro失効後の作品上限、広告再表示、購入済み装飾、外部リンク上限を回帰テストする。

## 6. 広告

### オーナー

- [ ] AdMob等の事業者を決め、アプリと広告ユニットを作成する。
- [ ] App Tracking Transparencyを使う広告設計か、非追跡型だけにするか決定する。
- [ ] 子ども・センシティブカテゴリ・競合広告のブロック設定を行う。

### Codex

- [~] Guest／無料会員向け広告PlacementとPro非表示条件は実装済み。現在はplaceholder。
- [ ] 広告SDK、テスト広告ID、Consent、失敗時レイアウト、頻度制御を実装する。
- [ ] 購入直後・感想入力中・Bubble Drop中など、コア体験を妨げる画面では表示方針を再確認する。

## 7. Push通知・運営からのお知らせ

### オーナー

- [ ] APNs Keyを発行し、Supabase Function Secretsへ安全に登録する。
- [ ] 通知文面、通知頻度、夜間配信、運営告知の承認フローを決める。

### Codex

- [x] アプリ内通知DB、冪等イベントキー、個別既読、Realtime、お知らせUIを実装済み。
- [!] APNs Device Token登録、配信Edge Function、期限切れToken削除、Pushからの詳細遷移を実装する。
- [ ] Push payloadへ感想本文や個人情報を含めないことをテストする。

## 8. UGC・法務・モデレーション

### オーナー

- [!] 利用規約、Privacy Policy、コミュニティガイドライン、権利者申請手順を専門家確認の上で確定する。
- [!] 通報対応担当、緊急SLA、凍結・復旧・異議申立て手順を決める。
- [ ] App Store Reviewへ、通報・ブロック・削除・問い合わせ方法を説明できるようにする。

### Codex

- [x] 通報、ブロック、作者非表示、証拠Snapshot、ソフト削除、権利者申請の基盤を実装済み。
- [!] 運営が通報・権利申請を処理するAdmin Moderation画面を実装する。
- [ ] 監査証拠を壊さずにRetention／匿名化／30日後パージを実行する定期Jobを用意する。
- [ ] 成人向け設定、ぼかし、画像検疫、検索除外をサーバー側でも検証する。

## 9. 性能・大量データ・障害復旧

### オーナー

- [ ] 想定MAU、1日投稿数、画像容量、広告表示数、月額上限予算を決める。
- [ ] Supabaseと広告の請求アラート／Spend Capを設定する。
- [ ] 障害時の告知先と問い合わせテンプレートを準備する。

### Codex

- [ ] 1作品1万件以上のFeedback、長文、画像3枚、Realtime集中の負荷試験を行う。
- [ ] Bubble表示は最新範囲だけを物理演算し、古い範囲は仮想化／ページングする。
- [ ] Network断、429、5xx、タイムアウト、重複送信、再試行、アプリ強制終了をテストする。
- [ ] Backupから別Projectへ復元するリハーサル手順を文書化する。

## 10. QA・TestFlight・審査

### オーナー

- [ ] 小型iPhone、標準iPhone、Pro Maxの実機を最低1台以上含むTestFlightテスターを集める。
- [ ] VoiceOver利用者、Dynamic Type最大、Reduce Motion、低速回線で確認する。
- [ ] App Storeスクリーンショットとレビュー用アカウント／操作説明を提出する。

### Codex

- [~] 2026-08-03時点でiOS 17指定のDebug／ReleaseビルドとSimulator自動テストは成功。自動テストの対象範囲拡大、実機、Archive検証が残る。
- [ ] 正常、異常、境界、競合、権限、セキュリティのテストケースを画面フロー別に完成させる。
- [ ] Build warning、Memory、Energy、Network、Accessibility Inspectorを確認する。
- [ ] Archiveを作成し、App Store Connect Validationを通す。

## 11. リリース後の運用

### オーナー

- [ ] 毎日: 通報、5xx、課金失敗、異常な投稿・コイン・広告を確認する。
- [ ] 毎週: クラッシュ、継続率、投稿完了率、QR着地率、退会理由を確認する。
- [ ] 毎月: DB／Storage増加、広告収益、Supabase／Apple手数料、Pro解約率を確認する。
- [ ] 四半期: 復元リハーサル、鍵棚卸し、権限棚卸し、規約・SDK更新を行う。

### Codex

- [ ] 運用Runbook、障害対応手順、定期メンテナンス手順、リリースチェックを更新し続ける。
- [ ] SDK・iOS・SupabaseのBreaking Changeを確認し、Stagingで先に検証する。

## 推奨実施順

1. 漏洩Token失効、Apple／Supabase／GitHub Pagesのアカウント準備
2. Migration・RLS・GRANT監査とStaging適用
3. App Attest／CAPTCHA／Edge Function Gateway、画像検疫
4. 法務ページ、Admin Moderation、Retention Job
5. StoreKitサーバー検証、App Store Server Notifications V2
6. APNs Push、本番広告
7. 大量データ対策、全自動テスト、複数実機テスト
8. TestFlight、Archive Validation、審査提出

## 直近の自動検証結果

- Simulator Test: 20件すべて成功（2026-08-03）
- Debug Build: 成功（iOS 17.0、2026-08-03）
- Release Build: 成功（iOS 17.0、2026-08-03）
- Privacy Manifest: Debug／Releaseの両方で`poco.app/PrivacyInfo.xcprivacy`へのCopyを確認
- Swiftコンパイル警告: 0件
- Xcodeツール警告: AppIntents未使用によるMetadata extraction skippedが1件。機能影響なし
- `git diff --check`: 問題なし
