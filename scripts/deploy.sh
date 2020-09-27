#!/bin/bash

host="$1"
if [ "$host" == "" ]; then
    read -p "please enter the host address: " h
    if [ "$h" != "" ]; then
        host="$h"
    fi
fi

if [ "$host" == "" ]; then
    echo "invalid host"
    exit
fi

loginUser="root"
read -p "please enter the host ssh user (default is 'root'): " user
if [ "$user" != "" ]; then
    loginUser="$user"
fi

hostSSHPort="22"
read -p "please enter the host ssh port (default is 22): " port
if [ "$port" != "" ]; then
    hostSSHPort="$port"
fi

init="no"
read -p "initiate service ('yes' or 'no', default is 'no')? " ok
if [ "$ok" == "yes" ]; then
    init="yes"
fi

port="80"
httpsPort="443"
etcDir="/etc/esmd"
cdnDomain=""
if [ "$init" == "yes" ]; then
    read -p "please enter the server http port (default is ${port}): " p
    if [ "$p" != "" ]; then
        port="$p"
    fi
    read -p "please enter the server https port (default is ${httpsPort}): " p
    if [ "$p" != "" ]; then
        httpsPort="$p"
    fi
    read -p "please enter the etc directory, user ${loginUser} must have r/w permission of it (default is ${etcDir}): " p
    if [ "$p" != "" ]; then
        etcDir="$p"
    fi
    read -p "please enter the cdn domain (optional): " p
    if [ "$p" != "" ]; then
        cdnDomain="$p"
    fi
fi

sh $(dirname $0)/build.sh
if [ "$?" != "0" ]; then
    exit
fi

echo "--- uploading..."
scp -P $hostSSHPort esmd $loginUser@$host:/tmp/esmd
if [ "$?" != "0" ]; then
    rm -f esmd
    exit
fi

echo "--- installing..."
ssh -p $hostSSHPort $loginUser@$host << EOF
    SV=\$(supervisorctl version)
    if [ "\$?" != "0" ]; then
        echo "error: missing supervisor!"
        exit
    fi
    echo "supervisor \$SV"

    writeSVConfLine () {
        echo "\$1" >> /etc/supervisor/conf.d/esmd.conf
    }

    supervisorctl stop esmd
    rm -f /usr/local/bin/esmd
    mv -f /tmp/esmd /usr/local/bin/esmd
    chmod +x /usr/local/bin/esmd

    if [ "$init" == "yes" ]; then
        mkdir ${etcDir}
        rm -f /etc/supervisor/conf.d/esmd.conf
        writeSVConfLine "[program:esmd]"
        writeSVConfLine "command=/usr/local/bin/esmd --port=${port} --https-port=${httpsPort} --etc-dir=${etcDir} --cdn-domain=${cdnDomain}"
        writeSVConfLine "directory=/tmp"
        writeSVConfLine "user=$loginUser"
        writeSVConfLine "autostart=true"
        writeSVConfLine "autorestart=true"
        supervisorctl reload
    else
        supervisorctl start esmd
    fi
EOF

rm -f server/readme_md.go
rm -f esmd
