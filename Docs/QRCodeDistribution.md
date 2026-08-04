# Poco QR配布仕様

## 表示する2種類

| 初期選択 | 用途 | QRに含めるURL |
|---|---|---|
| はい | Pocoをインストール済み | `poco://project/{projectID}` |
| いいえ | Pocoを未インストール | `POCO_APP_STORE_URL` |

QR画面の切替ボタンで1枚の表示枠を切り替えます。保存、リンクコピー、共有は、
その時点で選択中のURLだけを使用します。

## 公開前の差し替え

App Store ConnectでPocoのApple IDが発行されたら、
`Config/Shared.xcconfig`の仮検索URLを正式な製品URLへ変更します。

```xcconfig
POCO_APP_STORE_URL = https:/$()/apps.apple.com/jp/app/poco/idXXXXXXXXXX
```

新しいURLは必ず`https`かつ`apps.apple.com`でなければなりません。不正な設定は
アプリ内で採用せず、App StoreのPoco検索URLへ安全にフォールバックします。

## 実機確認

1. PocoをインストールしたiPhoneでアプリ用QRを読み、対象作品が開く。
2. Pocoを未インストールのiPhoneでインストール用QRを読み、App Storeが開く。
3. QR切替後、保存画像、コピーURL、Share内容が表示中のQRと一致する。
4. 不正UUID、非公開作品、削除済み作品をアプリ側が拒否する。

GitHub Pages、AASA、Associated Domains、Universal Linksはこの導線では使用しません。
