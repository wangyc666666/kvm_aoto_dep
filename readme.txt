ʹ�÷���:

1��auto_deploy_host.sh  �Զ���������������װ��
chmod a+x  auto_deploy_host.sh
./auto_deploy_host.sh

ִ�гɹ�����success ʧ��fail
��־�ļ� log=/tmp/ws_vhost_auto_install_v01.log 


2��VhostBlockDiskDeploy_v01.sh �Զ����������������̣��Զ������̴洢��ʽ
chmod a+x VhostBlockDiskDeploy_v01.sh
./VhostBlockDiskDeploy_v01.sh -v 0,1,2...(v=���������)

��./VhostBlockDiskDeploy_v01.sh -v 2
ִ�гɹ�����success ʧ��fail
��־�ļ� log=/tmp/ws_vhost_auto_install_v01_block_device.log 


3��VhostLvmDiskDeploy_v01.sh �Զ����������������̣���lvm�洢�ط�ʽ 
chmod a+x VhostLvmDiskDeploy_v01.sh 
./VhostLvmDiskDeploy_v01.sh -s (lvm�洢�ش�С��GΪ��λ)
�� ./VhostLvmDiskDeploy_v01.sh -s 100G

ִ�гɹ�����success ʧ��fail
��־�ļ� log=/tmp/ws_vhost_auto_install_v01_lvmDisk.log 



ע�⣺���Ͻű���֧������ϵͳ�����޸�����ϵͳΪĬ��Ӣ��ϵͳ.
�Ķ�:VhostLvmDiskDeploy_v01.sh ����֧����ˮ��Ĭ�ϲ��� ��ʽ ��ֵ+G ��100G
auto_deploy_host.sh ���������Ǩ����br0����ɾ��ԭ�����������ļ��������ظ����á�