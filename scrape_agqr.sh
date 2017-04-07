#!/bin/sh

NAME="scrape_agqr"
AGQR_URL="http://www.agqr.jp/timetable/streaming.html"
CURL="/usr/bin/curl"
XMLLINT="/usr/bin/xmllint"
XMLLINT_OPT="--html"
RAW_HTML="./tmp/streaming.html"
MOD_HTML="./tmp/streaming_mod.html"
RESULT_JSON="schedule.json"

## init
if [ -e ./tmp ]; then
    rm -rf ./tmp
    mkdir tmp
else
    mkdir tmp
fi
if [ -e result.txt ]; then
    rm -f result.txt
fi

$CURL -L $AGQR_URL > $RAW_HTML 2> /dev/null
echo "<!DOCTYPE html><html lang="ja"><head><meta charset="UTF-8"></head>" > $MOD_HTML
$XMLLINT $XMLLINT_OPT --xpath "/html/body/div[2]/div/table" $RAW_HTML >> $MOD_HTML 2> /dev/null
echo "</html>" >> $MOD_HTML
echo "[" > $RESULT_JSON
cnt=0
for i in {1..1500}; do
    for j in {1..7}; do
        elem=$($XMLLINT $XMLLINT_OPT --xpath "/html/body/table/tbody/tr[$i]/td[$j]" $MOD_HTML 2> /dev/null)
        if [ ! -z "$elem" ]; then
            json="{\n\t\"day\": $j,\n"
            # TIME
            json+="\t\"time\": "
            json+="\""
            json+=$(echo $elem | grep -o "[0-9][0-9]:[0-9][0-9]")
            json+="\",\n"
            # DURATION
            json+="\t\"duration\": "
            json+=$(echo $elem | grep -o "rowspan=\"[0-9][0-9][0-9]*\"" | tr -d "rowspan=" | tr -d "\"")
            json+=",\n"
            # TITLE
            json+="\t\"title\": "
            json+="\""
            title=$(echo $elem | grep -o "<a[^>]*>[^<]*</a>\|<div class=\"title-p[^>]*>[^<]*</div>" | sed -e 's/<[^>]*>//g' | sed -e 's/\&amp;/\&/g')
            if [ "$title" = " 放送休止 " ]; then
                let ++cnt
            fi
            json+=$title
            json+="\",\n"
            # PERSONALITY
            json+="\t\"personality\": "
            json+="\""
            json+=$(echo $elem | grep -o "<div class=\"rp\">.*</div>" | sed -e 's/<[^>]*>//g' | tr -d "[ ->]")
            json+="\"\n"
            json+="},"
            echo $json >> $RESULT_JSON
            if [ $cnt = 7 ]; then
                break 2
            fi
        else
            break 1
        fi
    done
done
sed -i -e '$s/,$//' $RESULT_JSON
echo "]" >> $RESULT_JSON

exit 0