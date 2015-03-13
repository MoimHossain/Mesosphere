
echo "Add the Mesosphere Repositories to Hosts"
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv E56151BF
DISTRO=$(lsb_release -is | tr '[:upper:]' '[:lower:]')
CODENAME=$(lsb_release -cs)
echo "deb http://repos.mesosphere.io/${DISTRO} ${CODENAME} main" | sudo tee /etc/apt/sources.list.d/mesosphere.list


echo "Install the Necessary Components"
sudo apt-get -y update

echo "Installing mesosphere packages...please wait."
sudo apt-get -y install mesosphere



echo "Set up the Zookeeper Connection Info for Mesos"
sudo sed -i -e s/localhost:2181/192.0.2.101:2181,192.0.2.102:2181,192.0.2.103:2181/g /etc/mesos/zk


echo "Assiging ID to Master Servers"
sudo sed -i -e s/.*/$2/g /etc/zookeeper/conf/myid

echo "Configure the Master Servers' Zookeeper Configuration"
sudo sed -i -e s/#server.1=zookeeper1:2888:3888/server.1=192.0.2.101:2888:3888/g /etc/zookeeper/conf/zoo.cfg
sudo sed -i -e s/#server.2=zookeeper2:2888:3888/server.2=192.0.2.102:2888:3888/g /etc/zookeeper/conf/zoo.cfg
sudo sed -i -e s/#server.3=zookeeper3:2888:3888/server.3=192.0.2.103:2888:3888/g /etc/zookeeper/conf/zoo.cfg


echo "Configure Mesos on the Master Servers"
sudo sed -i -e s/.*/2/g /etc/mesos-master/quorum

echo "Configure the Hostname and IP Address"
echo 192.0.2.$1 | sudo tee /etc/mesos-master/ip
sudo cp /etc/mesos-master/ip /etc/mesos-master/hostname

echo "Configure Marathon on the Master Servers"
sudo mkdir -p /etc/marathon/conf
sudo cp /etc/mesos-master/hostname /etc/marathon/conf

sudo cp /etc/mesos/zk /etc/marathon/conf/master

sudo cp /etc/marathon/conf/master /etc/marathon/conf/zk
sudo sed -i -e s/mesos/marathon/g /etc/marathon/conf/zk


echo "Configure Service Init Rules and Restart Services"

sudo stop mesos-slave
echo manual | sudo tee /etc/init/mesos-slave.override

sudo restart zookeeper
sudo start mesos-master
sudo start marathon


echo "Finished configuring " 192.0.2.$1