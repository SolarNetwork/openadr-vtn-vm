#!/bin/bash

TORQUEBOX_VERSION=3.2.0
TORQUEBOX_URL=http://torquebox.org/release/org/torquebox/torquebox-dist/$TORQUEBOX_VERSION/torquebox-dist-$TORQUEBOX_VERSION-bin.zip

VTN_VERSION=0.9.7
VTN_URL=https://github.com/epri-dev/OpenADR-Virtual-Top-Node/archive/v$VTN_VERSION.tar.gz

# Setup torquebox
if [ ! -d ~/torquebox/torquebox-$TORQUEBOX_VERSION ]; then
	echo -e "\nDownloading Torquebox $TORQUEBOX_VERSION..."
	curl -LsS -o "/var/tmp/openadrdev-torquebox-$TORQUEBOX_VERSION.zip" "$TORQUEBOX_URL"
	if [ $? -eq 0 ]; then
		if [ ! -d ~/torquebox ]; then
			mkdir ~/torquebox
		fi
		unzip "/var/tmp/openadrdev-torquebox-$TORQUEBOX_VERSION.zip" -d ~/torquebox/
		if [ $? -eq 0 ]; then
			rm -f ~/torquebox/current
			ln -sf ~/torquebox/torquebox-$TORQUEBOX_VERSION ~/torquebox/current
			rm -f "/var/tmp/openadrdev-torquebox-$TORQUEBOX_VERSION.zip"
		fi
	fi
fi

grep -q TORQUEBOX_HOME ~/.bashrc
if [ $? -ne 0 ]; then
	echo -e '\nSetting up Torquebox paths in .bashrc file...'
	cat >> ~/.bashrc <<"EOF"

export TORQUEBOX_HOME=~/torquebox/current
export JBOSS_HOME=$TORQUEBOX_HOME/jboss
export JRUBY_HOME=$TORQUEBOX_HOME/jruby
export PATH=$JBOSS_HOME/bin:$JRUBY_HOME/bin:$PATH
export RAILS_ENV=production
EOF
	export TORQUEBOX_HOME=~/torquebox/current
	export JBOSS_HOME=$TORQUEBOX_HOME/jboss
	export JRUBY_HOME=$TORQUEBOX_HOME/jruby
	export PATH=$JBOSS_HOME/bin:$JRUBY_HOME/bin:$PATH
	export RAILS_ENV=production
fi

if [ ! -d ~/OpenADR-Virtual-Top-Node-$VTN_VERSION ]; then
	echo -e "\nDownloading OpenADR VTN $VTN_VERSION..."
	curl -LsS -o "/var/tmp/oadr-$VTN_VERSION.tgz" "$VTN_URL"
	if [ $? -eq 0 ]; then
		tar -xf "/var/tmp/oadr-$VTN_VERSION.tgz" -C ~
		if [ $? -eq 0 ]; then
			ln -sf ~/OpenADR-Virtual-Top-Node-$VTN_VERSION ~/oadr
			rm "/var/tmp/oadr-$VTN_VERSION.tgz"
		fi
	fi
fi


if [ ! -f ~/oadr/config/torquebox.yml ]; then
	cd ~/oadr

	echo -e "\nInstalling rails..."
	gem install rails -v 3.2.12

	echo -e "\nInstalling ruby bundles..."
	bundle install

	echo -e "\nRunning rake assets:precompile; this can take quite some time..."
	bundle exec rake assets:precompile

	cp config/torquebox.yml.example config/torquebox.yml

	if [ ! -f config/database.yml ]; then
		echo -e "\nCreating database.yml..."
		cp config/database.yml.example config/database.yml
	fi

	if [ ! -f config/initializers/secret_token.rb ]; then
		echo -e "\nCreating secret_token.rb..."
		sed "s/place token here/$(bundle exec rake secret 2>/dev/null)/" config/initializers/secret_token.rb.example \
			>config/initializers/secret_token.rb
	fi

	# For some reason, the db:seed task below fails with an error from the
	# app/models/ven.rb file. After some tinkering, I found that by commenting
	# out the `name:` argument to the create() function, the error went away.
	if [ ! -f app/models/ven.rb.orig ]; then
		echo -e "\nModifying app/models/ven.rb to fix db:seed issue..."
		sed '/created_target = targets\.create(name: "VEN:#{ id }", type/s/\(name: "VEN:#{ id }",\)/#\1\n    \t/' \
			 app/models/ven.rb >app/models/ven.rb.new
		if [ $? -eq 0 ]; then
			mv app/models/ven.rb app/models/ven.rb.orig
			mv app/models/ven.rb.new app/models/ven.rb
			echo 'Original app/models/ven.rb saved as app/models/ven.rb.orig'
		fi
	fi

	echo -e "\nRunning rake db:setup..."
	bundle exec rake db:setup

	echo -e "\nRunning rake db:seed..."
	bundle exec rake db:seed

	echo -e "\nDeploying to torquebox..."
	torquebox deploy
fi
