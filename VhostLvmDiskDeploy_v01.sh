#!/usr/bin
#功能：宿主机存LVM储池部署
#注意:脚本不支持中文系统,请先修改系统为英文
#Change:2017.6.21

serinfname=serinf10.14.sh
log=/tmp/ws_vhost_auto_install_v01_lvmDisk.log
>$log
#存储池名称
sys_disk_hdd_pool=sys-hdd-dir
udisk_hdd_pool=udisk-hdd-lvm
udisk_ssd_pool=udisk-ssd-lvm

result_check(){
result=`cat $log|grep "异常"|wc -l`
if [[ $result -ge 1 ]];then
        echo "fail"
else
        echo "vmp-deploy-success"
fi
}
help="this is a example:
-s|--sizes             系统盘存储池大小
"
ARGS=`(getopt -o s: --long size: -n 'example.sh' -- "$@") 2>/dev/null`
if [ $? != 0 ]; then
    echo "$help 请遵守传参规范 异常">>$log
    result_check
    exit 1
fi


eval set -- "${ARGS}"
while true
do
    case "$1" in
        -s|--size)
	    sizes=$2
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
    echo "传入参数异常 $arg">>$log
    result_check
done


checkInt(){ 
        size_filter_G0=`echo $sizes|sed 's/G//g'`
        expr $size_filter_G0 + 0 &>/dev/null
        [ $? -ne 0 ] && { echo "输入必须为int类型 异常">>$log;result_check;exit 1; } 
} 

disk_install(){
if [[ ! -z $sizes ]];then
size_G=`echo $sizes|grep 'G'|wc -l`
if [[ $size_G = 0 ]];then
echo "输入值固定以G为单位请确认！异常">>$log
result_check
exit

fi
size_filter_G=`echo $sizes|sed 's/G//g'`
if [[ -z $size_filter_G ]];then
	echo "异常 请输入大小 如10G">>$log
	result_check
	exit
fi
if [[ `echo "$size_filter_G <= 0" | bc` -eq 1 ]];then

	echo "禁止输入0和负数!!! 异常">>$log
	result_check
	exit
fi
checkInt


if_chinese=`locale|grep "LANG="|grep zh|wc -l`
if [[ $if_chinese -ge 1 ]];then
        echo "不支持中文系统,请安装系统语言为英文 异常">>$log
	result_check
        exit
fi
echo "收集磁盘信息中...">>$log
if [[ -f /tmp/scanserver/scanServer.result ]];then
        rm -f /tmp/scanserver/scanServer.result
fi

if [[ ! -f ./$serinfname  ]];then
echo "上传$serinfname 与脚本同级目录 异常">>$log
result_check
exit
fi

/usr/bin/sh $serinfname >/dev/null 2>&1 

for online_disk in  `cat /tmp/disk_table |awk -F "::" '{print $1}'|xargs -n 1`
do
	used_id=`df -Th|grep boot|grep $online_disk|wc -l`
	if [[  $used_id = 1 ]];then
		ONLINE_SCSI_DISK_PRESENT=`echo $online_disk|sed 's#\/#\\\/#g'`
	fi

done

all_available_disk=`cat /tmp/disk_table |awk -F "::" '{print $1}'|xargs echo|sed "s/$ONLINE_SCSI_DISK_PRESENT//g"`
for all_disk_num in `echo $all_available_disk|xargs -n 1`
do
	ifmount=`df -Th|grep $all_disk_num|wc -l`
	if [[ $ifmount = 1  ]];then
		echo "请先清理宿主机磁盘环境 如磁盘是否已挂载 /etc/fstab 异常">>$log
		result_check
		exit
	fi

done
#获取SSD磁盘个数 创建vg1
ONLINE_SSD_DISK_NEWADD=`cat /tmp/disk_table |grep  SSD|awk -F "::" '{print $1}'|xargs|sed "s/$ONLINE_SCSI_DISK_PRESENT//g"`
echo -e  "\033[32mNew added SSD disk:\033[0m" >>$log
echo -e  "\033[32m$ONLINE_SSD_DISK_NEWADD\033[0m" >>$log
if [[ ! -z $ONLINE_SSD_DISK_NEWADD  ]];then

        VG1_Name=$(vgdisplay | grep 'VG Name' | awk '{print $NF}'|grep vg1)
        
        if [[  -z $VG1_Name ]];then
				lvm_exist_ssd=`lvdisplay |grep '/dev/vg1'|awk -F " " '{print $3}'`
				if [[ ! -z $lvm_exist_ssd ]];then
					(echo "yes" | lvremove $lvm_exist_ssd) >/dev/null 2>&1
				fi 
				for sdd_disk_num in `echo $ONLINE_SSD_DISK_NEWADD `
				do
						dd if=/dev/urandom   of=$sdd_disk_num  bs=512 count=64 >/dev/null 2>&1
				done
				
                pvcreate `echo $ONLINE_SSD_DISK_NEWADD` >/dev/null 2>&1
				if [ $? -ne 0 ];then
					vg1remove=`dmsetup ls|awk -F " " '{print $1}'|grep vg1`
					for vg1removes in `echo $vg1remove|xargs -n 1`
					do
							dmsetup remove $vg1removes >/dev/null  2>&1
					done
                fi
				pvcreate `echo $ONLINE_SSD_DISK_NEWADD` >/dev/null 2>&1
                vgcreate vg1 `echo $ONLINE_SSD_DISK_NEWADD`  >/dev/null 2>&1
                echo "vg1创建完成" >>$log
        else
                vgremove vg1 >/dev/null 2>&1
				lvm_exist_ssd=`lvdisplay |grep '/dev/vg1'|awk -F " " '{print $3}'`
				if [[ ! -z $lvm_exist_ssd ]];then
					(echo "yes" | lvremove $lvm_exist_ssd) >/dev/null 2>&1
				fi 
                for sdd_disk_num in `echo $ONLINE_SSD_DISK_NEWADD `
                do
                    dd if=/dev/urandom   of=$sdd_disk_num  bs=512 count=64 >/dev/null 2>&1
                done
                pvcreate `echo $ONLINE_SSD_DISK_NEWADD` >/dev/null 2>&1
				if [ $? -ne 0 ];then
					vg1remove=`dmsetup ls|awk -F " " '{print $1}'|grep vg1`
								for vg1removes in `echo $vg1remove|xargs -n 1`
								do
										dmsetup remove $vg1removes >/dev/null  2>&1
								done
				fi
				pvcreate `echo $ONLINE_SSD_DISK_NEWADD` >/dev/null 2>&1				
                vgcreate vg1 `echo $ONLINE_SSD_DISK_NEWADD` >/dev/null 2>&1
                echo "vg1创建完成" >>$log
        fi
else
    echo  -e "\033[31m不存在ssd磁盘\033[0m">>$log
fi

#已经分区的磁盘
#检测hdd磁盘 创建vg0
ONLINE_HDD_DISK_NEWADD=`cat /tmp/disk_table |grep -v SSD|awk -F "::" '{print $1}'|xargs echo | sed "s/$ONLINE_SCSI_DISK_PRESENT//g"`
if [[ -z $ONLINE_HDD_DISK_NEWADD ]];then
        echo "\033[31m不存在hdd磁盘,请先确认磁盘数 异常\033[0m" >>$log
	result_check
        exit
fi
echo -e "\033[32mNew added HDD disk:\033[0m" >>$log
echo -e "\033[32m$ONLINE_HDD_DISK_NEWADD\033[0m" >>$log

VG0_Name=$(vgdisplay | grep 'VG Name' | awk '{print $NF}'|grep vg0)
    if [[ -z $VG0_Name ]];then
		lvm_exist=`lvdisplay |grep '/dev/vg0'|awk -F " " '{print $3}'`

        if [[ ! -z $lvm_exist ]];then
            (echo "yes" | lvremove $lvm_exist) >/dev/null 2>&1
        fi 
		
        for hdd_disk_num in `echo $ONLINE_HDD_DISK_NEWADD `
        do
                dd if=/dev/urandom   of=$hdd_disk_num bs=512 count=64 >/dev/null 2>&1
        done
        pvcreate `echo $ONLINE_HDD_DISK_NEWADD` >/dev/null 2>&1
                if [ $? -ne 0 ];then
					vg0remove=`dmsetup ls|awk -F " " '{print $1}'|grep vg0`
					for vg0removes in `echo $vg0remove|xargs -n 1`
					do
						dmsetup remove $vg0removes >/dev/null  2>&1
					done
                fi
		pvcreate `echo $ONLINE_HDD_DISK_NEWADD` >/dev/null 2>&1
        vgcreate vg0 `echo $ONLINE_HDD_DISK_NEWADD`  >/dev/null 2>&1 
        VG0_Name=$(vgdisplay | grep 'VG Name' | awk '{print $NF}')
    else
        umount_sys_dir=`df -Th|grep sys-hdd-dir|wc -l`
        if [[ $umount_sys_dir = 1  ]];then
            umount /sys-hdd-dir  >/dev/null 2>&1
        fi
        
        sys_hdd_dir_fstab=`cat /etc/fstab |grep 'LABEL=/sys-hdd-dir'`
        sys_hdd_dir_fstab_filer=`echo $sys_hdd_dir_fstab|sed 's#\/#\\\/#g'|awk -F " " '{print $1}'`

        if [[ ! -z $sys_hdd_dir_fstab ]];then
                sed -i "/$sys_hdd_dir_fstab_filer/d" /etc/fstab
        fi
        lvm_exist=`lvdisplay |grep '/dev/vg0'|awk -F " " '{print $3}'`

        if [[ ! -z $lvm_exist ]];then
            (echo "yes" | lvremove $lvm_exist) >/dev/null 2>&1
        fi 
        (vgremove vg0)  >/dev/null 2>&1

        for hdd_disk_num in `echo $ONLINE_HDD_DISK_NEWADD `
        do
                dd if=/dev/urandom   of=$hdd_disk_num bs=512 count=64 >/dev/null 2>&1
        done
        pvcreate `echo $ONLINE_HDD_DISK_NEWADD` >/dev/null 2>&1
                if [ $? -ne 0 ];then
					vg0remove=`dmsetup ls|awk -F " " '{print $1}'|grep vg0`
                        for vg0removes in `echo $vg0remove|xargs -n 1`
                        do
                                dmsetup remove $vg0removes >/dev/null  2>&1
                        done
                fi
		pvcreate `echo $ONLINE_HDD_DISK_NEWADD` >/dev/null 2>&1		
        vgcreate vg0 `echo $ONLINE_HDD_DISK_NEWADD`  >/dev/null 2>&1
        VG0_Name=$(vgdisplay | grep 'VG Name' | awk '{print $NF}')


        echo "hdd磁盘vg0 已创建" >>$log
    fi
vgscore=`vgs|grep vg0|awk -F " " '{print $6}'|wc -l`
#判断输入值是否大于vg0
vgsizes_t=`vgs|grep vg0|awk -F " " '{print $6}'|grep "t"|wc -l`
vgsizes_g=`vgs|grep vg0|awk -F " " '{print $6}'|grep "g"|wc -l`
if [[ ! -z $vgscore ]];then
	if [[ $vgsizes_t = '1'  ]];then
		vgsizes=`vgs|grep vg0|awk -F " " '{print $6}'|sed 's/t//g'|sed  's/<//'|sed  's/>//'`
		vgsizes_G=`echo "scale=2; $vgsizes*1024" | bc`
	elif [[ $vgsizes_g = '1'  ]];then
		vgsizes=`vgs|grep vg0|awk -F " " '{print $6}'|sed 's/g//g'|sed  's/<//'|sed  's/>//'`
		vgsizes_G=$vgsizes
	else
		echo "vgs 显示大小异常确认是否以g或者t 为单位异常">>$log
		result_check
		exit
	fi
	if [[ `echo "$size_filter_G >= $vgsizes_G" | bc` -eq 1 ]];then
		echo "输入值大于现有vg0 异常 ">>$log
		result_check
		exit
	fi
fi

#创建sys-hdd-dir 逻辑卷
lvcreate_id=`lvdisplay |grep 'LV Name'|grep "$sys_disk_hdd_pool"|wc -l`
if [[ ! -z $VG0_Name  ]];then
        if [[ $lvcreate_id > '0' ]];then
                echo -e "\033[31mlvm已创建/dev/vg0/$sys_disk_hdd_pool,如需重新设置请手动删除已创建的lvm逻辑卷 异常\033[0m" >>$log
        else
                (echo "y" | lvcreate -n $sys_disk_hdd_pool -L $sizes -i 3 -I 64 vg0)  >/dev/null 2>&1
                (mkfs.ext4 -L /$sys_disk_hdd_pool /dev/vg0/$sys_disk_hdd_pool)   >/dev/null 2>&1

                echo "创建/dev/vg0/$sys_disk_hdd_pool lvm逻辑卷成功 正常">>$log
        fi
else
        echo -e "\033[31m未创建vg0 异常\033[0m" >>$log
fi

sys_hdd_dir_mount=`cat /etc/fstab |grep "$sys_disk_hdd_pool"|wc -l`
if [[ $sys_hdd_dir_mount > '0' ]];then
        echo "$sys_disk_hdd_pool 自动挂载已添加 正常">>$log
else
        echo "LABEL=/$sys_disk_hdd_pool                      /$sys_disk_hdd_pool            ext4    defaults        0 0">>/etc/fstab
fi
if [[ ! -d /$sys_disk_hdd_pool ]];then
        mkdir /$sys_disk_hdd_pool
fi

(mount -a)  >/dev/null 2>&1
if [ $? -ne 0 ];then
	echo "挂载查看/etc/fstab 异常">>$log
	result_check
	exit
else
	rm -fr /sys-hdd-dir/*  >>/dev/null 2>&1
fi
sys_hdd_id=`virsh pool-list|grep  "$sys_disk_hdd_pool"  |wc -l`

#创建sys-hdd-dir存储池
if [[  -d /$sys_disk_hdd_pool ]];then
        if [[ $sys_hdd_id = '0' ]];then
                virsh pool-define-as $sys_disk_hdd_pool dir --target /$sys_disk_hdd_pool >/dev/null 2>&1
                virsh pool-build $sys_disk_hdd_pool >/dev/null 2>&1
                virsh pool-autostart $sys_disk_hdd_pool >/dev/null 2>&1
                virsh pool-start $sys_disk_hdd_pool >/dev/null 2>&1
                echo "创建$sys_disk_hdd_pool 存储池成功 正常" >>$log
        else
                echo "$sys_disk_hdd_pool 存储池已创建" >>$log
		virsh pool-autostart $sys_disk_hdd_pool >/dev/null 2>&1
		virsh pool-start $sys_disk_hdd_pool >/dev/null 2>&1
                virsh pool-refresh $sys_disk_hdd_pool >/dev/null 2>&1
        fi
else
        echo "系统未挂载/$sys_disk_hdd_pool 无法创建$sys_disk_hdd_pool存储池 异常">>$log
fi
#创建udisk_hdd_lvm存储池
udisk_hdd_lvm_id=`virsh pool-list|grep  "$udisk_hdd_pool" |wc -l`
if [[ ! -z $VG0_Name   ]];then
        if [[ $udisk_hdd_lvm_id = '0' ]];then
                virsh  pool-define-as $udisk_hdd_pool logical --source-dev /dev/vg0 --source-name vg0 >/dev/null 2>&1
                virsh  pool-autostart $udisk_hdd_pool >/dev/null 2>&1
                virsh  pool-start $udisk_hdd_pool >/dev/null 2>&1
                echo "创建$udisk_hdd_pool 存储池成功 正常">>$log
        else
		virsh pool-autostart $sys_disk_hdd_pool >/dev/null 2>&1
		virsh  pool-start $udisk_hdd_pool >/dev/null 2>&1
                virsh pool-refresh $udisk_hdd_pool >/dev/null 2>&1
                echo "$udisk_hdd_pool 存储池已创建">>$log
        fi
else
        echo "未创建vg0,无法创建存储池,命令vgdisplay查看 异常" >>$log
fi

VG1_Name=$(vgdisplay | grep 'VG Name' | awk '{print $NF}'|grep vg1)
#创建lvm-ssd存储池
udisk_ssd_lvm_id=`virsh pool-list|grep  "$udisk_ssd_pool"  |wc -l`
if [[ ! -z $VG1_Name   ]];then

        if [[ $udisk_ssd_lvm_id = '0' ]];then
                virsh  pool-define-as $udisk_ssd_pool logical --source-dev /dev/vg1 --source-name vg1 >/dev/null 2>&1
                virsh  pool-autostart $udisk_ssd_pool >/dev/null 2>&1
                virsh  pool-start $udisk_ssd_pool >/dev/null 2>&1
                echo "创建$udisk_ssd_pool 存储池成功 正常" >>$log
        else
                echo "$udisk_ssd_pool 存储池已创建" >>$log
		virsh pool-autostart $sys_disk_hdd_pool >/dev/null 2>&1
		virsh  pool-start $udisk_ssd_pool >/dev/null 2>&1
                virsh pool-refresh $udisk_ssd_pool >/dev/null 2>&1
        fi
else
         echo "未提供ssd盘,无法创建$udisk_ssd_pool 存储池,无ssd盘为正常" >>$log
fi
        echo -e "\033[32m磁盘分区完成 日志cat /tmp/ws_kvm_install_v01.log\033[0m" >>$log

if [[ -f /tmp/scanserver/scanServer.result ]];then
	rm -f /tmp/scanserver/scanServer.result 
fi
result_check
fi
}



disk_install
