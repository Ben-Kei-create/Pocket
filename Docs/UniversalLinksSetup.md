# Poco Universal Links セットアップ

アプリ側は次のURLを同じProject Detailへ解決します。

- `poco://project/{UUID}`
- `https://{domain}/project/{UUID}`
- `https://{domain}/p/{UUID}`

ProjectはUUIDを保ったまま編集されるため、公開済みURLとQRコードは変わりません。

## 保留中TODO：公式Webサイトと独自ドメイン

現在は独自ドメインの取得とWebサイト公開を保留します。アプリは引き続き
`poco://`を開発用Fallbackとして使用し、ドメインが決まるまで正式配布用QRを
印刷しません。

再開時は、費用を抑えるため次の構成を第一候補とします。

- [ ] 公式Web用の別GitHub Repository（仮称`poco-web`）を作成する
- [ ] Cloudflare PagesのFree PlanへRepositoryを接続する
- [ ] 初年度価格だけでなく更新価格も比較し、安価な独自ドメインを取得する
- [ ] Cloudflareへ独自ドメインを接続し、HTTPSとDNSを確認する
- [ ] Poco紹介、App Store導線、利用規約、Privacy、問い合わせ、権利者向け削除申請を公開する
- [ ] `/project/{UUID}`と`/p/{UUID}`に、未インストール時のApp Store案内と再読込案内を用意する
- [ ] `/.well-known/apple-app-site-association`をリダイレクトなしで配信する
- [ ] `POCO_PUBLIC_BASE_URL`と`POCO_ASSOCIATED_DOMAIN`へ確定ドメインを設定する
- [ ] Apple DeveloperのAssociated DomainsとProvisioning Profileを更新する
- [ ] 実機でインストール済み／未インストールの両方を確認してから正式QRを発行する

Cloudflare Pagesはホスティング先であり、独自ドメインは別途Registrarで取得します。
ドメイン名・Registrar・実費は、公開作業の再開時点で空き状況と更新価格を確認して
最終決定します。

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
