使用方法:

1、auto_deploy_host.sh  自动化部署宿主机安装包
chmod a+x  auto_deploy_host.sh
./auto_deploy_host.sh

执行成功返回success 失败fail
日志文件 log=/tmp/ws_vhost_auto_install_v01.log 


2、VhostBlockDiskDeploy_v01.sh 自动化部署宿主机磁盘，以独立磁盘存储方式
chmod a+x VhostBlockDiskDeploy_v01.sh
./VhostBlockDiskDeploy_v01.sh -v 0,1,2...(v=虚拟机数量)

如./VhostBlockDiskDeploy_v01.sh -v 2
执行成功返回success 失败fail
日志文件 log=/tmp/ws_vhost_auto_install_v01_block_device.log 


3、VhostLvmDiskDeploy_v01.sh 自动化部署宿主机磁盘，以lvm存储池方式 
chmod a+x VhostLvmDiskDeploy_v01.sh 
./VhostLvmDiskDeploy_v01.sh -s (lvm存储池大小以G为单位)
如 ./VhostLvmDiskDeploy_v01.sh -s 100G

执行成功返回success 失败fail
日志文件 log=/tmp/ws_vhost_auto_install_v01_lvmDisk.log 



注意：以上脚本不支持中文系统，请修改中文系统为默认英文系统.
改动:VhostLvmDiskDeploy_v01.sh 可以支持流水传默认参数 格式 数值+G 如100G
auto_deploy_host.sh 多别名网卡迁移至br0，并删除原来别名配置文件，可以重复调用。