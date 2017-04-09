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
            p_time=$(echo $elem | grep -o "\d\{2\}:\d\{2\}")
            wday=$j
            duration=$(echo $elem | grep -o "rowspan=\"\d\{2,3\}\"" | tr -d "rowspan=" | tr -d "\"")
            title=$(echo $elem | grep -o "<a[^>]*>[^<]*</a>\|<div class=\"title-p[^>]*>[^<]*</div>" | sed -e 's/<[^>]*>//g' | sed -e 's/\&amp;/\&/g')
            personality=$(echo $elem | grep -o "<div class=\"rp\">.*</div>" | sed -e 's/<[^>]*>//g' | tr -d "[ ->]")
            json="{\n"
            # TYPE
            json+="\t\"type\": "
            json+="\""
            if [ ! -z $(echo $elem | grep -o "bg-repeat") ]; then
                json+="r"
            elif [ ! -z $(echo $elem | grep -o "bg-f") ]; then
                json+="f"
            elif [ ! -z $(echo $elem | grep -o "bg-l") ]; then
                json+="l"
            else
                json+="o"
            fi
            json+="\",\n"
            # WDAY
            json+="\t\"wday\": $wday,\n"
            # TIME
            json+="\t\"time\": "
            json+="\""
            json+=$p_time
            json+="\",\n"
            # DURATION
            json+="\t\"duration\": "
            json+=$duration
            json+=",\n"
            # TITLE
            json+="\t\"title\": "
            json+="\""
            if [ "$title" = " 放送休止 " ]; then
                let ++cnt
            fi
            json+=$title
            json+="\",\n"
            # PERSONALITY
            json+="\t\"personality\": "
            json+="\""
            json+=$personality
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
sed -i '' '$s/,$//' $RESULT_JSON
echo "]" >> $RESULT_JSON
rm -rf ./tmp

exit 0