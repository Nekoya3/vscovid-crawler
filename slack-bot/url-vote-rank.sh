#!/bin/bash

#
# Setup:
#   Set .env properly
#

#
# Usage:
#   cd {REPOS_ROOT}
#   ./slack-bot/url-vote-rank.sh
#

set -e

source .env

# 依存lib
. ./lib/slack-helper.sh


# ユーザー毎の投票数を集計 -> tmp/rank.txt
declare -A users

keys=`redis-cli KEYS "vscovid-crawler-vote:count-*"`
for key in $keys; do
    count=`redis-cli GET $key`
    user=`echo $key| cut -d'-' -f 4`
    users[${user}]=$count
done

for k in "${!users[@]}"; do
    echo $k,${users["$k"]}
done | sort -t , -rn -k2 | head -n 20 > tmp/rank.txt


# tmp/rank.txt を元にポスト用ランキング文字列を構築 -> $rank
rank=""
for line in `cat tmp/rank.txt`; do
    user_id=`echo $line | cut -d',' -f 1`
    count=`echo $line | cut -d',' -f 2`
    rank=$rank"\r\n<@$user_id> さん、 $count 回"
done
echo $rank


# ポスト先チャンネル識別子
channels_id=`get_channels_id`
echo $channels_id


# API へ送る用の JSON 構築
json=`cat <<EOF
{
    "channel": "${channels_id}",
    "text": "回答者ランキング",
    "blocks": [
        {
            "type": "section",
            "text": {
                "type": "mrkdwn",
                "text": "現在の回答者ランキングです！"
            }
        },
        {
            "type": "section",
            "text": {
                "type": "mrkdwn",
                "text": "${rank}"
            }
        }
    ]
}
EOF
`


# API ポスト実行
echo "$json"
wget -q -O - --post-data "$json" \
    --header="Content-type: application/json" \
    --header="Authorization: Bearer ${slack_token}" \
    https://slack.com/api/chat.postMessage | jq .
echo ""
