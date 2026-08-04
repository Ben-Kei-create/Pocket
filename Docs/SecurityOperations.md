# Poco Security Operations

最終更新: 2026-07-29

この文書は、iOSアプリとSQL Migrationだけでは完結しない本番セキュリティ運用のチェックリストです。`Anon Key`は公開される前提とし、RLS、RPC、レート制限、監視を多層に重ねます。

## 公開をブロックする必須項目

- Supabase AuthでAnonymous Sign-In用のCAPTCHA（Cloudflare Turnstile等）を有効化する。匿名UUIDの作り直しによる投稿上限回避を、DBのUUID制約だけに任せない。
- AuthのIPレート制限を本番値へ設定する。急増時は、引き上げる前にBot比率と失敗率を確認する。
- Feedback、Like、Report、権利申請、コイン付与をEdge Functionの共通ゲートウェイへ移し、Apple App AttestのAssertion、JWT、タイムスタンプ、一回限りnonceを検証する。改造クライアントのRPC直叩きを前提にする。
- StoreKit Transaction JWSとApp Store Server Notifications V2をサーバー検証し、端末の自己申告で`memberships`を更新しない。
- 画像は非公開の検疫Bucketへ先にUploadし、サーバーでJPEG再decode、寸法／容量確認、NSFW検査を通過したものだけを公開Bucketへ移す。Sensitive Content Analysisは端末上の一次警告であり、最終決定に使わない。
- アカウント削除、Apple連携解除、保持対象と監査証拠の匿名化・パージを自動化する。

## 大量トラフィックとDoS

- Home、作者一覧、Feedback、活動履歴はカーソルページングに移行する。Migration `023`の200／500件上限は緊急ブレーキであり、最終的な無限スクロール実装ではない。
- Realtimeは常に`project_id`等の最小フィルタを付ける。画面離脱時に購読Taskをcancelし、同一画面の重複購読を許さない。
- Storage Bucketのファイル上限とMIME制約をDashboardで確認する。パスは`cover.jpg`と`avatar.jpg`の1枚に固定し、孤立ファイルが増えないようにする。
- PostgresのCPU、DB容量、Connection数、p95 RPC時間、5xx、42501、レート制限発火数、Realtime接続数をアラート対象にする。

## UGCと悪質利用者

- 通報した原文は`feedback_report_evidence`に不変Snapshotとして保持する。作者または投稿者が本文を削除しても、運営の審査証拠を失わない。
- ブロックはUIの非表示だけでなく、Feedback取得、投稿、LikeをDBでも拒否する。
- 同一犯人が複数の匿名Auth IDを作るSybil攻撃はUUID単位制限では止められない。CAPTCHA、App Attest、IP／デバイス風評、運営凍結を組み合わせる。
- 通報は「量が多いから自動削除」にせず、運営審査キューへ入れる。誤通報の組織化に対して、同一アカウント／IP／端末の異常集中を確認する。
- スパム、個人情報、性的／暴力的内容、著作権は理由別にSLAとエスカレーションを決める。緊性の個人情報は即時非公開を可能にする。

## データ保全と復旧

- 有料PlanのDaily BackupまたはPITRを有効化し、四半期に1回以上、別Projectへの復元リハーサルを行う。
- Database BackupにStorageの実ファイルが含まれない前提で、Storageは別のエクスポート／複製ジョブを持つ。
- 削除作品の30日保持、通報保留、権利者申請保留、監査ログ保持のジョブを`pg_cron`または管理下のSchedulerで定期実行する。
- 暗号鍵とService Role KeyはSupabase Secrets／CI Secret Storeに置き、年次および漏洩疑い時にローテーションする。ローテーション手順を事前にリハーサルする。

## インシデント時の初動

1. 影響を受けるRPC、Realtime、Storage Uploadを最小範囲で停止する。
2. 監査ログ、Edge Function Log、Auth Logを削除せず、発生時刻と対応者を記録する。
3. 漏洩対象を特定し、必要な鍵をローテーションする。影響範囲不明のまま全データを削除しない。
4. 修復後に再発テストと復元テストを行い、影響を受けたユーザーへの通知・当局報告要否を確認する。
