#!/bin/zsh


echo '##### Creating Benchmarking db #####'

sudo -u postgres createdb unbench_the_kench  >/dev/null 2>&1

echo ' '
echo '##### Filling table with junk #####'
sudo -u postgres pgbench -i  -s 10 -p 5432 -d unbench_the_kench




echo '###### Running benchmark against default tuning  #######'
for i in {1..15}
do
sudo -u postgres pgbench unbench_the_kench -c 100 -T 3 -S -n >> result1.txt 
done
grep -i processed result1.txt | awk '{printf "%s\n", $6}' > result_nums.txt

count=0;
sum=0; 

for i in $( awk '{printf "%s\n", $1}' result_nums.txt )
   do 
     sum=$(echo $sum+$i | bc )
     ((count++))
   done
   default_tuning=$(echo 'Average number of transactions processed from 10 iterations ' && echo "scale=2; $sum / $count" | bc)

echo ' '
echo '##### Clean Up #####'
rm result1.txt result_nums.txt

sudo -u postgres dropdb unbench_the_kench >/dev/null 2>&1

#Define settings

total=$(grep MemTotal /proc/meminfo | awk '{print $2}')
shared_buffers=$(echo $total '/ 4' | bc) 
work_mem=$(echo $total '/ 2 / (200 * 5)' | bc)
maintanence_work_mem=$(echo $shared_buffers '/ 3' | bc)
checkpoint_completion_target='0.9'
checkpoint_timeout='20min'
autovacuum_freeze_max_age='100000000'
autovacuum_multixact_freeze_max_age='100000000'
vacuum_cost_limit='600'

#Work out hdd or ssd
hdd_or_ssd=$(cat /sys/block/sda/queue/rotational)
if (($hdd_or_ssd  == 1))
then 
	random_page_cost='3'
else
	random_page_cost='2'
	fi
effective_cache=$(echo  $total ' * 0.80 ' | bc)
effective_cache_size=$(printf "%.0f\n" "$effective_cache")
effective_io_concurrency=2

##Setting up the config file

touch /var/lib/pgsql/11/data/magic_tuner.conf
cat >/var/lib/pgsql/11/data/magic_tuner.conf <<EOL
######################################
##### Ned's magic tuner settings #####
######################################
default_statistics_target = 100
max_connections = 200
shared_buffers=${shared_buffers}kB
work_mem=${work_mem}kB
maintenance_work_mem=${maintanence_work_mem}kB
checkpoint_completion_target=$checkpoint_completion_target
checkpoint_timeout=$checkpoint_timeout
#autovacuum_freeze_max_age=$autovacuum_freeze_age
#autovacuum_multixact_freeze_max_age=$autovacuum_multixact_freeze_max_age
vacuum_cost_limit=$vacuum_cost_limit
random_page_cost=$random_page_cost
effective_cache_size=${effective_cache_size}kB 
effective_io_concurrency=$effective_io_concurrency
max_worker_processes = 4
max_parallel_workers_per_gather = 2
max_parallel_workers = 4
EOL

echo '##### Applying new settings #####'
echo ' '
cat /var/lib/pgsql/11/data/magic_tuner.conf
echo '##### Including config file in postgresql #####'


echo  "include = 'magic_tuner.conf'" >> /var/lib/pgsql/11/data/postgresql.conf

echo ' '
echo '###### Restarting postgres with new settings #####'
echo ' '
systemctl restart postgresql-11.service
echo '##### Running benchmark against magic tuner  #####'
echo ' '
echo '##### Creating Database #####'
echo ' '
sudo -u postgres createdb  unbench_the_kench >/dev/null 2>&1
echo '##### Filling Database with junk ######'
echo ' '
sudo -u postgres pgbench -i -s 10  -p 5432 -d unbench_the_kench 
for i in {1..15}
do
sudo -u postgres pgbench unbench_the_kench  -c 100 -T 3 -S -n > result2.txt
done

grep -i processed result2.txt | awk '{printf "%s\n", $6}' > result_nums2.txt

count2=0;
sum2=0; 

for i in $( awk '{ printf "%s\n", $1 }' result_nums2.txt )
   do 
     sum2=$(echo $sum2+$i | bc )
     ((count2++))
   done
   neds_tuning=$(echo 'Average number of transactions processed from 10 iterations '&& echo "scale=2; $sum2 / $count2" | bc)

echo '##### Cleaning up #####'
echo ' '

rm result2.txt result_nums2.txt

rm /var/lib/pgsql/11/data/magic_tuner.conf
sed -i '$d' /var/lib/pgsql/11/data/postgresql.conf

sudo -u postgres dropdb unbench_the_kench >/dev/null 2>&1

touch /var/lib/pgsql/11/data/pg_tune.conf                           
cat >/var/lib/pgsql/11/data/pg_tune.conf <<EOL                      
##### Pg Tuner settings######

# DB Version: 11
# OS Type: linux
# DB Type: web
# Total Memory (RAM): 4 GB
# CPUs num: 4
# Connections num: 100
# Data Storage: hdd

max_connections = 100
shared_buffers = 1GB
effective_cache_size = 3GB
maintenance_work_mem = 256MB
checkpoint_completion_target = 0.7
wal_buffers = 16MB
default_statistics_target = 100
random_page_cost = 4
effective_io_concurrency = 2
work_mem = 5242kB
min_wal_size = 1GB
max_wal_size = 2GB
max_worker_processes = 4
max_parallel_workers_per_gather = 2
max_parallel_workers = 4

EOL

echo '##### Applying new settings #####'                                
echo ' '
cat /var/lib/pgsql/11/data/pg_tune.conf                             
echo '##### Including config file in postgresql #####'                  


echo  "include = 'pg_tune.conf'" >> /var/lib/pgsql/11/data/postgresql.conf
echo ' '
echo '###### Restarting postgres with new settings #####'               
echo ' '

systemctl restart postgresql-11.service

echo '##### Creating Database #####'
echo ' '
sudo -u postgres createdb unbench_the_kench >/dev/null 2>&1
echo '##### Filling the database with junk #####'
echo ' '
sudo -u postgres pgbench -i -s 10 -p 5432 -d unbench_the_kench
echo '##### Running benchmark against PG_tune #####'

for i in {1..15}
do
sudo -u postgres pgbench unbench_the_kench -c 100 -T 3 -S -n >> result2.txt
done

grep -i processed result2.txt | awk '{printf "%s\n", $6}' > result_nums2.txt

count2=0;
sum2=0;

for i in $( awk '{ printf "%s\n", $1 }' result_nums2.txt )
	   do
	        sum2=$(echo $sum2+$i | bc )
     		((count2++))
       done
pg_bench=$(echo 'Average number of transactions processed from 10 iterations '&& echo "scale=2; $sum2 / $count2" | bc)
echo '##### Cleaning up ##### '
echo ' '

sudo -u postgres dropdb unbench_the_kench >/dev/null 2>&1
rm result2.txt result_nums2.txt
rm /var/lib/pgsql/11/data/pg_tune.conf
sed -i '$d' /var/lib/pgsql/11/data/postgresql.conf
systemctl restart postgresql-11.service




cat << EOF 
#############################
##### Results of tuning #####
#############################

Default tuning results
${default_tuning}

Neds magical tuning results
${neds_tuning}

pg_tune results
${pg_bench}
EOF
