#!/bin/bash
#time:2017.6.26
#author:wangyc
#usage:虚拟机安装环境检测
#version:1
log=/tmp/ws_vhost_check_host_environ_v01.log
>$log

rmp_vmp_name=`ls  /home/rmp-vmp-host* 2>/dev/null`
check_host_install(){
	vmx_id=`egrep '(vmx|svm)' /proc/cpuinfo|wc -l`
	if [[ $vmx_id > '0' ]];then
		echo "vmx状态 正常" >>$log 
	else
		echo -e "\033[31mvmx未启动请在bios下开启虚拟化技术 异常\033[0m"  >>$log
		result_check
		exit
	fi	
	#检测kvm_intel kvm模块是否正常
	kvm_intel_id=`lsmod | grep kvm|grep 'kvm'|wc -l`
	if [[ $kvm_intel_id == '2' ]];then
		echo "kvm 与kvm_intel模块存在 正常" >>$log
	else	
		echo -e "\033[31mkvm 与kvm_intel模块不存在 异常\033[0m">>$log
		result_check
		exit
	fi
	
	kvm_id=`(ls -l /dev/kvm|wc -l) 2>/dev/null`
		if [[ $kvm_id = '1' ]];then
			echo "kvm设备 正常">>$log
		else
			echo -e "\033[31mkvm设备不存在请查看是否正常安装kvm 异常\033[0m" >>$log
			result_check
			exit
		fi
	#检测libguestfs-tools是否安装
	libguesrfs_id=`rpm -qa|grep libguestfs-tools|wc -l`
	if [[ $libguesrfs_id > '0'  ]];then
		echo "libguestfs-tools已安装 正常">>$log
	else
		echo -e "\033[31mlibguestfs-tools安装异常 请重新安装\033[0m">>$log
		result_check
		exit
	fi
	
	#LIBGUESTFS_BACKEND环境变量设置
	direct_conf=`cat /etc/profile|grep "export LIBGUESTFS_BACKEND=direct"|wc -l`
	if [[ $direct_conf = '1' ]];then
		echo "LIBGUESTFS_BACKEND环境变量已设置 正常" >>$log
	else
		echo "export LIBGUESTFS_BACKEND=direct" >>/etc/profile
		echo "LIBGUESTFS_BACKEND环境变量已设置 正常" >>$log
	fi
	
	if [[ -f /etc/libvirt/qemu.conf ]];then
		sed -i 's/#user = "root"/user = "root"/g' /etc/libvirt/qemu.conf
		sed -i 's/#group = "root"/group = "root"/g' /etc/libvirt/qemu.conf
		/bin/systemctl restart  libvirtd.service
		/bin/systemctl enable libvirtd
		
	else	
		echo -e "\033[31mlibvirt安装异常，请重新安装\033[0m" >>$log
		result_check
		exit
	fi
	service_status=`/bin/systemctl status  libvirtd.service|grep 'Active'|awk -F ':' '{print $2}'|grep 'running'`
	if [[ -z $service_status   ]];then
		echo "libvirtd 启动异常" >>$log
		result_check
		exit
	fi
	
	rmp_vmp_id=`rpm -qa|grep rmp-vmp-host|wc -l`
	if [[ ! -f $rmp_vmp_name  ]];then
		echo -e "\033[31m请上传$rmp_vmp_name 目录 \033[0m" >>$log


	else
		if [[ $rmp_vmp_id > '0' ]];then
			echo "$rmp_vmp_name 已安装 正常" >>$log
		else
			rpm -ivh $rmp_vmp_name
			echo "$rmp_vmp_name 已安装 正常" >>$log
		fi
	fi
	#(/usr/sbin/service rmp-vmp-host restart) >/dev/null 2>&1
	rmp_vmp_host_start_core=`/usr/sbin/service rmp-vmp-host status|grep running|grep -v not|wc -l`
	if [[ $rmp_vmp_host_start_core = '1' ]];then
		echo "rmp-vmp-host 启动正常" >>$log
	else
		 echo "rmp-vmp-host 启动异常">>$log
		 result_check
		 exit

	fi
	
	#验证网桥配置准确性
	device_check=`cat /etc/sysconfig/network-scripts/ifcfg-br0|grep 'DEVICE=br0'|wc -l`	
	TYPe_check=`cat /etc/sysconfig/network-scripts/ifcfg-br0|grep 'TYPE=Bridge'|wc -l`
	BOOTPROTO_check=`cat /etc/sysconfig/network-scripts/ifcfg-br0|grep 'BOOTPROTO=static'|wc -l`
	ONBOOT_check=`cat /etc/sysconfig/network-scripts/ifcfg-br0|grep 'ONBOOT=yes'|wc -l`
	IPADDR_check=`cat /etc/sysconfig/network-scripts/ifcfg-br0|grep 'IPADDR'|wc -l`
	NETMASK_check=`cat /etc/sysconfig/network-scripts/ifcfg-br0|grep 'NETMASK='|wc -l`
	GATEWAY_check=`cat /etc/sysconfig/network-scripts/ifcfg-br0|grep 'GATEWAY='|wc -l`
	brdige_check_core=`expr $device_check + $TYPe_check + $BOOTPROTO_check + $ONBOOT_check + $IPADDR_check + $NETMASK_check + $GATEWAY_check`
		if [[ $brdige_check_core = '7'  ]];then
			echo "网卡桥接配置正常" >>$log
		else
			echo "网桥ifcfg-br0配置错误异常" >>$log
			result_check
			exit
	
		fi	
		
	jdk_version=`rpm -qa|grep java-1.7|wc -l`
	if [[ $jdk_version >'0' ]];then
		echo "jdk版本为1.7正常" >>$log
	else
		echo -e "\033[31mjdk版本不为1.7异常\033[0m" >>$log
		result_check
		exit
		#for i in `rpm -qa|grep jdk`
		#do
		#yum remove -y $i
		#done
		#yum install -y java-1.7.0-openjdk
	fi

	#systemctl restart rmp-vmp-host
	service_status=`/bin/systemctl status  rmp-vmp-host|grep 'Active'|awk -F ':' '{print $2}'|grep -v 'inactive'`
        if [[ -z $service_status   ]];then
                echo "rmp-vmp-host 启动异常" >>$log
				result_check
				exit
        fi
	/sbin/chkconfig rmp-vmp-host on
	#sdn环境检测
	if [[ ! -f /usr/local/bin/license_check.sh ]];then
		echo -e "\033[31msdn服务未安装 异常\033[0m"
		result_check
		exit
	else
		wslicense_core=`/usr/local/bin/license_check.sh`
	fi
	if [[ $wslicense_core = '0' ]];then
		echo "wslicense 已注册 正常" >>$log
	else
		echo -e "\033[31mwslicense 未注册 异常\033[0m" >>$log
		result_check
		exit
	fi	
	
	if [ ! -f ./check-sdn-service.sh ];then
		echo "请上传check-sdn-service.sh,与执行脚本同级目录" >>$log
		exit
	fi
	sdn_check=`/usr/bin/sh check-sdn-service.sh`
	if [[ $sdn_check = '0' ]];then
		echo "sdn功能 正常" >>$log
	else
		echo -e  "\033[31msdn功能 异常\033[0m" >>$log
		result_check
		exit
	fi  

	#获取网卡速率
 	 ethport=`brctl show|grep br0|grep -v 'vir'|awk -F ' '  '{print $4}'`
        if [[ -z $ethport ]];then
                echo -e  "\033[31m请先配置网桥 brctl show查看异常\033[0m" >>$log
				result_check
				exit

        fi
	if [[ -z $ethport ]];then
		ethport='10000M'
	fi
	network_speed=`ethtool $ethport|grep Speed|awk -F':' '{print $2}'|awk -F 'b' '{print $1}'|sed s/[[:space:]]//g` 
	if [ -z $network_speed ];then
          echo "无法获取$ethport获取网卡速率请手动配置/usr/local/rmp-vmp-host/conf/HostConfig.xml 异常">>$log
		  result_check
		  exit
    else
	echo "网卡速率为 $ethport:$network_speed">>$log
	if [[ ! -f  /usr/local/rmp-vmp-host/conf/HostConfig.xml.bak  ]];then
		cp /usr/local/rmp-vmp-host/conf/HostConfig.xml /usr/local/rmp-vmp-host/conf/HostConfig.xml.bak	
	fi

		hostconfig_value=`cat /usr/local/rmp-vmp-host/conf/HostConfig.xml |grep '<hostPhysicalRate>'|sed "s/<hostPhysicalRate>//g"|sed "s/<\/hostPhysicalRate>//g"|sed "s/M//g"`

		network_speed_filter_M=`echo  $network_speed|sed "s/M//g"`
		if [ $network_speed_filter_M = $network_speed_filter_M ];then
			echo "$ethport:$network_speed  HostConfig.xml $network_speed 速率一致配置正常">>$log
		else
			echo "$ethport:$network_speed  HostConfig.xml $network_speed 速率不一致配置异常">>$log
			result_check
			exit
		fi

		hostconfig_core=`cat /usr/local/rmp-vmp-host/conf/HostConfig.xml |grep '<hostPhysicalRate>'|grep M|wc -l`
		if [[ $hostconfig_core >'0' ]];then
			echo "/usr/local/rmp-vmp-host/conf/HostConfig.xml <hostPhysicalRate> 配置正常">>$log
		else
			echo "/usr/local/rmp-vmp-host/conf/HostConfig.xml <hostPhysicalRate> 配置异常" >>$log
			result_check
			exit
		fi
	fi 
	#检查是否开机启动
	libvirtd_chkconfig_on=`(systemctl is-enabled libvirtd|grep enabled |wc -l) 2>/dev/null`
	rmp_vmp_host_chkconfig_on=`(chkconfig --list|grep rmp-vmp-host |awk -F ' ' '{print $5}'|grep on|wc -l) 2>/dev/null`
	sdn_chkconfig_on=`(chkconfig --list|grep sdn |awk -F ' ' '{print $5}'|grep on|wc -l)2>/dev/null`
	if [[ $rmp_vmp_host_chkconfig_on > '0'  ]];then
		echo "rmp_vmp_host开机启动已设置"  >>$log
	else 
		echo "rmp_vmp_host开机启动未设置异常"  >>$log
		result_check
		exit

	fi

	if [[ $sdn_chkconfig_on > '0'  ]];then
                echo "sdn开机启动已设置"  >>$log
        else
                echo "sdn开机启动未设置异常"  >>$log
				result_check
				exit

        fi
	 if [[ $libvirtd_chkconfig_on > '0'  ]];then
                echo "libvirtd开机启动已设置">>$log
        else
                echo "libvirtd开机启动未设置异常" >>$log
				result_check
				exit

        fi
result_check
}

result_check(){
result=`cat $log|grep "异常"|wc -l`
if [[ $result -ge 1 ]];then
        echo "fail"
else
        echo "vmp-deploy-success"
fi

}

check_host_install
	
		
	
