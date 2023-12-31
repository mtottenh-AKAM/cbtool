#!/usr/bin/env python
#/*******************************************************************************
# Copyright (c) 2012 IBM Corp.

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
'''
Mockup of what needs to happen for CloudNet use case
'''

#--------------------------------- START CB API --------------------------------

from sys import path, argv
from time import sleep

import fnmatch
import os
import pwd

home = os.environ["HOME"]
username = pwd.getpwuid(os.getuid())[0]

api_file_name = "/tmp/cb_api_" + username
if os.access(api_file_name, os.F_OK) :    
    try :
        _fd = open(api_file_name, 'r')
        _api_conn_info = _fd.read()
        _fd.close()
    except :
        _msg = "Unable to open file containing API connection information "
        _msg += "(" + api_file_name + ")."
        print(_msg)
        exit(4)
else :
    _msg = "Unable to locate file containing API connection information "
    _msg += "(" + api_file_name + ")."
    print(_msg)
    exit(4)

_path_set = False

for _path, _dirs, _files in os.walk(os.path.abspath(path[0] + "/../")):
    for _filename in fnmatch.filter(_files, "code_instrumentation.py") :
        if _path.count("/lib/auxiliary") :
            path.append(_path.replace("/lib/auxiliary",''))
            _path_set = True
            break
    if _path_set :
        break

from lib.api.api_service_client import *

_msg = "Connecting to API daemon (" + _api_conn_info + ")..."
print(_msg)
api = APIClient(_api_conn_info)

#---------------------------------- END CB API ---------------------------------

if len(argv) < 2 :
        print("./" + argv[0] + " <cloud_name>")
        exit(1)

cloud_name = argv[1]

start = int(time())
expid = "singlevm_" + makeTimestamp(start).replace(" ", "_")

print("starting experiment: " + expid)

try :
    vm = None
    error = False

    api.cldalter(cloud_name, "time", "experiment_id", expid)

    _tmp_vm = api.vminit(cloud_name, "tinyvm")
    uuid = _tmp_vm["uuid"]

    print("Started an VM with uuid = " + uuid) 

    vm = api.vmrun(cloud_name, _tmp_vm["uuid"])

    print("Resumed VM with uuid = " + vm["uuid"])

    print(str(vm))

except APIException as obj :
    error = True
    print("API Problem (" + str(obj.status) + "): " + obj.msg)
except KeyboardInterrupt :
    print("Aborting this experiment.")
except Exception as msg :
    error = True
    print("Problem during experiment: " + str(msg))

finally :
    try :
        if vm :
            print("Destroying VM..")
            api.vmdetach(cloud_name, vm["uuid"])
    except APIException as obj :
        print("Error cleaning up: (" + str(obj.status) + "): " + obj.msg)
