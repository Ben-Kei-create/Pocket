# Poco Universal Links セットアップ

アプリ側は次のURLを同じProject Detailへ解決します。

- `poco://project/{UUID}`
- `https://{domain}/project/{UUID}`
- `https://{domain}/p/{UUID}`

ProjectはUUIDを保ったまま編集されるため、公開済みURLとQRコードは変わりません。

## 実ドメイン決定後に行うこと

1. `Config/Secrets.xcconfig`へ次を設定します。xcconfig内の`//`対策として
   `https:/$()/`表記を維持してください。

   ```xcconfig
   POCO_PUBLIC_BASE_URL = https:/$()/YOUR_DOMAIN
   POCO_ASSOCIATED_DOMAIN = YOUR_DOMAIN
   ```

2. `Web/.well-known/apple-app-site-association`を、拡張子なし・
   `application/json`で次の場所へ配置します。

   ```text
   https://YOUR_DOMAIN/.well-known/apple-app-site-association
   ```

3. HTTPSの有効な証明書を使い、上記URLがリダイレクトなしで`200`を返すことを
   確認します。`www`など別サブドメインも使う場合は、そのサブドメインを
   Entitlementへ追加し、同じAASAをそのホストからも配信します。

4. Apple DeveloperのApp ID
   `com.fumiakiMogi777.poco`でAssociated Domains Capabilityを有効化し、
   Provisioning Profileを再生成します。

5. 未インストール時に表示するWebページとして、少なくとも
   `/project/{UUID}`と`/p/{UUID}`を用意します。ページにはApp Store導線と、
   インストール後にQRを再読取できる案内を置きます。

## 実機確認

Universal Linksの関連付けはインストール時に確認されるため、設定変更後は
アプリを実機から削除して再インストールします。メッセージやメールなど、
アプリ外からHTTPSリンクをタップし、対象Project Detailが直接開くことを確認します。

次も確認します。

- 不正なUUIDや別ホストをアプリが拒否する
- 削除済み・非公開Projectが開かない
- 未インストール端末では同じURLのWebページが開く
- QRコードがHTTPS URLを含む
- `poco://`が開発用Fallbackとして引き続き動作する

実ドメインが未設定のビルドでは、Reserved TLDの
`universal-links-not-configured.invalid`がEntitlementへ入りますが、共有URLは
`POCO_PUBLIC_BASE_URL`が空のため既存の`poco://`を使用します。
