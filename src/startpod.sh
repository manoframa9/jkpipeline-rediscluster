echo "start nohup redis node initialize script"   
nohup /usr/local/bin/redisnode-init.sh      &
echo "Start redis server"
redis-server /usr/local/etc/redis.conf