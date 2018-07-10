nodes_addrs=$(redis-cli cluster nodes|grep -v handshake| awk '{print $2}')
for addr in ${nodes_addrs[@]}
do
host=${addr%:*}
port=$( echo ${addr##*:} | awk -F'@' '{print $1}')
echo  host is $host ----    $port
del_nodeids=$(redis-cli -h $host -p $port cluster nodes|grep -E 'handshake|fail'| awk '{print $1}')
for nodeid in ${del_nodeids[@]}
do
echo $host $port $nodeid
redis-cli -h $host -p $port cluster forget $nodeid
done
done
