
Write-Host "Gethering facts from Azure subscription..Please wait."

$ScriptDirectory = ".\bash"

if(Test-Path $ScriptDirectory) {
	Remove-Item $ScriptDirectory -Force -Recurse
}


$NEWLINE = "`n"

$vmInfo = Get-AzureVM -ServiceName "Mesossphare"
$numOfVm = $vmInfo.Length

Write-Host "Total $numOfVm virtual machines found."

$masterIpAddresses = @()
$slaveIpAddresses = @()

$masterMachineNames = @()
$slaveMachineNames = @()

for($i=1; $i -le $numOfVm; $i++) {
	$machineName = $vmInfo[$i - 1].Name
	$ipAddress = $vmInfo[$i - 1].IpAddress
    
    if($machineName -Match "Master") {
    	$masterMachineNames += $machineName
    	$masterIpAddresses += $ipAddress
    } else {
    	$slaveMachineNames += $machineName
    	$slaveIpAddresses += $ipAddress
    }    
}


Function AddEndpoints ($vm, $epName, $pubPort, $pvtPort)
{
	$endpoints = Get-AzureEndpoint -VM $vm
	$portAdded = $False

	for($x = 1; $x -le $endpoints.Length; $x ++) 
	{
		if($endpoints[$x-1].Name -Match $epName) 
		{
			$portAdded = $True
		}		
	}		
	
	if($portAdded) 
	{
		Write-Host -ForegroundColor GREEN ("Port ($epName) already exists in "  + $vm.Name) 
	}
	else 
	{
		Write-Host -ForegroundColor RED "Port ($epName) does not exist. Will create now..."
    	
    	Add-AzureEndpoint -Name $epName -Protocol tcp -LocalPort $pvtPort -PublicPort $pubPort -VM $vm | Update-AzureVM
	}
}

$marathonPort = 8080
$mesosPort = 5050
Write-Host "Creating EndPoints into the VM instances..."
for($i=1; $i -le $numOfVm; $i++) {
    if($vmInfo[$i - 1].Name -Match "Master") {
    	AddEndpoints $vmInfo[$i - 1] "Marathon" ($marathonPort + $i -1) $marathonPort
    	AddEndpoints $vmInfo[$i - 1] "Mesos" ($mesosPort + $i -1) $mesosPort
    }    
}



Write-Host "Generating Master script files.."

$zookeeperUrl = ""
$zookeeperConfig = ""
for($i=1; $i -le $masterIpAddresses.Length; $i++) {
	if($i -ge 2) {
		$zookeeperUrl += ","
	}
	$zookeeperUrl +=  $masterIpAddresses[$i - 1] + ":2181" 

	$zookeeperConfig += "sudo sed -i -e s/#server."+ $i +"=zookeeper"+ $i +":2888:3888/server."+ $i +"="+ $masterIpAddresses[$i - 1] +":2888:3888/g /etc/zookeeper/conf/zoo.cfg" + $NEWLINE	
}

for($i=1; $i -le $slaveIpAddresses.Length; $i++) {

	$scriptCode = "echo ""Add the Mesosphere Repositories to Hosts""" + $NEWLINE
	$scriptCode += "sudo apt-key adv --keyserver keyserver.ubuntu.com --recv E56151BF" + $NEWLINE
	$scriptCode += "DISTRO=`$(lsb_release -is | tr '[:upper:]' '[:lower:]')" + $NEWLINE
	$scriptCode += "CODENAME=`$(lsb_release -cs)" + $NEWLINE
	$scriptCode += "echo ""deb http://repos.mesosphere.io/`${DISTRO} `${CODENAME} main"" | sudo tee /etc/apt/sources.list.d/mesosphere.list" + $NEWLINE


	$scriptCode += "echo ""Install the Necessary Components""" + $NEWLINE
	$scriptCode += "sudo apt-get -y update" + $NEWLINE
	$scriptCode += "sudo apt-get -y install mesos" + $NEWLINE	

	$scriptCode += "echo ""Set up the Zookeeper Connection Info for Mesos""" + $NEWLINE
	$scriptCode += "sudo sed -i -e s/localhost:2181/" + $zookeeperUrl + "/g /etc/mesos/zk" + $NEWLINE
	$scriptCode += "sudo stop zookeeper" + $NEWLINE
	$scriptCode += "echo manual | sudo tee /etc/init/zookeeper.override" + $NEWLINE
	$scriptCode += "echo manual | sudo tee /etc/init/mesos-master.override" + $NEWLINE
	$scriptCode += "sudo stop mesos-master" + $NEWLINE

	$scriptCode += "echo " + $slaveIpAddresses[$i - 1] + " | sudo tee /etc/mesos-master/ip" + $NEWLINE
	$scriptCode += "sudo cp /etc/mesos-master/ip /etc/mesos-master/hostname" + $NEWLINE
	$scriptCode += "sudo start mesos-slave" + $NEWLINE

	$scriptName = $ScriptDirectory + "\" + $slaveMachineNames[$i - 1] + ".sh"
	New-Item $scriptName -type file -force -value $scriptCode	
}

for($i=1; $i -le $masterIpAddresses.Length; $i++) {

	$scriptCode = "echo ""Add the Mesosphere Repositories to Hosts""" + $NEWLINE
	$scriptCode += "sudo apt-key adv --keyserver keyserver.ubuntu.com --recv E56151BF" + $NEWLINE
	$scriptCode += "DISTRO=`$(lsb_release -is | tr '[:upper:]' '[:lower:]')" + $NEWLINE
	$scriptCode += "CODENAME=`$(lsb_release -cs)" + $NEWLINE
	$scriptCode += "echo ""deb http://repos.mesosphere.io/`${DISTRO} `${CODENAME} main"" | sudo tee /etc/apt/sources.list.d/mesosphere.list" + $NEWLINE


	$scriptCode += "echo ""Install the Necessary Components""" + $NEWLINE
	$scriptCode += "sudo apt-get -y update" + $NEWLINE
	$scriptCode += "sudo apt-get -y install mesosphere" + $NEWLINE	


	$scriptCode += "echo ""Set up the Zookeeper Connection Info for Mesos""" + $NEWLINE
	$scriptCode += "sudo sed -i -e s/localhost:2181/" + $zookeeperUrl + "/g /etc/mesos/zk" + $NEWLINE
	$scriptCode += "sudo sed -i -e s/.*/" + $i + "/g /etc/zookeeper/conf/myid" + $NEWLINE

	$scriptCode += "echo ""Configure the Master Server Zookeeper Configuration""" + $NEWLINE
	$scriptCode += $zookeeperConfig + $NEWLINE

	$scriptCode += "echo ""Configure Mesos on the Master Servers""" + $NEWLINE
	$scriptCode += "sudo sed -i -e s/.*/2/g /etc/mesos-master/quorum" + $NEWLINE

	$scriptCode += "echo ""Configure the Hostname and IP Address""" + $NEWLINE
	$scriptCode += "echo " + $masterIpAddresses[$i - 1] + " | sudo tee /etc/mesos-master/ip" + $NEWLINE
	$scriptCode += "sudo cp /etc/mesos-master/ip /etc/mesos-master/hostname" + $NEWLINE

	$scriptCode += "echo ""Configure Marathon on the Master Servers""" + $NEWLINE
	$scriptCode += "sudo mkdir -p /etc/marathon/conf" + $NEWLINE
	$scriptCode += "sudo cp /etc/mesos-master/hostname /etc/marathon/conf" + $NEWLINE	
	$scriptCode += "sudo cp /etc/mesos/zk /etc/marathon/conf/master" + $NEWLINE
	$scriptCode += "sudo cp /etc/marathon/conf/master /etc/marathon/conf/zk" + $NEWLINE
	$scriptCode += "sudo sed -i -e s/mesos/marathon/g /etc/marathon/conf/zk" + $NEWLINE


	$scriptCode += "echo ""Configure Service Init Rules and Restart Services""" + $NEWLINE
	$scriptCode += "sudo stop mesos-slave" + $NEWLINE
	$scriptCode += "echo manual | sudo tee /etc/init/mesos-slave.override" + $NEWLINE
	$scriptCode += "sudo restart zookeeper" + $NEWLINE
	$scriptCode += "sudo start mesos-master" + $NEWLINE
	$scriptCode += "sudo start marathon" + $NEWLINE

	$scriptCode += "echo ""Configuration completed.""" + $NEWLINE

	$scriptName = $ScriptDirectory + "\" + $masterMachineNames[$i - 1] + ".sh"
	New-Item $scriptName -type file -force -value $scriptCode
}


# Activate script
(get-content .\Vagrantfile) | foreach-object {$_ -replace "#config.vm.provision", "config.vm.provision"} | set-content .\Vagrantfile

for($i=1; $i -le $masterMachineNames.Length; $i++) {
	Write-Host $NEWLINE + "Provisioning via SSH ... " + $masterMachineNames[$i - 1]
	vagrant provision $masterMachineNames[$i - 1]
}

for($i=1; $i -le $slaveMachineNames.Length; $i++) {
	Write-Host $NEWLINE + "Provisioning via SSH ... " + $slaveMachineNames[$i - 1]
	vagrant provision $slaveMachineNames[$i - 1]
}

# Deactivate script
(get-content .\Vagrantfile) | foreach-object {$_ -replace "config.vm.provision", "#config.vm.provision"} | set-content .\Vagrantfile




