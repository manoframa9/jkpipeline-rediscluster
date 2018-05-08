#!/bin/bash
if [ "$DEPLOYMENT_SIDE" == "" ] 
then
 SIDE=""
else
 SIDE="-$DEPLOYMENT_SIDE"
fi

echo "deploy to side = $SIDE"

COMM="/usr/local/bin/redis-trib.rb create --replicas $REPLICAS "   
for c in $(seq -f "%02g" 1 $NUMB_NODE)                                                                                                                                                                            
do                                                                                                                                                                                                        
echo $c 
NODE_IP=$(/usr/bin/getent hosts redis-cluster$SIDE-node$c | awk {' print $1 '})
NODE=$NODE_IP":6379"
echo $NODE
COMM=$COMM" $NODE "
done

#sleep 90
echo $COMM
$COMM
echo RICARDO
exit 0
