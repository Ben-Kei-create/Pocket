# delete-account

登録ユーザー本人のJWTを検証し、次の順でアカウントを削除します。

1. `prepare_account_deletion`で公開データを非表示・匿名化
2. `project-images`と`profile-avatars`の本人所有画像を削除
3. Supabase Authユーザーをsoft delete

`SUPABASE_SECRET_KEY`または従来の`SUPABASE_SERVICE_ROLE_KEY`は
Supabase側のFunction Secretだけに設定し、iOSアプリやGitへ保存しません。

このFunctionはGatewayのlegacy JWT checkに依存せず、受け取ったBearer tokenを
`auth.getUser`で必ず再検証します。
