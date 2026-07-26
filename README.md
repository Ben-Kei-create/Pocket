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

`feedback_count`は重複カラムにせず`projects_with_feedback_count` Viewで計算します。`likes_count`は`feedback_likes`のINSERT/DELETEトリガーだけで更新し、整合性を維持します。

匿名Feedbackは`sender_id = null`で投稿できます。匿名投稿は後から本人確認して更新・削除できないため、将来のAuth導入時には端末トークンまたはEdge Functionを使った所有権設計を追加してください。また、公開Anon投稿はBot対策、Rate Limit、内容モデレーションを本番公開前に追加する必要があります。

## Storage

作品画像は選択後、長辺1600px以内・JPEG品質0.8へ変換され、次のパスへ保存されます。

```text
project-images/projects/{creatorID}/{projectID}/{imageID}.jpg
```

DBにはBase64ではなく公開URLだけを保存します。アップロード上限は6MB、MIME typeは`image/jpeg`です。

## Authの次フェーズ

現在は`CurrentUserProvider`が境界です。Sign in with Apple導入時は以下が必要です。

1. Apple DeveloperでSign in with Apple CapabilityとService IDを設定
2. Supabase AuthでApple Provider、Client ID、Secret、Redirect URLを設定
3. `ASAuthorizationAppleIDProvider`のnonceをSupabase Authへ渡す
4. Auth Sessionを`CurrentUserProvider`へ接続
5. `profiles`作成トリガーと表示名更新を確認
6. 開発専用匿名Creator Policyを削除し、本番RLSだけを使用
7. Account削除、Token更新、ログアウト、Deep Link callbackを実装
