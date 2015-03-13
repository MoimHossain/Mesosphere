## Mesosphere cluster on Azure

[vagrant](https://roslyn.codeplex.com) has to be installed on a windows machine to run the scripts.

This repository contains two groups of scripts. 

### Mesos-Ubuntu

Clone this folder in a Windows machine and navigate to the folder and do a `vagrant up`. It will create a 3 mesos master (zookeeper on all of them) machines and 3 mesos slave machines using the Virtual Box provider.

### Mesos-Azure

Clone this folder in a Windows machine and navigate to the folder and do a `./light.ps1` on your powershell console. It will create a 3 mesos master (zookeeper on all of them) machines and 3 mesos slave machines using the Vagrant-Azure provider on your azure subscription.

You need to provide your Azure certificate though into the Vagrantfile.
