#!/bin/bash
  
docker run -d --runtime=nvidia --rm --name=nv-exportor \
    -v /run/prometheus:/run/prometheus nvidia/dcgm-exporter

docker run -d --rm --volumes-from nv-exportor:ro \
    -p 9100:9100 \
    quay.io/prometheus/node-exporter --collector.textfile.directory="/run/prometheus"

echo ""
echo "GPU Monitor is running ..."
echo ""