#!/bin/bash
#echo $@
#author:wangyc
#time:2017/06/01
#功能:虚拟机独立磁盘自动化部署，自动识别ssd 与hdd磁盘，ssd统作为数据盘，hdd指定创建虚拟机数量，创建相应的独立磁盘作为虚拟机系统盘使用
#剩余的hdd磁盘作为虚拟机磁盘使用
#Change:2017.6.21
serinfname=serinf10.14.sh 

log=/tmp/ws_vhost_auto_install_v01_block_device.log
>$log


result_check(){
result=`cat $log|grep "异常"|wc -l`
if [[ $result -ge 1 ]];then
        echo "fail"
else
        echo "vmp-deploy-success"
fi

}

help="this is a example:
-v|--vhostNum          0,1,2...(v=虚拟机数量)
-t|--machineType       如 宿主机_VOD&PIC共用<海外>
"
ARGS=`(getopt -o v:t: --long vhostNum:,machineType: -n 'example.sh' -- "$@") 2>/dev/null`
if [ $? != 0 ]; then
    echo "$help 输入参数异常" >>$log
    result_check
    exit 1
fi


eval set -- "${ARGS}"
while true
do
    case "$1" in
        -v|--vhostNum)
	    vhostNu=$2
            shift 2
            ;;
		-t|--machineType)
            mType=$2
            shift 2
            ;;
        --) shift ; break ;;

         *) echo -e "$help" ; exit 1
            exit 1
            ;;
    esac
done

#处理剩余的参数
for arg in $@
do
    echo "输入参数异常 $arg">>$log
    result_check   
    exit
done

auto_install_ip(){
if [[ ! -z $vhostNu ]];then

if [ $vhostNu -le 0 ];then
	echo "禁止输入0和负数!!! 异常">>$log
	result_check
	exit
fi

#使用中的hdd磁盘
echo "收集磁盘信息中...">>$log
if [[ ! -f ./$serinfname  ]];then
	echo "上传$serinfname文件必须与执行脚本放于同目录下 异常">>$log
	result_check
	exit
fi
/usr/bin/sh $serinfname  >/dev/null 2>&1
if_chinese=`locale|grep "LANG="|grep zh|wc -l`
if [[ $if_chinese -ge 1 ]];then
	echo "不支持中文系统,请安装系统语言为英文 异常">>$log
	result_check
	exit
fi



if [[ ! -d  /usr/local/rmp-vmp-host/conf/  ]];then
	mkdir -p /usr/local/rmp-vmp-host/conf/
fi

if [[ ! -f  /usr/local/rmp-vmp-host/conf/block_storage.cfg ]];then
	touch /usr/local/rmp-vmp-host/conf/block_storage.cfg
fi


vg_resouce=`vgdisplay |grep vg|wc -l`
if [[ $vg_resouce > 0 ]];then
	echo "请先清理磁盘vg资源 异常">>$log
	result_check
	exit
	
fi
if [[ ! -s /usr/local/rmp-vmp-host/conf/block_storage.cfg  ]];then
        	

	for used in `cat /tmp/disk_table |awk -F "::" '{print $1}'`
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
			echo "请先清理宿主机磁盘环境 如磁盘是否已挂载 /etc/fstab 异常">>$log
			result_check
			exit
		fi
		
	done

    SSD_TOTAL_NUM=`cat /tmp/disk_table |grep  SSD|awk -F "::" '{print $1}'|sed "s/$used_id//g"|wc -l`
	ONLINE_SSD_DISK_NEWADD=`cat /tmp/disk_table |grep  SSD|awk -F "::" '{print $1}'|xargs echo|sed "s/$used_id//g"`
	echo -e  "\033[32m可用ssd数据磁盘列表:\033[0m">>$log
	echo $ONLINE_SSD_DISK_NEWADD >>$log
	#ssd 只有一块并为海外指定类型机器时候. 划分两个分区使用
        if [ '1' == "$SSD_TOTAL_NUM"  -a '宿主机_VOD&PIC共用<海外>' == "$mType" ];then
		ssd_disk_if_insert=`cat /usr/local/rmp-vmp-host/conf/block_storage.cfg|grep $ONLINE_SSD_DISK_NEWADD |wc -l`
                if [[ $ssd_disk_if_insert = '0' ]];then
                        dd if=/dev/urandom   of=$ONLINE_SSD_DISK_NEWADD  bs=512 count=64 >/dev/null 2>&1
                        ssd_size=`fdisk -l|grep "$ONLINE_SSD_DISK_NEWADD:"|awk -F " " '{print $3}'`
                        ssd_size_mib=$(echo "$ssd_size*1000*1000*1000/1024/1024/2" | bc)
			ssd_size_mib=`echo $ssd_size_mib|awk -F "." '{print $1}'`
			ssd_size_mib=$ssd_size_mib"M"
/usr/sbin/fdisk $ONLINE_SSD_DISK_NEWADD >/dev/null 2>&1  <<EOF
n
p
1

+$ssd_size_mib

n
p
2

   
w
EOF
                        ssd_size_half_G=$(echo "$ssd_size/2" | bc)"GB"
                        echo "$ONLINE_SSD_DISK_NEWADD"1" ssd $ssd_size_half_G udisk" >> /usr/local/rmp-vmp-host/conf/block_storage.cfg
                        echo "$ONLINE_SSD_DISK_NEWADD"2" ssd $ssd_size_half_G udisk" >> /usr/local/rmp-vmp-host/conf/block_storage.cfg
                        echo "ssd数据盘$ONLINE_SSD_DISK_NEWADD 已写入/usr/local/rmp-vmp-host/conf/block_storage.cfg">>$log
                fi	

	else

		for ssd_disk_num in `echo $ONLINE_SSD_DISK_NEWADD `
		do
			ssd_disk_if_insert=`cat /usr/local/rmp-vmp-host/conf/block_storage.cfg|grep $ssd_disk_num |wc -l`
			if [[ $ssd_disk_if_insert = '0' ]];then
				dd if=/dev/urandom   of=$ssd_disk_num  bs=512 count=64 >/dev/null 2>&1
				ssd_size=`fdisk -l|grep "$ssd_disk_num:"|awk -F " " '{print $3}'`"GB"
				echo "$ssd_disk_num ssd $ssd_size udisk" >> /usr/local/rmp-vmp-host/conf/block_storage.cfg
				echo "ssd数据盘$ssd_disk_num 已写入/usr/local/rmp-vmp-host/conf/block_storage.cfg">>$log
			fi
		done

	fi

	#hdd
	#生成配置文件

	all_available_hdd_disk=`cat /tmp/disk_table |grep -v "SSD"|awk -F "::" '{print $1}'|xargs echo|sed "s/$used_id//g"`

	for hdd_disk_num in `echo $all_available_hdd_disk|xargs -n 1`
	do
		hdd_disk_if_insert=`cat /usr/local/rmp-vmp-host/conf/block_storage.cfg|grep $hdd_disk_num |wc -l`
		hdd_size=`fdisk -l|grep "$hdd_disk_num:"|awk -F " " '{print $3}'`"GB"
		if [[ $hdd_disk_if_insert = '0' ]];then
			dd if=/dev/urandom   of=$hdd_disk_num bs=512 count=64 >/dev/null 2>&1
			echo "$hdd_disk_num hdd $hdd_size udisk" >> /usr/local/rmp-vmp-host/conf/block_storage.cfg
			echo "hdd $hdd_disk_num 数据盘已写入 /usr/local/rmp-vmp-host/conf/block_storage.cfg" >> $log
		fi
	done

	#获取大于275G
	vhost_total=`cat /usr/local/rmp-vmp-host/conf/block_storage.cfg|grep -v "ssd"|grep -v sys|sed s/GB//g|sort -n -k 3 -t " "|awk -F " " '{if ($3>275) print $1;}'|head -n  $vhostNu`
	echo -e  "\033[32mhdd磁盘征用为虚拟机独立磁盘列表:\033[0m">>$log
	echo $vhost_total|xargs -n 1 >>$log
	#HDD_DISK_TOTALS=`cat /usr/local/rmp-vmp-host/conf/block_storage.cfg|grep -v "ssd"|grep -v sys|awk -F " " '{if (!$5) print $0;}'|wc -l`
	HDD_DISK_TOTALS=`cat /usr/local/rmp-vmp-host/conf/block_storage.cfg|grep -v "ssd"|grep -v sys|sed s/GB//g|sort -n -k 3 -t " "|awk -F " " '{if (!$5) print $0;}'|awk -F " " '{if($3>275) print $1;}'|wc -l`
        if [ $vhostNu -gt $HDD_DISK_TOTALS ];then
                echo "无法创建虚拟机，虚拟机数量大于可以使用hdd独立磁盘 异常">>$log
		result_check
                exit
        fi
	#frequency=`cat /usr/local/rmp-vmp-host/conf/block_storage.cfg|grep sys|wc -l`
	#((frequency = $frequency + 1))
        get_frequency
        frequency=`echo $?`
        if [ -z $frequency ];then
            echo "frequency $frequency 为空" >>$log
            exit
        fi
	for use_block in `echo $vhost_total|xargs -n 1`
	do
		ifmount=`df -Th|grep sys-hdd-dir$frequency|wc -l`
		block_line=`cat /usr/local/rmp-vmp-host/conf/block_storage.cfg|grep $use_block|sed 's#\/#\\\/#g'`
		disk_type=`cat /usr/local/rmp-vmp-host/conf/block_storage.cfg|grep "$use_block"|awk -F " " '{print $2}'`
		disk_size=`cat /usr/local/rmp-vmp-host/conf/block_storage.cfg|grep "$use_block"|awk -F " " '{print $3}'`
		use_block_format=`echo $use_block|sed 's#\/#\\\/#g'`
		if [[ $ifmount = 0 ]];then
			dd if=/dev/urandom   of=$use_block bs=512 count=64 >/dev/null 2>&1
			(echo y | mkfs.ext4 -L /sys-hdd-dir$frequency $use_block) >/dev/null 2>&1
			if [[ ! -d /sys-hdd-dir$frequency ]];then
				mkdir /sys-hdd-dir$frequency
			fi
			mount LABEL=/sys-hdd-dir$frequency  /sys-hdd-dir$frequency
			rm -fr  /sys-hdd-dir$frequency/*
			echo "$block_line">>$log
			echo "$use_block_format $disk_type $disk_size sys">>$log
			sed -i "s/$block_line/$use_block_format $disk_type $disk_size sys/g" /usr/local/rmp-vmp-host/conf/block_storage.cfg
		fi
		echo "磁盘$use_block $disk_size 创建 $vhostNu 块系统磁盘sys-hdd-dir$frequency" >>$log
		sys_hdd_dir_mount=`cat /etc/fstab |grep "$use_block"|wc -l`
		if [[ $sys_hdd_dir_mount = '0' ]];then
			echo "LABEL=/sys-hdd-dir$frequency                            /sys-hdd-dir$frequency            ext4    defaults        0 2">>/etc/fstab
		else
			echo "$block_use 自动挂载已添加 正常">>$log
		fi	
		sys_hdd_id=`virsh pool-list|grep  "sys-hdd-dir$frequency"  |wc -l`
		#创建sys-hdd-dir存储池
        if [[  -d /sys-hdd-dir$frequency ]];then
                if [[ $sys_hdd_id = '0' ]];then
                        virsh pool-define-as sys-hdd-dir$frequency dir --target /sys-hdd-dir$frequency >/dev/null 2>&1
                        virsh pool-build sys-hdd-dir$frequency >/dev/null 2>&1
                        virsh pool-autostart sys-hdd-dir$frequency >/dev/null 2>&1
                        virsh pool-start sys-hdd-dir$frequency >/dev/null 2>&1
                        echo "创建sys-hdd-dir$frequency 存储池成功 正常" >>$log
                else
                        echo "sys-hdd-dir$frequency 存储池已创建" >>$log
			virsh pool-autostart sys-hdd-dir$frequency >/dev/null 2>&1
                        virsh pool-start sys-hdd-dir$frequency >/dev/null 2>&1
                        virsh pool-refresh sys-hdd-dir$frequency >/dev/null 2>&1
                fi
        else
                echo "目录不存在/sys-hdd-dir$frequency 异常" >>$log
        fi
		#((frequency = $frequency + 1))
                get_frequency
                frequency=`echo $?`
                if [ -z $frequency ];then
                	echo "frequency $frequency 为空" >>$log
                	exit
        	fi
	done
else
	#新增hdd磁盘
	for used in `cat /tmp/disk_table |awk -F "::" '{print $1}'`
        do
                temp=`df -Th|grep boot`
                temp_id=`echo $temp|grep $used|wc -l`
                if [[ $temp_id = 1 ]];then
                        used_id=`echo $used|sed 's#\/#\\\/#g'`
                fi


        done
		ONLINE_SSD_DISK_NEWADD=`cat /usr/local/rmp-vmp-host/conf/block_storage.cfg|grep "ssd"`
		SYS_SSD_DISK_NEWADD=`cat /tmp/disk_table |grep  SSD|awk -F "::" '{print $1}'|xargs -n 1`
		
        for ssd_disk_num in `echo $SYS_SSD_DISK_NEWADD`
        do
		ssd_disk_if_exist=`cat /usr/local/rmp-vmp-host/conf/block_storage.cfg|grep $ssd_disk_num|wc -l`
                if [[ $ssd_disk_if_exist = '0' ]];then
                	dd if=/dev/urandom   of=$ssd_disk_num  bs=512 count=64 >/dev/null 2>&1
                        ssd_size=`fdisk -l|grep "$ssd_disk_num:"|awk -F " " '{print $3}'`"GB"
                        echo "$ssd_disk_num ssd $ssd_size udisk" >> /usr/local/rmp-vmp-host/conf/block_storage.cfg
                        echo "ssd新数据盘$ssd_disk_num 已写入/usr/local/rmp-vmp-host/conf/block_storage.cfg">>$log
                fi
        done

        all_available_hdd_disk=`cat /tmp/disk_table |grep -v "SSD"|awk -F "::" '{print $1}'|xargs echo|sed "s/$used_id//g"`

        for hdd_disk_num in `echo $all_available_hdd_disk|xargs -n 1`
        do
                hdd_disk_if_insert=`cat /usr/local/rmp-vmp-host/conf/block_storage.cfg|grep $hdd_disk_num |wc -l`
                hdd_size=`fdisk -l|grep "$hdd_disk_num:"|awk -F " " '{print $3}'`"GB"
                if [[ $hdd_disk_if_insert = '0' ]];then
                	dd if=/dev/urandom   of=$hdd_disk_num bs=512 count=64 >/dev/null 2>&1
                        echo "$hdd_disk_num hdd $hdd_size udisk" >> /usr/local/rmp-vmp-host/conf/block_storage.cfg
                        echo "hdd $hdd_disk_num 数据盘已写入 /usr/local/rmp-vmp-host/conf/block_storage.cfg" >> $log
                fi
        done

	ONLINE_SSD_DISK_NEWADD=`cat /usr/local/rmp-vmp-host/conf/block_storage.cfg|grep "ssd"|grep -v sys|awk -F " " '{if (!$5) print $1;}'`
	echo -e  "\033[32m可用ssd数据磁盘列表:\033[0m" >>$log
        echo $ONLINE_SSD_DISK_NEWADD >>$log
        #获取大于275G
	vhost_total=`cat /usr/local/rmp-vmp-host/conf/block_storage.cfg|grep -v "ssd"|grep -v sys|awk -F " " '{if (!$5) print $0;}'|sed s/GB//g|sort -n -k 3 -t " "|awk -F " " '{if ($3>275) print $1;}'|head -n  $vhostNu`
	echo -e  "\033[32mhdd盘征用为虚拟机独立磁盘列表:\033[0m" >>$log
        echo $vhost_total|xargs -n 1 >>$log
	#判断磁盘使用是否足够
	HDD_DISK_TOTALS=`cat /usr/local/rmp-vmp-host/conf/block_storage.cfg|grep -v "ssd"|grep -v sys|sed s/GB//g|sort -n -k 3 -t " "|awk -F " " '{if (!$5) print $0;}'|awk -F " " '{if($3>275) print $1;}'|wc -l`
	if [ $vhostNu -gt $HDD_DISK_TOTALS ];then
        	echo "无法创建虚拟机，虚拟机数量大于可以使用hdd独立磁盘 异常" >>$log
		result_check
        	exit
	fi
        #frequency=`cat /usr/local/rmp-vmp-host/conf/block_storage.cfg|grep sys|wc -l`
        #((frequency = $frequency + 1
        get_frequency
        frequency=`echo $?`
        if [ -z $frequency ];then
        	echo "frequency $frequency 为空" >>$log
                exit
        fi
        for use_block in `echo $vhost_total|xargs -n 1`
        do
                ifmount=`df -Th|grep sys-hdd-dir$frequency|wc -l`
                block_line=`cat /usr/local/rmp-vmp-host/conf/block_storage.cfg|grep $use_block|sed 's#\/#\\\/#g'`
                disk_type=`cat /usr/local/rmp-vmp-host/conf/block_storage.cfg|grep "$use_block"|awk -F " " '{print $2}'`
                disk_size=`cat /usr/local/rmp-vmp-host/conf/block_storage.cfg|grep "$use_block"|awk -F " " '{print $3}'`
                use_block_format=`echo $use_block|sed 's#\/#\\\/#g'`
                if [[ $ifmount = 0 ]];then
                        dd if=/dev/urandom   of=$use_block bs=512 count=64 >/dev/null 2>&1
                        (echo y | mkfs.ext4 -L /sys-hdd-dir$frequency $use_block) >/dev/null 2>&1
                        if [[ ! -d /sys-hdd-dir$frequency ]];then
                                mkdir /sys-hdd-dir$frequency
                        fi
			mount LABEL=/sys-hdd-dir$frequency  /sys-hdd-dir$frequency
			rm -fr  /sys-hdd-dir$frequency/*
                        echo "$block_line">>$log
                        echo "$use_block_format $disk_type $disk_size sys">>$log
                        sed -i "s/$block_line/$use_block_format $disk_type $disk_size sys/g" /usr/local/rmp-vmp-host/conf/block_storage.cfg
                fi
                echo "磁盘$use_block $disk_size 创建 $vhostNu 块系统磁盘sys-hdd-dir$frequency">>$log
                sys_hdd_dir_mount=`cat /etc/fstab |grep "$use_block"|wc -l`
                if [[ $sys_hdd_dir_mount = '0' ]];then
                      echo "LABEL=/sys-hdd-dir$frequency                            /sys-hdd-dir$frequency            ext4    defaults        0 2">>/etc/fstab
                else
                        echo "$block_use 自动挂载已添加 正常">>$log
                fi
        sys_hdd_id=`virsh pool-list|grep  "sys-hdd-dir$frequency"  |wc -l`
        #创建sys-hdd-dir存储池
        if [[  -d /sys-hdd-dir$frequency ]];then
                if [[ $sys_hdd_id = '0' ]];then
                        virsh pool-define-as sys-hdd-dir$frequency dir --target /sys-hdd-dir$frequency >/dev/null 2>&1
                        virsh pool-build sys-hdd-dir$frequency >/dev/null 2>&1
                        virsh pool-autostart sys-hdd-dir$frequency >/dev/null 2>&1
                        virsh pool-start sys-hdd-dir$frequency >/dev/null 2>&1
  	echo "创建sys-hdd-dir$frequency 存储池成功 正常" >>$log
                else
                        echo "sys-hdd-dir$frequency 存储池已创建" >>$log
			virsh pool-autostart sys-hdd-dir$frequency >/dev/null 2>&1
                        virsh pool-start sys-hdd-dir$frequency >/dev/null 2>&1
                        virsh pool-refresh sys-hdd-dir$frequency >/dev/null 2>&1
                fi
        else
                echo "目录不存在/sys-hdd-dir$frequency 异常">>$log
        fi
                #((frequency = $frequency + 1))
		get_frequency
        	frequency=`echo $?`
		if [ -z $frequency ];then
                	echo "frequency $frequency 为空" >>$log
                	exit
        	fi
        done

fi

result_check
fi

if [[ -f /tmp/scanserver/scanServer.result ]];then
        rm -f /tmp/scanserver/scanServer.result
fi

}
get_frequency(){
max_frequency=10
sys_hdd_dir_exist=`cat /etc/fstab|grep "sys-hdd-dir"|wc -l`
if [[ $sys_hdd_dir_exist > 0  ]];then
        for frequency in `seq 1 $max_frequency`
                do
                        existed=`cat /etc/fstab|grep sys-hdd-dir$frequency|wc -l`
                        if [[ $existed  > 0 ]];then
                                ((frequency=$frequency + 1))
                        else
                                return $frequency
                        fi


                done

else
        frequency=1
        return $frequency
fi

}

auto_install_ip


