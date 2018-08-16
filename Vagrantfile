# -*- mode: ruby -*-
# vi: set ft=ruby :

#------------------------------------------------------------------------------
# VM Environment and parameter configuration
# These settings can be overridden by creating a file named Vagrantfile.local
#------------------------------------------------------------------------------
vm_define="openadr-vtn"
bootstrap_path="bin/bootstrap.sh"
vm_name="OpenADR Virtual Top Node"
basebox_name="ubuntu/bionic64"
no_of_cpus=1
memory_size=2048
vm_gui=false

vm_hostname="openadr-vtn-dev.net"
postgres_version=10
java_version=8
desktop_packages="virtualbox-guest-dkms virtualbox-guest-additions-iso lubuntu-desktop"

# Read any user specific configuration overrides - cater for this file not existing
local_env_config_file="Vagrantfile.local"
begin
  localsettings = File.read local_env_config_file
  eval localsettings
  rescue Errno::ENOENT
    #print "No "+local_env_config_file+" found\n"
end

# Check for required plugin
unless Vagrant.has_plugin?("vagrant-disksize")
  puts 'vagrant-disksize plugin is required. To install run: `vagrant plugin install vagrant-disksize`'
  abort
end

# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.
Vagrant.configure(2) do |config|
  # The most common configuration options are documented and commented below.
  # For a complete reference, please see the online documentation at
  # https://docs.vagrantup.com.
  config.vm.define vm_define

  # Every Vagrant development environment requires a box. You can search for
  # boxes at https://atlas.hashicorp.com/search.
  config.vm.box = basebox_name

  # Use the https://github.com/sprotheroe/vagrant-disksize plugin
  config.disksize.size = '10GB'

  # Forward ports for developer access
  config.vm.network "forwarded_port", guest: 5432, host: 55432
  config.vm.network "forwarded_port", guest: 8080, host: 58080

  # Share an additional folder to the guest VM. The first argument is
  # the path on the host to the actual folder. The second argument is
  # the path on the guest to mount the folder. And the optional third
  # argument is a set of non-required options.
  config.vm.synced_folder ".", "/vagrant", :mount_options => ["dmode=755"]

  config.vm.provider "virtualbox" do |vb|
    vb.gui = vm_gui
    vb.memory = memory_size
    vb.cpus = no_of_cpus
    vb.name = vm_name
  end

  config.vm.provision :shell, path: bootstrap_path, :args => [
      java_version.to_s,
      postgres_version.to_s,
      vm_hostname,
      (vm_gui ? desktop_packages : "")
    ]
end
