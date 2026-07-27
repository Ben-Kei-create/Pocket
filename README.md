# Poco

SwiftUIで作られた、クリエイターへパステルカラーのフキダシで感想を届けるiOSアプリです。

## Requirements

- Xcode 26.5+
- Swift 6
- iOS 17.0+
- Supabase Swift SDK 2.46.0

認証情報がない状態ではMock Repositoryで動作します。既存の投稿体験、Preview、開発用MockはSupabaseの設定なしで利用できます。

## Supabaseセットアップ

1. Supabase DashboardでProjectを作成します。
2. Project SettingsのAPI画面からProject URLとPublishable/Anon Keyを取得します。Service Role Keyはアプリへ設定しないでください。
3. `Config/Secrets.example.xcconfig`を`Config/Secrets.xcconfig`へコピーします。
4. `Secrets.xcconfig`へ値を設定します。URL内の`//`はxcconfigでコメント扱いされるため、次の形式を維持してください。

   ```xcconfig
   POCO_BACKEND = supabase
   SUPABASE_URL = https:/$()/YOUR_PROJECT_REF.supabase.co
   SUPABASE_ANON_KEY = YOUR_SUPABASE_ANON_KEY
   POCO_DEVELOPMENT_USER_ID =
   ```

5. Supabase CLIでプロジェクトをリンクし、Migrationを適用します。

   ```sh
   supabase login
   supabase link --project-ref YOUR_PROJECT_REF
   supabase db push
   ```

6. `003_storage.sql`によって公開Bucket `project-images`が作成されていることをStorage画面で確認します。
7. Table Editorで全テーブルのRLSが有効であること、Realtime画面で`feedbacks`がpublicationへ追加されていることを確認します。
8. `poco.xcodeproj`を開き、DebugまたはReleaseで起動します。

`Config/Secrets.xcconfig`は`.gitignore`対象です。値はSwiftファイルへ埋め込まれません。CIでは同じファイルをSecret Storeからビルド前に生成してください。

## Environment切り替え

- Preview / Mock: `POCO_BACKEND = mock`。ネットワーク不要です。
- Development / Production: `POCO_BACKEND = supabase`と有効なURL・Anon Keyが必要です。
- Supabase指定時に設定が欠けている場合、クラッシュを避けてMockへフォールバックし、設定エラーをStoreへ記録します。

Auth UI完成前にCreator作成を試す場合だけ、Dashboardで作ったAuth UserのUUIDを`POCO_DEVELOPMENT_USER_ID`へ指定し、`supabase/development/001_unsafe_anonymous_creator_policies.sql`を開発Projectへ手動適用できます。このSQLは匿名の作品・画像作成を許すため、本番Projectへ適用してはいけません。通常のMigrationには含まれません。確認後は`supabase/development/999_remove_unsafe_anonymous_creator_policies.sql`を実行し、追加したPolicyと権限を必ず削除してください。

## Database

Migrationは次の順で再構築できます。

- `001_initial_schema.sql`: `profiles`、`projects`、`feedbacks`、`feedback_likes`、件数View、プロフィール/Likeトリガー
- `002_rls.sql`: 本番用RLS Policy
- `003_storage.sql`: `project-images` BucketとStorage Policy
- `004_realtime.sql`: `feedbacks`のRealtime publication
- `005_memberships.sql`: Pocoメンバー資格、本人のみread可能なRLS、匿名ゲスト用プロフィール
- `006_registered_creators.sql`: Anonymous Authゲストの作品作成・画像更新を拒否

`feedback_count`は重複カラムにせず`projects_with_feedback_count` Viewで計算します。`likes_count`は`feedback_likes`のINSERT/DELETEトリガーだけで更新し、整合性を維持します。

## ゲスト・Pocoメンバー・広告

- ゲスト投稿者にはSupabase Anonymous Authを使用し、登録画面なしで端末固有のユーザーIDを付与します。これにより、ゲストもRLSを保ったまま1つのフキダシへ1回いいねできます。Supabase DashboardでAnonymous Sign-Insを有効にしてください。
- 閲覧・感想投稿・いいねはゲストでも利用できます。作品作成は登録ユーザーだけ、共感順・自分の作品/感想に届いたいいね集計・広告非表示はPocoメンバーだけが利用できます。`006_registered_creators.sql`はAnonymous Authユーザーによる作品作成と画像更新をDB側でも拒否します。
- いいね済み状態は`feedback_likes`から復元します。画面内の連打防止だけに依存せず、DBの`unique(feedback_id, user_id)`を最終的な保証にしています。
- `memberships`はアプリから更新できません。本番ではStoreKit 2の購入結果をApp Store Server Notificationsで検証し、service roleを持つEdge Functionなどからのみ更新します。
- Mock環境ではマイページまたは広告バーから登録・会員表示を試せます。Supabase環境ではStoreKit 2がApp Store Connectの商品情報を読み込み、購入・復元・端末上のTransaction検証を行います。
- `PocoAdBanner`は広告枠のUI境界です。広告はHome・Project Detail・Bubble Wallだけに配置し、投稿入力・落下・完了体験には表示しません。現在はプレースホルダーで、配信開始時にGoogle Mobile Ads等の実装へ内部だけを差し替えます。
- 共感順といいね集計はUI上で会員限定です。本番公開前には、共感順・会員集計を会員資格検証付きRPCへ移し、`likes_count`を直接ランキング用途で取得させないようにしてください。

## StoreKit 2セットアップ

1. App Store Connectで自動更新サブスクリプションを作成し、商品IDを`Config/Shared.xcconfig`の`POCO_MEMBERSHIP_PRODUCT_ID`へ設定します。現在の開発用IDは`com.fumiakiMogi777.poco.member.monthly`です。
2. 価格・ローカライズ・審査用情報をApp Store Connectへ設定します。表示価格は固定文字列ではなくStoreKitの`displayPrice`を使用します。
3. App Store Server Notifications V2の送信先をSupabase Edge Functionへ設定し、Appleの署名済みTransactionをサーバーで検証します。
4. 検証成功後だけservice role側から`memberships`を更新します。アプリの購入成功表示だけを会員資格の永続的な根拠にしないでください。
5. XcodeのStoreKit ConfigurationまたはSandbox Accountで新規購入・保留・取消・期限切れ・復元を確認します。
6. Appleの署名済みTransactionを検証するEdge Functionをデプロイした後、`POCO_MEMBERSHIP_SYNC_FUNCTION = sync-storekit-membership`を設定します。未設定時も端末検証済みの購入体験は止めず、サーバー同期を保留します。

## 広告配信セットアップ

`POCO_AD_PROVIDER`と`POCO_AD_UNIT_ID`は広告Adapter用の設定境界です。広告事業者を決めた後、SDKをSwift Package Managerで追加し、`PocoAdBanner`内部をProvider固有Viewへ差し替えてください。開発中は必ずテスト広告ユニットIDを使い、ATT同意・プライバシーマニフェスト・子ども向けコンテンツ設定・同意管理を審査前に確認します。広告認証情報が未設定の現在は、実広告を要求せずプレースホルダーを表示します。

匿名Feedbackは`sender_id = null`で投稿できます。匿名投稿は後から本人確認して更新・削除できないため、将来のAuth導入時には端末トークンまたはEdge Functionを使った所有権設計を追加してください。また、公開Anon投稿はBot対策、Rate Limit、内容モデレーションを本番公開前に追加する必要があります。

## Storage

作品画像は選択後、長辺1600px以内・JPEG品質0.8へ変換され、次のパスへ保存されます。

```text
project-images/projects/{creatorID}/{projectID}/{imageID}.jpg
```

DBにはBase64ではなく公開URLだけを保存します。アップロード上限は6MB、MIME typeは`image/jpeg`です。

## Sign in with Apple

アプリ側はAuthenticationServices、SHA-256 nonce、Supabase `AuthRepository`、ログアウト、初回氏名のプロフィール保存まで実装済みです。ゲストが登録する場合はApple Identityを現在の匿名ユーザーへリンクし、登録前の感想・いいね所有権を可能な限り維持します。

実際に接続するには以下の外部設定が必要です。

1. Apple DeveloperのApp ID `com.fumiakiMogi777.poco`でSign in with Apple Capabilityを有効化
2. Provisioning Profileを再生成
3. Supabase AuthでApple ProviderとAnonymous Sign-Insを有効化
4. Supabase AuthのManual Linkingを有効化（匿名ユーザー昇格に必要）
5. Supabase Apple ProviderのClient IDsへネイティブApp IDを登録
6. 初回Apple認証で取得した氏名が`profiles.display_name`へ保存されることを確認

Apple Identityが既存Pocoユーザーに紐づいている復帰ユーザーは既存アカウントへログインします。この場合、ログイン直前に新しい匿名IDで作ったデータを統合するには、次フェーズで所有権移行用Edge Functionが必要です。本番公開前には、アプリ内アカウント削除、Apple認証状態の失効確認、退会時の作品・感想データ保持方針も実装してください。

## 会員資格同期の残作業

アプリはStoreKit 2の`VerificationResult`から署名済みTransaction JWSを取り出し、設定されたSupabase Edge Functionへ送信できます。関数側ではApple公式App Store Server LibraryでJWS、Bundle ID、Environment、Product ID、有効期限、取消状態を検証し、service roleで`memberships`をupsertしてください。秘密鍵・Apple Root証明書・service role keyはiOSアプリやGitへ含めません。必要な契約は`supabase/functions/sync-storekit-membership/README.md`に記載しています。
