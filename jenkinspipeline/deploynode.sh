#!/bin/bash
## Tag of the docker image
GITLAB_TAG=$1
echo "GITLAB_TAG = $GITLAB_TAG"
## number of total nodes in the cluster
NUMB_NODE=$2
echo "NUMB_NODE = $NUMB_NODE"
## node id of calling the script this time
nodeinstsh=$3
echo "nodeinstsh = $nodeinstsh"
## ex: side => blue, green
side=$4
echo "Deployment side = $side"
## number of slave in each shard
numb_replicas=$5
echo "Number of replicas = $numb_replicas"
## ex: envi => DEV, SIT, NFT, UAT
envi=$6
echo "Environment = $envi"
## ex: zone => masternode, slavelevel1, slavelevel2
ZONE=$7
echo "Zone id = $ZONE"
######### prep svc file before replace
cp -f $envi-redis-cluster-$side-node00-svc.yaml $envi-redis-cluster-$side-node$nodeinstsh-temp-svc.yaml
sed -i "s/redis-cluster-$side-node00/redis-cluster-$side-node$nodeinstsh/g" $envi-redis-cluster-$side-node$nodeinstsh-temp-svc.yaml
sed -i "s/redis-$side-00/redis-$side-$nodeinstsh/g" $envi-redis-cluster-$side-node$nodeinstsh-temp-svc.yaml
oc replace -f $envi-redis-cluster-$side-node$nodeinstsh-temp-svc.yaml --force --cascade=true

######### prep dc file before replace
cp -f $envi-redis-cluster-$side-node00-dc.yaml $envi-redis-cluster-$side-node$nodeinstsh-temp-dc.yaml
sed -i "s/redis-cluster-$side-node00/redis-cluster-$side-node$nodeinstsh/g" $envi-redis-cluster-$side-node$nodeinstsh-temp-dc.yaml
sed -i "s/NUMB_NODE_VAL/${NUMB_NODE}/g" $envi-redis-cluster-$side-node$nodeinstsh-temp-dc.yaml
sed -i "s/DEPLOYMENT_SIDE_VAL/$side/g" $envi-redis-cluster-$side-node$nodeinstsh-temp-dc.yaml
sed -i "s/REPLICAS_VAL/${numb_replicas}/g" $envi-redis-cluster-$side-node$nodeinstsh-temp-dc.yaml
sed -i "s/GITTAG/${GITLAB_TAG}/g" $envi-redis-cluster-$side-node$nodeinstsh-temp-dc.yaml
sed -i "s/ZONENUMBER/${ZONE}/g" $envi-redis-cluster-$side-node$nodeinstsh-temp-dc.yaml
oc replace -f $envi-redis-cluster-$side-node$nodeinstsh-temp-dc.yaml --force --cascade=true
oc scale dc/redis-cluster-$side-node$nodeinstsh --replicas=1
oc rollout latest dc/redis-cluster-$side-node$nodeinstsh || true
oc rollout status dc/redis-cluster-$side-node$nodeinstsh -w