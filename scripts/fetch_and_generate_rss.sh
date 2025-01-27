#!/bin/bash

# エラーハンドリングの強化
set -e  # エラーが出たらスクリプトを停止する
set -u  # 未定義の変数を使用した場合にエラーにする
set -o pipefail  # パイプ内でエラーが発生した場合もエラーとする

# 必要なディレクトリとファイルをクリーンアップ
rm -rf tweets gists.json rss.xml
mkdir -p tweets

echo "Fetching Gists from GitHub..."

# Gistを取得して保存
curl -s -H "Authorization: token $GIST_TOKEN" https://api.github.com/gists > gists.json

echo "Processing Gists and saving content to local files..."

# Gistのコンテンツを抽出して保存
jq -r '.[] | .id as $id | .files[] | .content as $content | [$id, $content] | @tsv' gists.json | while IFS=$'\t' read -r id content; do
  echo "$content" > tweets/tweet_$id.txt
done

echo "Generating RSS file..."

# RSSファイルのヘッダー部分を作成
cat << EOF > rss.xml
<rss version="2.0">
  <channel>
    <title>Twitter Feed</title>
    <link>https://yoshida0531a.github.io/private-rss-feed/</link>
    <description>Your custom Twitter feed</description>
EOF

# 各ツイートをRSSアイテムとして追加
for file in tweets/*.txt; do
  user=$(grep "User: " $file | sed 's/User: //')
  tweet=$(grep "Tweet: " $file | sed 's/Tweet: //')
  link=$(grep "Link: " $file | sed 's/Link: //')
  created=$(grep "Created: " $file | sed 's/Created: //')

  cat << ITEM >> rss.xml
    <item>
      <title>${user}: ${tweet}</title>
      <link>${link}</link>
      <pubDate>${created}</pubDate>
    </item>
ITEM
done

# RSSファイルのフッター部分を作成
cat << EOF >> rss.xml
  </channel>
</rss>
EOF

echo "Committing and pushing updates to the repository..."

# リポジトリに変更をコミットしてプッシュ
git config user.name "GitHub Actions"
git config user.email "actions@github.com"
git add tweets/ rss.xml
git commit -m "Moved Gists and updated RSS"
git push

echo "RSS feed generated and changes pushed successfully!"
