#!/usr/bin/env bash
# Telegram Bot APIへの疎通確認・送信フォーマット検証用スクリプト。
# Xcodeなしでも、Swift実装(TelegramClient.swift)と同じリクエスト形状を先に検証できるようにするためのもの。
#
# 使い方:
#   export TELEGRAM_BOT_TOKEN="123456789:AA..."
#   ./telegram_api_check.sh chat_id            # getUpdatesからchat_idを調べる
#   ./telegram_api_check.sh send_document <chat_id> <file>   # documentとして送信(写真の原本保持を検証)
#   ./telegram_api_check.sh send_video <chat_id> <file>      # videoとして送信

set -euo pipefail

if [[ -z "${TELEGRAM_BOT_TOKEN:-}" ]]; then
  echo "環境変数 TELEGRAM_BOT_TOKEN を設定してください" >&2
  exit 1
fi

API="https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}"
CMD="${1:-}"

case "$CMD" in
  chat_id)
    curl -s "${API}/getUpdates" | python3 -m json.tool
    ;;
  send_document)
    CHAT_ID="${2:?chat_idを指定してください}"
    FILE="${3:?ファイルパスを指定してください}"
    curl -s -X POST "${API}/sendDocument" \
      -F "chat_id=${CHAT_ID}" \
      -F "document=@${FILE}" \
      -F "caption=telegram_api_check.sh からのdocument送信テスト" \
      | python3 -m json.tool
    ;;
  send_video)
    CHAT_ID="${2:?chat_idを指定してください}"
    FILE="${3:?ファイルパスを指定してください}"
    curl -s -X POST "${API}/sendVideo" \
      -F "chat_id=${CHAT_ID}" \
      -F "video=@${FILE}" \
      -F "caption=telegram_api_check.sh からのvideo送信テスト" \
      | python3 -m json.tool
    ;;
  *)
    echo "使い方: $0 {chat_id|send_document|send_video} [chat_id] [file]" >&2
    exit 1
    ;;
esac
