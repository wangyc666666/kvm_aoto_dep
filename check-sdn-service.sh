#!/bin/sh

#version 1.0 chency

cur_date=`date +%F`
cur_time=`date +%H-%M`
pre_min=`date +%H:%M -d '1 mins ago'`
CUR_TIME_POINT=`echo "${cur_time}" | cut -c1-4`

monitor_dir=/tmp/sdn-device-monitor
log_file=${monitor_dir}/sdn_check.log.${cur_date}

#check sdn processes
sdn_processes=`ps aux | grep /usr/local/sdn/bin/sdn | egrep -v "grep|sdn_|rpm" | awk '{print $1,$2,$3,$4,$5,$6,$7,$8,$9,$11}' | grep -v "^$"`
get_ret=$?; #echo ${get_ret}
sdn_processes_num=`echo "${sdn_processes}" | grep -v "^$" | wc -l`
if [ ${sdn_processes_num} -lt 2 ]; then
	if [ ${get_ret} -eq 0 ] ; then
		echo "sdn process num error"
		exit 1
	elif [ ${get_ret} -eq 1 ] ; then
		ps_processes=`ps aux`; get_ret=$?
		if [ ${get_ret} -eq 0 ] ; then
			echo "sdn process num error"
			exit 1
		fi
	fi
elif [ ${sdn_processes_num} -gt 2 ]; then
	SERVICE_RESTART_NUM=`cat ${log_file} | grep ${CUR_TIME_POINT} | grep "SERVICE_RESTART" | wc -l`
	if [ ${SERVICE_RESTART_NUM} -gt 3 ]; then
		echo "sdn crash to much"
		exit 1
	fi
else    #sdn process normal
	#check listen port
	ports=`grep http-port /usr/local/sdn/etc/cache.conf | grep -v "#" | awk 'BEGIN{FS=":"}{print $2}' | awk '{print $1}'`
	for port in $ports; do
		if [ -f /usr/local/sdn/bin/nc ]; then
			nc_ret=`/usr/local/sdn/bin/nc 127.0.0.1 ${port} -z`
			port_check_ret=$?
		else
			curl_ret=`curl -x 127.0.0.1:${port} -0 -s -m 30 http://server.sdn.com/sdn-measured-info`
			port_check_ret=$?
		fi
		if [ ${port_check_ret} -ne 0 ] ; then
			if ! [ ${port_check_ret} -eq 135 ] ; then
				echo "[NOT_LISTENING] port ${port} ret ${port_check_ret}"
				exit 1
			fi
		fi
	done

	#check sdn_client_agent
	sdn_client_agent_processes=`ps aux | grep /usr/local/sdn/bin/sdn_client_agent | grep -v grep`
	if [ $? -ne 0 ] ; then
		echo "[NOT_RUNNING] sdn_client_agent"
		exit 1
	fi

	#check sdn access log
	FIRST_LOG_TIME=`head -n2 /usr/local/sdn/logs/access.log| awk '{print $4}'| awk -F"/|:" '{print $1,$2,$3" "$4":"$5":"$6}'| awk -F "[" '{print $2}'| tail -n1`
	LAST_LOG_TIME=`tail -n2 /usr/local/sdn/logs/access.log | awk '{print $4}'| awk -F"/|:" '{print $1,$2,$3" "$4":"$5":"$6}'| awk -F "[" '{print $2}'| head -n1`
	if [ -z "${FIRST_LOG_TIME}" ]; then
		is_pre_null=`cat ${log_file} | grep NOT_CORRECT | grep "sdn-access.log" | grep ${pre_min}`
		if ! [ -z "${is_pre_null}" ] ; then #when last min having nothing log too
			echo "[NOT_CORRECT] sdn-access.log"
			exit 1
		fi
	else
		LAST_LOG_SECOND=`date -d "${LAST_LOG_TIME}" +%s`
		CUR_TIME_SECOND=`date +%s`
		TIME_MINUS=`python -c "print ${CUR_TIME_SECOND} - ${LAST_LOG_SECOND}"`
		if [ ${TIME_MINUS} -ge 60 ]; then
			echo "[NOT_CORRECT] sdn-access.log"
			exit 1
		fi
	fi

	#check sdn cache.conf
	no_new_conf=`find /usr/local/sdn/etc/cache.conf -mtime +12`
	if ! [ -z "${no_new_conf}" ]; then
		echo "sdn cache.conf needs to update"
		exit 1
	else
		is_ori_conf=`/bin/ls -l /usr/local/sdn/etc/cache.conf | awk '{if($5<10860)print $0}'`
		if ! [ -z "${is_ori_conf}" ] ; then
			echo "sdn cache.conf needs to update"
			exit 1
		fi
		sdn_conf_lock=`/usr/bin/lsattr /usr/local/sdn/etc/cache.conf | grep "\-\-\-\-i" `
		if ! [ -z "${sdn_conf_lock}" ]; then
			echo "sdn cache.conf is i locked"
			exit 1
		fi
		update_normal=`cat /usr/local/sdn/etc/cache.conf | grep "update http://conf.sdn.lxdns.com:2012/sdn-cache.conf" | grep -v '#'`
		if [ -z "${update_normal}" ] ; then
			echo "sdn cache.conf having # update"
			exit 1
		fi
	fi

	is_listen_2012=`grep http-port /usr/local/sdn/etc/cache.conf | grep -v "#" | awk 'BEGIN{FS=":"}{print $2}' | awk '{print $1}' | grep 2012`
	if ! [ -z ${is_listen_2012} ] ; then
		local_test=`/usr/local/sdn/bin/sdn_send_trace.sh -a 127.0.0.1:2012 -t test | head -n1`
		if [ "${local_test}" != "0" ] ; then
			echo "local send trase error"
			exit 1
		fi
	fi
fi

#2017.8.10 edited by lvxy,replace "/var/spool/cron/root" with "/etc/cron.d/sdn-cron.conf".
in_cron=`cat /etc/cron.d/sdn-cron.conf | grep "/usr/local/sdn/etc/check-sdn.sh" | grep -v '#'`
if [ -z "${in_cron}" ] ; then
	echo "check-sdn.sh is not in cron"
	exit 1
fi

echo "0"
exit 0
