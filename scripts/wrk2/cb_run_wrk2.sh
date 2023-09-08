#!/usr/bin/env bash
#/*******************************************************************************
# Copyright (c) 2019 DigitalOcean

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

#     http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#/*******************************************************************************

cd ~
source $(echo $0 | sed -e "s/\(.*\/\)*.*/\1.\//g")/cb_common.sh

set_load_gen $@

cd ~

WRK2_DIR="~/wrk2"
eval WRK2_DIR=${WRK2_DIR}

CBUSERLOGIN=`get_my_ai_attribute login`
sudo chown -R ${CBUSERLOGIN}:${CBUSERLOGIN} ${WRK2_DIR}

LOAD_GENERATOR_TARGET_IP=`get_my_ai_attribute load_generator_target_ip`
CONNECTIONS=$(get_my_ai_attribute_with_default connections 400)
PROTOCOL=$(get_my_ai_attribute_with_default protocol http)
RESPONSESIZE=$(get_my_ai_attribute_with_default responsesize 0)
RESPONSEDELAY=$(get_my_ai_attribute_with_default responsedelay 0)
THREADS=$(get_my_ai_attribute_with_default threads auto)
LOAD_BALANCER=$(get_my_ai_attribute load_balancer)

if [ x"$THREADS" == x"auto" ] ; then
	NR_CPUS=`cat /proc/cpuinfo | grep processor | wc -l`
	syslog_netcat "Setting threads = ${NR_CPUS}"
	THREADS=${NR_CPUS}
fi

cd $WRK2_DIR

if [ "x${LOAD_BALANCER}" == "x\$False" ]; then
	if [ "x${PROTOCOL}" == "xhttps" ]; then
		if [ ! -e "./mydomain.key" ]; then
			# If using HTTPS without a loadbalancer then generate a cert if necessary.
		        sudo openssl genrsa -out mydomain.key 2048
		        sudo openssl req -new -key mydomain.key -out mydomain.csr -batch -verbose
			sudo openssl x509 -req -days 365 -in mydomain.csr -signkey mydomain.key -out mydomain.crt
		fi
	fi
fi


CMDLINE="./wrk -L -t${THREADS} -d${LOAD_DURATION} -c${CONNECTIONS} -R ${LOAD_LEVEL} -H 'sleep: ${RESPONSEDELAY}' -H 'size: ${RESPONSESIZE}' ${PROTOCOL}://${LOAD_GENERATOR_TARGET_IP}"

execute_load_generator "${CMDLINE}" ${RUN_OUTPUT_FILE} ${LOAD_DURATION}

cd ~
normalize_units() {
	local var
	var=$1

	unit=$(echo "${var}" | grep -oE "[a-z]+")
	val=$(echo "${var}" | sed -e "s/[a-z]\+//g")
	if [ x"${unit}" == xs ] ; then
		var=$(echo "${val}*1000" | bc -l)ms
	elif [ x"${unit}" == xm ] ; then
		var=$(echo "${val}*1000*60" | bc -l)ms
	fi
	echo -n "$var"
}

lat=$(cat ${RUN_OUTPUT_FILE} | grep Latency | awk '{ print $2 }')
lat_99=$(cat ${RUN_OUTPUT_FILE} | grep '99.000%' | awk '{print $2}')

# wrk2 likes to switch units on us from milliseconds to seconds. Let's keep it consistent.
lat=$(normalize_units "$lat")
lat_99=$(normalize_units "$lat_99")

tp=$(cat ${RUN_OUTPUT_FILE} | grep Req/Sec | awk '{ print $2 }')
tp_stddev=$(cat ${RUN_OUTPUT_FILE} | grep Req/Sec | awk '{ print $3 }')
tptotal=$(cat ${RUN_OUTPUT_FILE} | grep Requests/sec | awk '{ print $2 }')
connecterrors=$(cat ${RUN_OUTPUT_FILE} | grep "errors" | awk '{ print $4 }' | grep -oE "[0-9]+")
readerrors=$(cat ${RUN_OUTPUT_FILE} | grep "errors" | awk '{ print $6 }' | grep -oE "[0-9]+")
writeerrors=$(cat ${RUN_OUTPUT_FILE} | grep "errors" | awk '{ print $8 }' | grep -oE "[0-9]+")
timeouts=$(cat ${RUN_OUTPUT_FILE} | grep "errors" | awk '{ print $10 }' | grep -oE "[0-9]+")


~/cb_report_app_metrics.py \
$(format_for_report latency $lat) \
$(format_for_report 99_latency $lat_99) \
$(format_for_report throughput $tp) \
$(format_for_report throughput_stddev ${tp_stddev}) \
$(format_for_report throughput_total $tptotal) \
$(format_for_report connecterrors $connecterrors) \
$(format_for_report readerrors $readerrors) \
$(format_for_report writeerrors $writeerrors) \
$(format_for_report timeouts $timeouts) \
$(common_metrics)

unset_load_gen

exit 0
