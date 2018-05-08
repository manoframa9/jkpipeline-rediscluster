#!/bin/bash                                                                                                                                                                                                                      
## preparation section    
while true; do
  pingres=$(timeout 2s redis-cli -h localhost ping) 
  echo "MY redis ping result is $pingres"                                                                                                                              
  if [ "$pingres" == "PONG" ]
  then
    echo ">>> redis-server already started"
    break
  fi
done
### determine deployment side                                                                                                                                                                                                    
if [ "$DEPLOYMENT_SIDE" == "" ]                                                                                                                                                                                                  
then                                                                                                                                                                                                                             
 SIDE=""                                                                                                                                                                                                                         
else                                                                                                                                                                                                                             
 SIDE="-$DEPLOYMENT_SIDE"                                                                                                                                                                                                        
fi                                                                                                                                                                                                                               
### list all ip of redis nodes                                                                                                                                                                                                   
echo -n > /usr/local/bin/nodelist.txt                                                                                                                                                                                            
for c in $(seq -f "%02g" 1 $NUMB_NODE)                                                                                                                                                                                           
do                                                                                                                                                                                                                               
echo $c                                                                                                                                                                                                                          
echo $(/usr/bin/getent hosts redis-cluster$SIDE-node$c | awk {' print $1 '}) >> /usr/local/bin/nodelist.txt                                                                                                                      
done                                                                                                                                                                                                                             
echo "----------------------------------------------"                                                                                                                                                                            
cat /usr/local/bin/nodelist.txt                                                                                                                                                                                                  
echo "----------------------------------------------"  
cat /confmap/deployer.txt
echo "----------------------------------------------"  
### get my node id                                                                                                                                                                                                               
MYID=$(hostname | awk '{print substr($0, match($0, "node")+4,2)}')                                                                                                                                                               
echo "MYID is $MYID"                                                                                                                                                                                                             
### get my ip                                                                                                                                                                                                                    
MYIP=$(/usr/bin/getent hosts redis-cluster$SIDE-node$MYID | awk {' print $1 '})                                                                                                                                                  
echo "MyIP is $MYIP"                                                                                                                                                                                                             
## check if the deployment is trigger from Jenkins, or not?                                                                                                                                                                      
if [ "$(cat /confmap/deployer.txt)" != "jenkins" ]                                                                                                                                                                               
then                                                                                                                                                                                                                             
## Loop to add node on each redis-node                                                                                                                                                                                           
  while read l; do                                                                                                                                                                                                               
    echo "try to add node with ip address of nodes type redis-cluster-node ; Try IP - $l"  
    if [ "$MYPI" == "$l" ]
    then
      continue
    fi      
    pingres=$(timeout 2s redis-cli -h $l ping) 
    echo "redis ping result is $pingres"                                                                                                                              
    if [ "$pingres" == "PONG" ]
    then
      echo "run command => timeout 20s /usr/local/bin/redsi-trib.rb add-node --slave $MYIP:6379 $l:6379"                                                                                                                           
      timeout 20s /usr/local/bin/redis-trib.rb add-node --slave $MYIP:6379 $l:6379                                                                                                                                                 
      if [ "$?" == "0" ]                                                                                                                                                                                                           
      then                                                                                                                                                                                                                         
        exit 0                                                                                                                                                                                                                     
      fi
    fi                                                                                                                                                                                                                           
  done </usr/local/bin/nodelist.txt                                                                                                                                                                                              
                                                                                                                                                                                                                                 
elif [ "$MYID" -lt "$NUMB_NODE" ]                                                                                                                                                                                                
then                                                                                                                                                                                                                             
  echo "The pod is started by Jenkins deployment. I am node$MYID which not the last node. Wait for node$NUMB_NODE to do cluster-init"                                                                                            
elif [ "$MYID" == "$NUMB_NODE" ]                                                                                                                                                                                                 
then                                                                                                                                                                                                                             
  echo "The pod is started by Jenkins deployment. I am node$MYID which is the last node. I am goint to do cluster-init"                                                                                                          
  cluster-init.sh & pid=$!                                                                                                                                                                                                       
  wait $pid
else
  echo "node id is out of range ; max node = $NUMB_NODE ; my node id = $MYID"
fi


