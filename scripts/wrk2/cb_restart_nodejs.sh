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

START=`provision_application_start`
LOAD_PROFILE=$(get_my_ai_attribute load_profile)
LOAD_BALANCER=$(get_my_ai_attribute load_balancer)
PROTOCOL=$(get_my_ai_attribute_with_default protocol http)

linux_distribution

chmod +x $dir/backend.js

USE_HTTPS_NODEJS=0
NODEJS_PORT=80
if [ "x${LOAD_BALANCER}" == "x\$False" ]; then
	if [ "x${PROTOCOL}" == "xhttps" ]; then
		USE_HTTPS_NODEJS=1
		NODEJS_PORT=443
	fi
fi

is_nodejs_running=$(sudo ps aux | grep node | grep -v grep | grep "backend.js")
if [[ x"${is_nodejs_running}" == x ]]
then
	syslog_netcat "Starting Nodejs server on ${SHORT_HOSTNAME}"
	sudo screen -d -m -S NODEJSSERVER bash -c "$dir/backend.js" "${NODEJS_PORT}"
	wait_until_port_open 127.0.0.1 ${NODEJS_PORT} 20 5
fi


if [[ "x${USE_HTTPS_NODEJS}" == "x1" ]]; then
	wget -N -P /tmp https://${my_ip_addr}
else
# The backend will be non-ssl via haproxy SSL termination.
	wget -N -P /tmp http://${my_ip_addr}
fi
STATUS=$?

if [[ $STATUS -ne 0 ]]
then
    syslog_netcat "Nodejs server is not listening on ${SHORT_HOSTNAME} - NOK"
else
    syslog_netcat "Nodejs server is listening on ${SHORT_HOSTNAME} - OK"
fi

provision_application_stop $START
exit ${STATUS}
