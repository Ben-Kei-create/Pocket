# アーカイブ: Poco Universal Links セットアップ

> 2026-08-03の仕様変更により、この方式は現在使用しません。作品画面では
> `poco://project/{UUID}`のアプリ用QRと、App Store製品URLのインストール用QRを
> 切り替えて表示します。GitHub Pages、AASA、Associated Domainsの設定は不要です。
> 以下は将来Universal Linksを再検討する場合の参考資料として残しています。

この資料が作成された当時は、次のURLを同じProject Detailへ解決する構想でした。
現在のアプリはHTTPS形式を受け付けず、`poco://`だけを解決します。

- `poco://project/{UUID}`
- `https://{domain}/project/{UUID}`
- `https://{domain}/p/{UUID}`

ProjectはUUIDを保ったまま編集されるため、公開済みURLとQRコードは変わりません。

## 暫定公開先：GitHub Pages

暫定の作品URLは次に統一します。

```text
https://ben-kei-create.github.io/project/{projectID}
```

当時はアプリ側へ`POCO_PUBLIC_BASE_URL`と`POCO_ASSOCIATED_DOMAIN`を設定する想定でした。
現在これらの設定は削除済みです。
Web側は別リポジトリ`Ben-Kei-create.github.io`をGitHub Pagesとして公開し、
このリポジトリの`Web/`にあるAASAを配置します。

公開までのTODOです。

- [ ] `Ben-Kei-create.github.io`リポジトリを作成する
- [ ] GitHub Pagesを有効化し、HTTPSを強制する
- [ ] Poco紹介、App Store導線、利用規約、Privacy、問い合わせ、権利者向け削除申請を公開する
- [ ] `/project/{UUID}`と`/p/{UUID}`に、未インストール時のApp Store案内と再読込案内を用意する
- [ ] `/.well-known/apple-app-site-association`をリダイレクトなしで配信する
- [ ] Apple DeveloperのAssociated DomainsとProvisioning Profileを更新する
- [ ] 実機でインストール済み／未インストールの両方を確認してから正式QRを発行する

独自ドメインは反響後に追加します。その際は新旧両方をアプリの
Associated DomainsとAASAに残し、配布済みGitHub Pages QRを壊しません。

## GitHub Pages公開時に行うこと

1. `Config/Secrets.xcconfig`へ次を設定します。xcconfig内の`//`対策として
   `https:/$()/`表記を維持してください。

   ```xcconfig
   POCO_PUBLIC_BASE_URL = https:/$()/ben-kei-create.github.io
   POCO_ASSOCIATED_DOMAIN = ben-kei-create.github.io
   ```

2. `Web/.well-known/apple-app-site-association`を、拡張子なし・
   `application/json`で次の場所へ配置します。

   ```text
   https://ben-kei-create.github.io/.well-known/apple-app-site-association
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

GitHub Pages公開前でもアプリはHTTPSの共有URLを生成しますが、Web側は
404になりUniversal Links検証も完了しません。正式QRの印刷はPages公開と
実機確認の後に行います。`poco://`は開発用Fallbackとして引き続き解析できます。
