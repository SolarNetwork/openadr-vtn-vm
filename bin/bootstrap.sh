#!/bin/bash

JAVAVER=$1
PGVER=$2
HOST=$3
DESKTOP_PACKAGES=$6

# Expand root
sudo resize2fs /dev/sda1

# Apply local settings
if [ -d /vagrant/local-root ]; then
	echo "Copying local VM settings from local-root directory..."
	sudo cp -Rv /vagrant/local-root/* /
fi

# Setup hostname
grep -q $HOST /etc/hostname
if [ $? -ne 0 ]; then
	echo "Setting up $HOST hostname"
	echo $HOST >>/tmp/hostname.new
	chmod 644 /tmp/hostname.new
	sudo chown root:root /tmp/hostname.new
	sudo cp -a /etc/hostname /etc/hostname.bak
	sudo mv -f /tmp/hostname.new /etc/hostname

	sudo hostname $HOST
fi

# Setup DNS to resolve hostname
grep -q $HOST /etc/hosts
if [ $? -ne 0 ]; then
	echo "Setting up $HOST host entry"
	sed "s/^127.0.0.1[[:space:]]*localhost/127.0.0.1 $HOST localhost/" /etc/hosts >/tmp/hosts.new
	if [ -z "$(diff /etc/hosts /tmp/hosts.new)" ]; then
		# didn't change anything, try 127.0.1.0
		sed "s/^127.0.1.1.*/127.0.1.1 $HOST/" /etc/hosts >/tmp/hosts.new
	fi
	if [ "$(diff /etc/hosts /tmp/hosts.new)" ]; then
		chmod 644 /tmp/hosts.new
		sudo chown root:root /tmp/hosts.new
		sudo cp -a /etc/hosts /etc/hosts.bak
		sudo mv -f /tmp/hosts.new /etc/hosts
	fi
fi

grep -q '/swapfile' /etc/fstab
if [ $? -ne 0 ]; then
	echo -e '\nCreating swapfile...'
	sudo fallocate -l 1G /swapfile
	sudo chmod 600 /swapfile
	sudo mkswap /swapfile
	sudo swapon /swapfile
	echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
fi

echo -e '\nUpdating package cache...'
sudo apt-get update

echo -e '\nUpgrading outdated packages...'
sudo apt-get upgrade -y

echo -e '\nInstalling language-pack...'
sudo apt-get install -y language-pack-en

if [ -n "$DESKTOP_PACKAGES" ]; then
	echo -e "\nInstalling Desktop Packages: $DESKTOP_PACKAGES"
	sudo apt-get install -y $DESKTOP_PACKAGES
fi

echo -e "\nInstalling Postgres $PGVER and Java $JAVAVER..."
javaPkg=openjdk-$JAVAVER-jdk
if [ -z "$DESKTOP_PACKAGES" ]; then
	javaPkg="${javaPkg}-headless"
fi
sudo apt-get install -y postgresql-$PGVER postgresql-contrib-$PGVER $javaPkg git git-flow unzip

# Add the oadrdev user if it doesn't already exist, password oadrdev
getent passwd oadrdev >/dev/null
if [ $? -ne 0 ]; then
	echo -e '\nAdding oadrdev user.'
	sudo useradd -c 'OpenADR Developer' -s /bin/bash -m -U oadrdev
	sudo sh -c 'echo "oadrdev:oadrdev" |chpasswd'
fi

sudo grep -q 'epri_oadr oadrdev' /etc/postgresql/$PGVER/main/pg_ident.conf
if [ $? -ne 0 ]; then
	echo -e '\nConfiguring Postgres oadrdev user mapping...'
	sudo sh -c "echo \"openadr oadrdev epri\" >> /etc/postgresql/$PGVER/main/pg_ident.conf"
	sudo service postgresql restart
fi

sudo grep -q epri_oadr /etc/postgresql/$PGVER/main/pg_hba.conf
if [ $? -ne 0 -a -e /vagrant/pg_hba.sed ]; then
	echo -e '\nConfiguring Postgres OpenADR user access...'
	sudo sh -c "sed -f /vagrant/pg_hba.sed /etc/postgresql/$PGVER/main/pg_hba.conf > /etc/postgresql/$PGVER/main/pg_hba.conf.new"
	sudo chown postgres:postgres /etc/postgresql/$PGVER/main/pg_hba.conf.new
	sudo chmod 640 /etc/postgresql/$PGVER/main/pg_hba.conf.new
	sudo mv /etc/postgresql/$PGVER/main/pg_hba.conf /etc/postgresql/$PGVER/main/pg_hba.conf.orig
	sudo mv /etc/postgresql/$PGVER/main/pg_hba.conf.new /etc/postgresql/$PGVER/main/pg_hba.conf
	sudo service postgresql restart
fi

sudo grep -q "listen_addresses = '\*'" /etc/postgresql/$PGVER/main/postgresql.conf
if [ $? -ne 0 ]; then
	echo -e '\nConfiguring Postgres to listen on all addresses...'
	sudo sed "/^#listen_addresses/s/#listen_addresses = 'localhost'/listen_addresses = '*'/" \
		/etc/postgresql/$PGVER/main/postgresql.conf \
		>/etc/postgresql/$PGVER/main/postgresql.conf.new
	sudo chown postgres:postgres /etc/postgresql/$PGVER/main/postgresql.conf.new
	sudo chmod 644 /etc/postgresql/$PGVER/main/postgresql.conf.new
	sudo mv /etc/postgresql/$PGVER/main/postgresql.conf /etc/postgresql/$PGVER/main/postgresql.conf.orig
	sudo mv /etc/postgresql/$PGVER/main/postgresql.conf.new /etc/postgresql/$PGVER/main/postgresql.conf
	sudo service postgresql restart
fi

sudo -u postgres sh -c "psql -d epri_oadr -c 'SELECT now()'" >/dev/null 2>&1
if [ $? -ne 0 ]; then
	echo -e '\nCreating epri_oadr Postgres database...'
	sudo -u postgres createuser -AD epri
	sudo -u postgres psql -U postgres -d postgres -c "alter user epri with password 'epri';"
	sudo -u postgres createdb -E UNICODE -l C -T template0 -O epri epri_oadr
fi

if [ ! -e /etc/sudoers.d/oadrdev -a -e /vagrant/oadrdev.sudoers ]; then
	echo -e '\nCreating sudoers file for oarddev user...'
	sudo cp /vagrant/oadrdev.sudoers /etc/sudoers.d/oadrdev
	sudo chmod 644 /etc/sudoers.d/oadrdev
fi

# Configure the linux installation
if [ -x /vagrant/bin/oadrdev.sh ]; then
	sudo -i -u oadrdev /vagrant/bin/oadrdev.sh
fi

if [ -e /home/oadrdev/torquebox/current/jboss -a ! -f /etc/systemd/system/oadr-vtn.service -a -f /vagrant/oadr-vtn.service ]; then
	echo -e "\nCreating OpenADR VTN service..."
	sudo cp /vagrant/oadr-vtn.service /etc/systemd/system/oadr-vtn.service
	sudo systemctl daemon-reload
	sudo systemctl enable oadr-vtn.service
	sudo systemctl start oadr-vtn.service
fi

# Success messages
if [[ "$DESKTOP_PACKAGES" == *"virtualbox-guest-dkms"*  ]]; then
  # if virtualbox-guest-dkms is included reconfigure so that the desktop will scale when resized
  echo -e "\nReconfiguring virtualbox-guest-dkms\n"
  sudo dpkg-reconfigure virtualbox-guest-dkms

  cat <<"EOF"

--------------------------------------------------------------------------------
OpenADR development environment setup complete, rebooting VM.

Once restarted log into the VM as oadrdev:oadrdev.

NOTE: If the desktop fails to auto scale first try rebooting the VM,
if that doesn't work manually run : "sudo dpkg-reconfigure virtualbox-guest-dkms"
then restart the VM.
EOF

  # Restart the VM to show the desktop
  sudo reboot

else
  cat <<"EOF"

--------------------------------------------------------------------------------
OpenADR development environment setup complete.

Log into the VM as oadrdev:oadrdev. The VTN database is `epri_oadr` and can be
accessed using Postgres tools as epri:epri.
EOF
fi
