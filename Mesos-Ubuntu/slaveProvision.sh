
echo "Add the Mesosphere Repositories to Hosts"
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv E56151BF
DISTRO=$(lsb_release -is | tr '[:upper:]' '[:lower:]')
CODENAME=$(lsb_release -cs)
echo "deb http://repos.mesosphere.io/${DISTRO} ${CODENAME} main" | sudo tee /etc/apt/sources.list.d/mesosphere.list


echo "Install the Necessary Components"
sudo apt-get -y update

echo "Installing mesos...please wait."
sudo apt-get -y install mesos


echo "Set up the Zookeeper Connection Info for Mesos"
sudo sed -i -e s/localhost:2181/192.0.2.101:2181,192.0.2.102:2181,192.0.2.103:2181/g /etc/mesos/zk

echo "Configure the Slave Servers"
sudo stop zookeeper
echo manual | sudo tee /etc/init/zookeeper.override

echo manual | sudo tee /etc/init/mesos-master.override
sudo stop mesos-master


echo "Configure the Hostname and IP Address"
echo 192.0.2.$1 | sudo tee /etc/mesos-master/ip
sudo cp /etc/mesos-master/ip /etc/mesos-master/hostname

sudo start mesos-slave