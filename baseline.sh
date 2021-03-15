#! /bin/bash

DEVICE=$(findmnt -T . -o SOURCE  -n)
BASENAME=$(basename $DEVICE)
PARAMETERS=("max_sectors_kb" "read_ahead_kb" "nr_requests" "wbt_lat_usec" "queue_depth" "scheduler")

JQ_ARGS=()
JQ_QUERY='.'

for i in "${!PARAMETERS[@]}";
do
        KEY=${PARAMETERS[$i]}

        if [[ $KEY = queue_depth ]]; then SUBDIR=device; else SUBDIR=queue; fi
        VAL=$(cat /sys/block/$BASENAME/$SUBDIR/$KEY)
        JQ_ARGS+=( --arg "key$i" "$KEY" )
        JQ_ARGS+=( --arg "value$i" "$VAL" )
        JQ_QUERY+=" | .[\$key${i}]=\$value${i}"
done

jq -cM "${JQ_ARGS[@]}" "$JQ_QUERY" <<<'{}'
