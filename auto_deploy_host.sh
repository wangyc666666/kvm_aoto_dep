#!/bin/bash
#time:2017.4.1
#author:wangyc
#usage:虚拟机安装环境检测，以及自动化部署,存储池自动化部署
#version:1.1
#Change:2017.9.12
#last action 增加清理功能,检测br0是否为脚本设置否则异常
serinfname=serinf10.14.sh
nowdate=`date +%Y-%m-%d-%H:%M:%S`
kvm_conf_base="/usr/local/"
log=/tmp/ws_vhost_auto_install_v01.log
rpm_url=/home
#存储池名称
sys_disk_hdd_pool=sys-hdd-dir
udisk_hdd_pool=udisk-hdd-lvm
udisk_ssd_pool=udisk-ssd-lvm
iparray=()
prvi_iparray=()
> $log
install_state=0
kvm_install(){
if_chinese=`locale|grep "LANG="|grep zh|wc -l`
if [[ $if_chinese -ge 1 ]];then
        echo "不支持中文系统,请安装系统语言为英文 异常">>$log
	result_check
        exit
fi
#检测是否开启bios虚拟化技术
vmx_id=`egrep '(vmx|svm)' /proc/cpuinfo|wc -l`
if [[ $vmx_id > '0' ]];then
	echo "vmx状态 正常" >>$log
else
	echo -e "\033[31mvmx未启动请在bios下开启虚拟化技术 异常\033[0m" >>$log
	result_check
        exit
fi	
qemu_kvm_core=`rpm -qa|grep 'qemu-kvm' |wc -l`
libvirt_core=`rpm -qa|grep 'libvirt'|wc -l`
libguestfs_core=`rpm -qa|grep 'libguestfs'|wc -l`
qemu_img_core=`rpm -qa|grep 'qemu-img'|wc -l`
chattr -i /etc/passwd /etc/group /etc/gshadow /etc/shadow
(yum install -y net-tools qemu-kvm.x86_64 qemu-kvm-common.x86_64 java-1.7.0-openjdk  qemu-kvm-tools.x86_64  qemu-img.x86_64  libvirt-daemon.x86_64  libguestfs-tools)>/dev/null 2>&1 

modprobe kvm >>$log 2>&1
modprobe kvm_intel  >>$log 2>&1

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
	echo -e "\033[31mlibguestfs-tools未安装 异常\033[0m">>$log
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
	
else	
	echo -e "\033[31mlibvirt安装异常,缺失qemu.conf 异常\033[0m">>$log
	result_check
        exit
fi
service_status=`(/bin/systemctl status  libvirtd.service|grep 'Active'|awk -F ':' '{print $2}'|grep 'running') 2>/dev/null`
if [[ -z $service_status   ]];then
	echo "libvirtd 启动失败">>$log
fi
#安装网桥及rmp-vmp-host


(yum -y install rmp-vmp-host) >/dev/null 2>&1

(/usr/sbin/service rmp-vmp-host restart) >/dev/null 2>&1
rmp_vmp_host_start_core=`(/usr/sbin/service rmp-vmp-host status|grep running|grep -v not|wc -l) 2>/dev/null`
if [[ $rmp_vmp_host_start_core = '1' ]];then
	echo "rmp-vmp-host 启动正常">>$log
else
	 echo "rmp-vmp-host 启动 异常">>$log	
	result_check
        exit

fi
if [[ ! -f ./$serinfname ]];then
	echo "请上传$serinfname 与改脚本同级目录 异常">>$log
	result_check
	exit
fi
jdk_version=`rpm -qa|grep java-1.7|wc -l`
mulitu_jdk=`rpm -qa|grep jdk|wc -l`
if [[ $jdk_version >'0' ]];then
	echo "jdk版本为1.7正常" >>$log
else
	echo "jdk版本不为1.7 异常" >>$log
fi
if [[ $mulitu_jdk >'3' ]];then
	echo -e "\033[31mjdk存在多版本 异常 手动卸载不需要的jdk版本\033[0m">>$log
	result_check
    exit
fi


echo "统计ip地址中...">>$log
if [[ -f /tmp/scanserver/scanServer.result ]];then
	rm -f /tmp/scanserver/scanServer.result
fi
(sh ./$serinfname)>/dev/null 2>&1
init_ip_num=0
all_scan_ip=`cat /tmp/scanserver/scanServer.result |grep "ncip"|awk -F ":" '{print $2}'|sed 's/",//g'|sed 's/"//g'`
for ip in `echo $all_scan_ip|xargs -n 1`
do
ip_rex=`echo $ip|grep "^[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}$"|wc -l`
if [[ $ip_rex = 0 ]];then
	echo "ip地址不符合规范 异常">>$log
	result_check
	exit
fi
ip_address=`echo $ip|grep -E '(^192\.168\..*|^10\..*|^172\.16\..*|^172\.17\..*|^172\.18\..*|^172\.19\..*|^172\.20\..*|^172\.21\..*|^172\.22\..*|^172\.23\..*|^172\.24\..*|^172\.25\..*|^172\.26\..*|^172\.27\..*|^172\.28\..*|^172\.29\..*|^172\.30\..*|^172\.31\..*|^169\.254\..*)'|wc -l` 
if [[ $ip_address = 1 ]];then
	prvi_ip=$ip
        prvi_iparray+=($prvi_ip)
else
	public_ip=$ip
        iparray+=($public_ip)
fi


done

#公网ip数大于2的报异常

if [[  ${#iparray[@]} > 2 ]];then
	echo 公网ip地址数大于3异常 >>$log
	result_check
	exit
elif [[ ${#iparray[@]} = 0 ]];then
	echo "无法获取公网ip地址 异常">>$log
	result_check
	exit

fi

   

#判断两个公网ip的网卡名称是多少
public_ip_etx=()
public_ip_map=0
for var in ${iparray[@]}; 
do  
    public_ip_etx+=(`grep -r $var /etc/sysconfig/network-scripts/ifcfg-* |awk -F "/" '{print $5}'|awk -F ":" '{print $1}'|awk -F "-" '{print $2}'`)
	public_ip_map_eth=`grep -r $var /etc/sysconfig/network-scripts/ifcfg-* |awk -F "/" '{print $5}'|awk -F 'IPADDR=' '{print $1}'|awk -F ':' '{print $2}'`
	if [[ -z $public_ip_map_eth ]];then
		((public_ip_map=$public_ip_map+1))
	fi	
done  


echo ${public_ip_etx[*]} >>$log
if [[ ${#public_ip_etx[*]} > '1' ]];then
	if [[ ${public_ip_etx[0]} != ${public_ip_etx[1]} ]];then
		echo "公网ip数为2 对应网卡名称不同 异常">>$log
        	result_check
        	exit
	fi
fi

echo "公网ip地址为 ${iparray[@]}" >>$log
if [[ $public_ip_map < 1 ]];then
	echo '实网卡上无公网ip地址配置 异常' >>$log
	result_check
	exit
fi

if [[  -z ${iparray[0]}  ]];then
	echo "无法获取共有地址列表请检查/tmp/scanserver/scanServer.result 异常" >>$log
	result_check
	exit
fi


public_netcart=`cat /tmp/scanserver/scanServer.result|grep ${iparray[0]}  -A 3|grep netcardname|awk -F ":" '{print $2}'|sed "s/\"//g"|sed "s/,//g"`
(ls /tmp/ifcfg-$public_netcart:*) >/dev/null 2>&1
if [ $? -eq 0  ];then
	all_ip=`(ls /tmp/ifcfg-$public_netcart:*|grep -v "bak") 2>/dev/null`
	vip_netcar=`echo $all_ip|sed 's/\/tmp\///g'|xargs -n 1|grep :`
else
	all_ip=`(ls /etc/sysconfig/network-scripts/ifcfg-$public_netcart:*|grep -v "bak"|sed 's/\/etc\/sysconfig\/network-scripts\///g') 2>/dev/null`
	for net_cart in `echo $all_ip`
	do
		mv /etc/sysconfig/network-scripts/$net_cart  /tmp/$net_cart 
	done
	all_ip=`(ls /tmp/ifcfg-$public_netcart:*|grep -v "bak") 2>/dev/null`
	vip_netcar=`echo $all_ip|sed 's/\/tmp\///g'|xargs -n 1|grep :`
fi


if [[ ! -z $vip_netcar ]];then

for vcart in `echo $vip_netcar|xargs -n 1`
do

br_num=`echo $vcart|awk -F ":" '{print $2}'`
br_ipaddr=`(cat /tmp/$vcart|grep 'IPADDR')2>/dev/null`
br_netmask=`(cat /tmp/$vcart|grep 'NETMASK')2>/dev/null`
br_gateway=`(cat /tmp/$vcart|grep 'GATEWAY')2>/dev/null`

if [[ ! -f /etc/sysconfig/network-scripts/ifcfg-br0:$br_num ]];then
	touch /etc/sysconfig/network-scripts/ifcfg-br0:$br_num
fi
v_device_check=`cat /etc/sysconfig/network-scripts/ifcfg-br0:$br_num|grep 'DEVICE=br0'|wc -l`
v_TYPe_check=`cat /etc/sysconfig/network-scripts/ifcfg-br0:$br_num|grep 'TYPE=Bridge'|wc -l`
v_BOOTPROTO_check=`cat /etc/sysconfig/network-scripts/ifcfg-br0:$br_num|grep 'BOOTPROTO=static'|wc -l`
v_ONBOOT_check=`cat /etc/sysconfig/network-scripts/ifcfg-br0:$br_num|grep 'ONBOOT=yes'|wc -l`
v_IPADDR_check=`cat /etc/sysconfig/network-scripts/ifcfg-br0:$br_num|grep 'IPADDR'|wc -l`
v_NETMASK_check=`cat /etc/sysconfig/network-scripts/ifcfg-br0:$br_num|grep 'NETMASK='|wc -l`
#v_GATEWAY_check=`cat /etc/sysconfig/network-scripts/ifcfg-br0:$br_num|grep 'GATEWAY='|wc -l`
v_brdige_check_core=`expr $v_device_check + $v_TYPe_check + $v_BOOTPROTO_check + $v_ONBOOT_check + $v_IPADDR_check + $v_NETMASK_check`
if [[ $v_brdige_check_core != '6' ]];then
>/etc/sysconfig/network-scripts/ifcfg-br0:$br_num
cat >>/etc/sysconfig/network-scripts/ifcfg-br0:$br_num <<EOF
DEVICE=br0:$br_num
TYPE=Bridge
BOOTPROTO=static
ONBOOT=yes
$br_ipaddr
$br_netmask
$br_gateway
DNS1=114.114.114.114
DNS2=8.8.8.8
EOF
else
	echo "ifcfg-br0:$br_num 网桥已配置">>$log

fi
done
else
	echo "无别名网卡" >>$log
fi

#-------------------------------------------------------------------------------------



for phip in ${public_ip_etx[0]}
do	#查看网卡配置是否配置外网ip
        phip="ifcfg-$phip"
	public_cart=`cat /etc/sysconfig/network-scripts/$phip |grep ${iparray[0]} |wc -l`
	if [[ $public_cart > '0'  ]];then
		et=$phip
		if [[ ! -f /etc/sysconfig/network-scripts/$et.bak ]];then
			cp /etc/sysconfig/network-scripts/$et /tmp/$et.bak
		fi
		public_cart_new=`cat /tmp/$et.bak |grep ${iparray[0]} |wc -l`
	else
		if [[ -f /tmp/$phip.bak  ]];then
			public_cart_new=`cat /tmp/$phip.bak |grep ${iparray[0]} |wc -l`
			et=$phip
		else
			echo "$phip 网卡未查询到配置${iparray[0]}"  >/dev/null 2>&1
		fi
	

	fi
done


eth_init=`(ls /tmp/ifcfg-eth*|wc -l) 2>/dev/null`
if [[ $eth_init = '0' ]];then

	if [[ -f /tmp/ifcfg-br0.bak ]];then
		echo "异常，br0非本脚本设置，请手动删除br0，配置好网络">>$log
		result_check
		exit

	fi

fi
#验证网桥配置准确性
if [[ ! -f /etc/sysconfig/network-scripts/ifcfg-br0 ]];then
	  touch /etc/sysconfig/network-scripts/ifcfg-br0
fi
#验证网桥是否配置
if_bridge=`cat /etc/sysconfig/network-scripts/ifcfg-br0|grep 'IPADDR'|wc -l`

device_check=`cat /etc/sysconfig/network-scripts/ifcfg-br0|grep 'DEVICE=br0'|wc -l`	
TYPe_check=`cat /etc/sysconfig/network-scripts/ifcfg-br0|grep 'TYPE=Bridge'|wc -l`
BOOTPROTO_check=`cat /etc/sysconfig/network-scripts/ifcfg-br0|grep 'BOOTPROTO=static'|wc -l`
ONBOOT_check=`cat /etc/sysconfig/network-scripts/ifcfg-br0|grep 'ONBOOT=yes'|wc -l`
IPADDR_check=`cat /etc/sysconfig/network-scripts/ifcfg-br0|grep 'IPADDR'|wc -l`
NETMASK_check=`cat /etc/sysconfig/network-scripts/ifcfg-br0|grep 'NETMASK='|wc -l`
#GATEWAY_check=`cat /etc/sysconfig/network-scripts/ifcfg-br0|grep 'GATEWAY='|wc -l`
brdige_check_core=`expr $device_check + $TYPe_check + $BOOTPROTO_check + $ONBOOT_check + $IPADDR_check + $NETMASK_check`
if [[ $brdige_check_core != '6' ]];then
if [[ $public_cart_new > '0' ]];then
	if [[ ! -f /etc/sysconfig/network-scripts/ifcfg-br0 ]];then
		touch /etc/sysconfig/network-scripts/ifcfg-br0 
	fi
	if_br0=`cat /etc/sysconfig/network-scripts/$et|grep 'BRIDGE=br0'|wc -l`
	if_bridge=`cat /etc/sysconfig/network-scripts/ifcfg-br0|grep 'IPADDR'|wc -l`
	br0_ipaddr=`cat /tmp/$et.bak|grep 'IPADDR'`  
	br0_netmask=`cat /tmp/$et.bak|grep 'NETMASK'`
	br0_gateway=`cat /tmp/$et.bak|grep 'GATEWAY'`
	device=`echo "$et"|awk -F '-' '{print $2}'`
	if [[ $if_br0 = '0' ]];then
		>/etc/sysconfig/network-scripts/$et	
		cat >>/etc/sysconfig/network-scripts/$et <<EOF
DEVICE=$device
TYPE=Ethernet
ONBOOT=yes
BOOTPROTO=static
BRIDGE=br0

EOF
		echo "$et BRIDGE=br0配置完成" >>$log
	else
		echo "$et BRIDGE=br0已配置  ">>$log
	fi
	if [[ $brdige_check_core != '6'  ]];then	

		>/etc/sysconfig/network-scripts/ifcfg-br0
		cat >>/etc/sysconfig/network-scripts/ifcfg-br0 <<EOF
DEVICE=br0
TYPE=Bridge
BOOTPROTO=static
ONBOOT=yes
$br0_ipaddr
$br0_netmask
$br0_gateway
DNS1=114.114.114.114
DNS2=8.8.8.8
EOF
		echo "ifcfg-br0 配置完成">>$log
	else
		echo "ifcfg-br0 已配置">>$log
	fi

else
	echo -e "\033[31m未查询到${iparray[0]}  所对应的网卡 异常\033[0m"  
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
#GATEWAY_check=`cat /etc/sysconfig/network-scripts/ifcfg-br0|grep 'GATEWAY='|wc -l`
brdige_check_core=`expr $device_check + $TYPe_check + $BOOTPROTO_check + $ONBOOT_check + $IPADDR_check + $NETMASK_check `
if [[ $brdige_check_core = '6'  ]];then
	echo "网卡桥接配置正常">>$log
else
	echo "网桥ifcfg-br0配置错误">>$log

fi	
/bin/systemctl stop  NetworkManager.service >/dev/null 2>&1
/bin/systemctl disable NetworkManager.service  >/dev/null 2>&1
systemctl restart network >>/dev/null 2&>1

public_ip_length=${#iparray[@]}

pri_ip_length=${#prvi_iparray[@]}


online_all_ip=`ls -l /tmp/ifcfg-eth*|wc -l`
bripnum=`ip a |grep br0|grep -v vir|grep inet|wc -l`
if [[ $online_all_ip != $bripnum ]];then
	systemctl restart network >>/dev/null 2&>1
        echo "第二次重启网卡成功">>$log
        install_state=1
fi 

else
  echo "桥接已配置">>$log	  
#验证网桥配置准确性
device_check=`cat /etc/sysconfig/network-scripts/ifcfg-br0|grep 'DEVICE=br0'|wc -l`	
TYPe_check=`cat /etc/sysconfig/network-scripts/ifcfg-br0|grep 'TYPE=Bridge'|wc -l`
BOOTPROTO_check=`cat /etc/sysconfig/network-scripts/ifcfg-br0|grep 'BOOTPROTO=static'|wc -l`
ONBOOT_check=`cat /etc/sysconfig/network-scripts/ifcfg-br0|grep 'ONBOOT=yes'|wc -l`
IPADDR_check=`cat /etc/sysconfig/network-scripts/ifcfg-br0|grep 'IPADDR'|wc -l`
NETMASK_check=`cat /etc/sysconfig/network-scripts/ifcfg-br0|grep 'NETMASK='|wc -l`
#GATEWAY_check=`cat /etc/sysconfig/network-scripts/ifcfg-br0|grep 'GATEWAY='|wc -l`
brdige_check_core=`expr $device_check + $TYPe_check + $BOOTPROTO_check + $ONBOOT_check + $IPADDR_check + $NETMASK_check `
if [[ $brdige_check_core = '6'  ]];then
	echo "网卡桥接配置正常">>$log
else
	echo "网桥ifcfg-br0配置错误">>$log
	if_br0=`cat /etc/sysconfig/network-scripts/$et|grep 'BRIDGE=br0'|wc -l`
	if_bridge=`cat /etc/sysconfig/network-scripts/ifcfg-br0|grep 'IPADDR'|wc -l`
	br0_ipaddr=`cat /tmp/$et.bak|grep 'IPADDR'`
	br0_netmask=`cat /tmp/$et.bak|grep 'NETMASK'`
	br0_gateway=`cat /tmp/$et.bak|grep 'GATEWAY'`
	device=`echo "ifcfg-eth0"|awk -F '-' '{print $2}'`
>/etc/sysconfig/network-scripts/ifcfg-br0
cat >>/etc/sysconfig/network-scripts/ifcfg-br0 <<EOF
DEVICE=br0
TYPE=Bridge     
BOOTPROTO=static
ONBOOT=yes      
$br0_ipaddr
$br0_netmask
$br0_gateway
DNS1=114.114.114.114
DNS2=8.8.8.8
EOF
fi	
fi

ethport=`brctl show|grep br0|grep -v 'vir'|awk -F ' '  '{print $4}'`
if [[ -z $ethport ]];then
	echo -e  "\033[31m请先配置网桥 brctl show查看异常\033[0m" >>$log
	echo -e "\033[31m退出\033[0m"
	result_check
	exit
	
fi

#获取网卡速率
network_speed=`ethtool $ethport|grep Speed|awk -F':' '{print $2}'|awk -F 'b' '{print $1}'|sed s/[[:space:]]//g` 

if [ -z $network_speed ];then
	echo "无法获取$ethport获取网卡速率 手动配置/usr/local/rmp-vmp-host/conf/HostConfig.xml 异常" >>$log
	result_check
   exit
else


echo "网卡速率为 $ethport:$network_speed">>$log
if [[ ! -f  /usr/local/rmp-vmp-host/conf/HostConfig.xml.bak  ]];then
	cp /usr/local/rmp-vmp-host/conf/HostConfig.xml /usr/local/rmp-vmp-host/conf/HostConfig.xml.bak	
fi
statsunum_init=`cat /usr/local/rmp-vmp-host/conf/HostConfig.xml |grep '<hostPhysicalRate>'|wc -l`
if [[ -f /usr/local/rmp-vmp-host/conf/HostConfig.xml ]];then
	sed -i "s/<hostPhysicalRate>10000M<\/hostPhysicalRate>/<hostPhysicalRate>$network_speed<\/hostPhysicalRate>/g" /usr/local/rmp-vmp-host/conf/HostConfig.xml 
	hostconfig_core=`cat /usr/local/rmp-vmp-host/conf/HostConfig.xml |grep '<hostPhysicalRate>'|grep M|wc -l`
	if [[ $hostconfig_core >'0' ]];then
		echo "HostConfig.xml 配置正常">>$log
	else
		if [[ $statsunum_init = '0' ]];then
			echo "/usr/local/rmp-vmp-host/conf/HostConfig.xml <hostPhysicalRate>配置不存在 异常">>$log

			sed -i "/<\/net>/i\\\t\\t<hostPhysicalRate>$network_speed<\/hostPhysicalRate>" /usr/local/rmp-vmp-host/conf/HostConfig.xml
			sed -i "s/$(echo -e '\015')//g" /usr/local/rmp-vmp-host/conf/HostConfig.xml
			
		else
			echo "HostConfig.xml hostPhysicalRate配置 自动更正请核实">>$log
			linenum=`cat -n  "/usr/local/rmp-vmp-host/conf/HostConfig.xml" |grep "<hostPhysicalRate>" |awk '{print $1}'|sed -n "1"p `
			sed -i "$linenum"d  /usr/local/rmp-vmp-host/conf/HostConfig.xml	
			statsunum=`cat /usr/local/rmp-vmp-host/conf/HostConfig.xml |grep '<hostPhysicalRate>'|wc -l` 
			if [[ $statsunum = '0' ]];then
				sed -i "/<\/net>/i\\\t\\t<hostPhysicalRate>$network_speed<\/hostPhysicalRate>" /usr/local/rmp-vmp-host/conf/HostConfig.xml
				sed -i "s/$(echo -e '\015')//g" /usr/local/rmp-vmp-host/conf/HostConfig.xml
			else
				echo "/usr/local/rmp-vmp-host/conf/HostConfig.xml 存在<hostPhysicalRate>多条配置 ">>$log
			fi
		fi
	fi
fi 

fi





(systemctl restart rmp-vmp-host) >/dev/null 2>&1
service_status=`(/bin/systemctl status  rmp-vmp-host|grep 'Active'|awk -F ':' '{print $2}'|grep -v 'inactive') 2>/dev/null`
if [[ -z $service_status   ]];then
	echo "rmp-vmp-host 启动失败 异常">>$log
	result_check
	exit
fi



(/sbin/chkconfig rmp-vmp-host on)>/dev/null 2>&1
#sdn环境检测
if [[ ! -f ./check-sdn-service.sh ]];then
echo "上传check-sdn-service.sh 与脚本同级目录 异常">>$log
result_check
exit
fi
if [[ ! -f /usr/local/bin/license_check.sh ]];then
	echo -e "\033[31msdn服务未安装 异常\033[0m" >>$log
	result_check
        exit
else
	wslicense_core=`/usr/local/bin/license_check.sh 2>/dev/null`
fi
if [[ $wslicense_core = '0' ]];then
	echo "wslicense 已注册 正常">>$log
else
	echo -e "\033[31mwslicense 未注册 异常\033[0m">>$log
	result_check
        exit
fi	

sdn_check=`/usr/bin/sh check-sdn-service.sh 2>/dev/null`
if [[ $sdn_check = '0' ]];then
	echo "sdn功能 正常">>$log
else
	echo -e  "\033[31msdn功能 异常\033[0m">>$log
	result_check
        exit
fi      


if [[ -f /tmp/scanserver/scanServer.result ]];then
        rm -f /tmp/scanserver/scanServer.result
fi
chattr +i /etc/passwd /etc/group /etc/gshadow /etc/shadow

#创建default存储池
default_pool=`virsh pool-list|grep  default  |wc -l` 
default_core=`(ls -l /home/WSOS*.img |wc -l) 2>/dev/null`
images_core=`(ls -l /var/lib/libvirt/images/WSOS*.img|wc -l) 2>/dev/null`
if [[ $default_core > '0' ]];then
        if [[ -d /var/lib/libvirt/images  ]];then
                if [[ $images_core > '0' ]];then
                        echo "已拷贝WSOS*.img至/var/lib/libvirt/images" >>$log
                else
                        cp -f /home/WSOS*.img /var/lib/libvirt/images/
                        echo "成功拷贝WSOS*.img至/var/lib/libvirt/images">>$log
                fi
        else
                echo "/var/lib/libvirt/images 不存在 异常">$log
		 result_check
       		 exit
        fi
else
        echo "不存在镜像WSOS*.img 文件,请上传镜像至/home/ 异常">>$log
        result_check
	exit
fi

if [[ $default_pool = '0' ]];then
        virsh  pool-define-as default dir --target /var/lib/libvirt/images/ >/dev/null 2>&1
        virsh  pool-autostart default >/dev/null 2>&1
        virsh  pool-start default >/dev/null 2>&1
	virsh pool-refresh default >/dev/null 2>&1
else
        echo "default存储池已创建" >>$log
	virsh  pool-autostart default >/dev/null 2>&1
        virsh  pool-start default >/dev/null 2>&1
	virsh pool-refresh default >/dev/null 2>&1
fi

clean_all_disk
echo "第二次清理磁盘">>$log
clean_all_disk
result_check
exit
}

clean_all_disk(){

#pool-list_delete

pool_lists=`virsh pool-list --all |grep -v 'default'|awk -F " " '{print $1}'|grep -v "Name"|sed  '1d'`
for pools in `echo $pool_lists|xargs -n 1`
do
virsh pool-destroy $pools >/dev/null 2>&1
virsh pool-undefine $pools >/dev/null 2>&1
done
if [[ -f /usr/local/rmp-vmp-host/conf/block_storage.cfg ]];then
rm -f /usr/local/rmp-vmp-host/conf/block_storage.cfg >/dev/null 2>&1
fi
#hdd and ssd disk delete
for used in `cat /tmp/disk_table |grep -v "SSD" |awk -F "::" '{print $1}'`
do
	temp=`df -Th|grep boot`
	temp_id=`echo $temp|grep $used|wc -l`
	if [[ $temp_id = 1 ]];then
		used_id=`echo $used|sed 's#\/#\\\/#g'`
	fi


done
all_available_disk=`cat /tmp/disk_table |awk -F "::" '{print $1}'|xargs echo|sed "s/$used_id//g"`
for all_disk_num in `echo $all_available_disk|xargs -n 1`
do
	ifmount=`df -Th|grep $all_disk_num|wc -l`
	if [[ $ifmount = 1  ]];then
		mounted_name=`df -Th|grep "$all_disk_num"|awk -F " " '{print $7}'`
		umount $mounted_name
		dd if=/dev/urandom   of=$all_disk_num  bs=512 count=64 >/dev/null 2>&1
	fi

done


sys_hdd_dir_fstab=`cat /etc/fstab |grep 'LABEL='|awk -F " " '{if ($2!="/") print $1}'`

if [[ ! -z $sys_hdd_dir_fstab ]];then
	for del in `echo $sys_hdd_dir_fstab|xargs -n 1|sed 's#\/#\\\/#g'`
        do
	    sed  -i  "/$del/d" /etc/fstab
	
	done

	 if [ $? -eq 0 ];then
		echo "正常删除 /etc/fstab磁盘信息">>$log
	 else
		echo "异常删除 /etc/fstab磁盘信息,请核实">>$log
		 result_check
        	exit
	 fi
fi

#lvm delete
lvm_exist_ssd=`lvdisplay |grep '/dev/vg1'|awk -F " " '{print $3}'`
	if [[ ! -z $lvm_exist_ssd ]];then
		umount $lvm_exist_ssd >/dev/null 2>&1
		(echo "yes" | lvremove $lvm_exist_ssd) >/dev/null 2>&1
	fi
lvm_exist_hdd=`lvdisplay |grep '/dev/vg0'|awk -F " " '{print $3}'`
        if [[ ! -z $lvm_exist_hdd ]];then
		umount $lvm_exist_hdd >/dev/null 2>&1
                (echo "yes" | lvremove $lvm_exist_hdd) >/dev/null 2>&1
        fi
vg1_num=`vgdisplay |grep vg1|wc -l`
vg0_num=`vgdisplay |grep vg0|wc -l`
if [ ! -z $vg1_num ];then
	(vgremove vg1)  >/dev/null 2>&1
fi
if [ ! -z $vg0_num ];then
	(vgremove vg0)  >/dev/null 2>&1
fi
echo "磁盘清理完毕">>$log


}



result_check(){
result=`cat $log|grep "异常"|wc -l`
if [[ $result -ge 1 ]];then
        echo "fail"
else
        echo "vmp-deploy-success"
fi

}


kvm_install 




