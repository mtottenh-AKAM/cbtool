#!/usr/bin/env bash

cd ~
source $(echo $0 | sed -e "s/\(.*\/\)*.*/\1.\//g")/cb_common.sh

set_load_gen $@

cd ~

CBUSERLOGIN=`get_my_ai_attribute login`
LOAD_GENERATOR_TARGET_IP=`get_my_ai_attribute load_generator_target_ip`
RATIO=$(get_my_ai_attribute_with_default ratio 5:10)
PIPELINE=$(get_my_ai_attribute_with_default pipeline 1)
CLIENTS_PER_THREAD=$(get_my_ai_attribute_with_default clients_per_thread 10)
DATA_SIZE_PATTERN=$(get_my_ai_attribute data_size_pattern)
DATA_OFFSET=$(get_my_ai_attribute data_offset)
DATA_SIZE_RANGE=$(get_my_ai_attribute data_size_range)
KEY_MINIMUM=$(get_my_ai_attribute key_minimum)
KEY_MAXIMUM=$(get_my_ai_attribute key_maximum)
KEY_PATTERN=$(get_my_ai_attribute key_pattern)
KEY_STDDEV=$(get_my_ai_attribute key_stddev)
KEY_MEDIAN=$(get_my_ai_attribute key_median)
USE_RANDOM_DATA=$(get_my_ai_attribute_with_default use_random_data true)

declare -a ARGS=()
[ $USE_RANDOM_DATA = true ] && ARGS+=('--random-data')
[ ! -z "$DATA_SIZE_PATTERN" ] && ARGS+=("--data-size-pattern=${DATA_SIZE_PATTERN}")
[ ! -z "$DATA_OFFSET" ] && ARGS+=("--data-offset=${DATA_OFFSET}")
[ ! -z "$DATA_SIZE_RANGE" ] && ARGS+=("--data-size-range=${DATA_SIZE_RANGE}")
[ ! -z "$KEY_MINIMUM" ] && ARGS+=("--key-minimum=${KEY_MINIMUM}")
[ ! -z "$KEY_MAXIMUM" ] && ARGS+=("--key-maximum=${KEY_MAXIMUM}")
[ ! -z "$KEY_PATTERN" ] && ARGS+=("--key-pattern=${KEY_PATTERN}")
[ ! -z "$KEY_STDDEV" ]  && ARGS+=("--key-stddev=${KEY_STDDEV}")
[ ! -z "$KEY_MEDIAN" ]  && ARGS+=("--key-median=${KEY_MEDIAN}")


CMDLINE="memtier_benchmark ${ARGS[@]} -s ${LOAD_GENERATOR_TARGET_IP} -c ${CLIENTS_PER_THREAD} -t ${LOAD_LEVEL} --ratio ${RATIO} --pipeline ${PIPELINE} --test-time ${LOAD_DURATION} --hide-histogram"



execute_load_generator "${CMDLINE}" ${RUN_OUTPUT_FILE} ${LOAD_DURATION}

lat=$(cat ${RUN_OUTPUT_FILE} | grep Totals | awk '{ print $5 }')
lat_99=$(cat ${RUN_OUTPUT_FILE} | grep Totals | awk '{print $7}')
tp=$(cat ${RUN_OUTPUT_FILE} | grep Totals | awk '{ print $2 }')
bw=$(cat ${RUN_OUTPUT_FILE} | grep Totals | awk '{ print $6 }')

~/cb_report_app_metrics.py \
throughput:$tp:tps \
latency:$lat:msec \
99_latency:$lat_99:mesc \
bandwidth:$tp:KBps \
$(common_metrics)

unset_load_gen

exit 0
