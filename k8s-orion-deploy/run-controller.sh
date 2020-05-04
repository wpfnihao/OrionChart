#!/bin/bash
  
cd `dirname $0`
SELF_PATH=$(pwd)

sche_with_quota_limite=0
listen_port=15500
let port1=listen_port+1
let port2=listen_port+2

persistent_volume="/home/chenfei/00-poc/xunfei/controller/etcd"
#mkdir -p $persistent_volume

#       -v ${persistent_volume}:/root/etcd \
docker run -d --rm --name orion-controller-test  \
    -e ORION_PORT=${listen_port}  \
    -e EXT_DB="127.0.0.1:9020"  \
    -e TOKEN="" \
    -e ADMIN_PASSWD="admin" \
        -e ENALBE_QUOTA=$sche_with_quota_limite \
        -p ${listen_port}:${listen_port} \
        -p ${port1}:${port1} -p ${port2}:${port2} \
        -v /etc/localtime:/etc/localtime:ro \
    orion-controller:2.1

#docker run -d --rm --name prometheus00 \
#       --net container:orion-controller-xunfei00 \
#       -v ${SELF_PATH}/prometheus.yml:/etc/prometheus/prometheus.yml \
#       prom/prometheus

if [ $sche_with_quota_limite == 1 ]; then
        with_without="with"
else
        with_without="without"
fi

echo ""
echo "================================================================="
echo "Orion Controller is launched $with_without resource quota limite."
echo "Orion Controller provides scheduling at port $listen_port"
echo "Orion Controller provides web GUI at port $port2"
echo "================================================================="
echo ""