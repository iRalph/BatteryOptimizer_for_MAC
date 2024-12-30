#!/bin/bash

function write_config() { # write $val to $name in config_file
	name=$1
	val=$2
	if test -f $config_file; then
		config=$(cat $config_file 2>/dev/null)
		name_loc=$(echo "$config" | grep -n "$name" | cut -d: -f1)
		if [[ $name_loc ]]; then
			sed -i '' ''"$name_loc"'s/.*/'"$name"' = '"$val"'/' $config_file
		else # not exist yet
			echo "$name = $val" >> $config_file
		fi
	fi
}

# User welcome message
echo -e "\n####################################################################"
echo '# 👋 Welcome, this is the setup script for the battery CLI tool.'
echo -e "# Note: this script will ask for your password once or multiple times."
echo -e "####################################################################\n\n"

# Set environment variables
tempfolder=~/.battery-tmp
binfolder=/usr/local/bin
mkdir -p $tempfolder

# Set script value
calling_user=${1:-"$USER"}
configfolder=/Users/$calling_user/.battery
config_file=$configfolder/config_battery
pidfile=$configfolder/battery.pid
logfile=$configfolder/battery.log

# Ask for sudo once, in most systems this will cache the permissions for a bit
sudo echo "🔋 Starting battery installation"
echo -e "[ 1 ] Superuser permissions acquired."

# check CPU type
if [[ $(sysctl -n machdep.cpu.brand_string) == *"Intel"* ]]; then
    cpu_type="intel"
else
    cpu_type="apple"
fi

# Note: github names zips by <reponame>-<branchname>.replace( '/', '-' )
update_branch="customized"
in_zip_folder_name="BatteryOptimizer_for_MAC-$update_branch"
batteryfolder="$tempfolder/battery"
echo "[ 2 ] Downloading latest version of battery CLI"
rm -rf $batteryfolder
mkdir -p $batteryfolder
curl -sSL -o $batteryfolder/repo.zip "https://github.com/iRalph/BatteryOptimizer_for_MAC/archive/refs/heads/$update_branch.zip"
unzip -qq $batteryfolder/repo.zip -d $batteryfolder
cp -r $batteryfolder/$in_zip_folder_name/* $batteryfolder
rm $batteryfolder/repo.zip

# Move built file to bin folder
echo "[ 3 ] Move smc to executable folder"
sudo mkdir -p $binfolder
if [[ $cpu_type == "apple" ]]; then
	sudo cp $batteryfolder/dist/smc $binfolder/smc
else
	sudo cp $batteryfolder/dist/smc_intel $binfolder/smc
fi
sudo chown $calling_user $binfolder/smc
sudo chmod 755 $binfolder/smc
sudo chmod +x $binfolder/smc
# Check if smc works
check_smc=$(smc 2>&1)
if [[ $check_smc =~ " Bad " ]] || [[ $check_smc =~ " bad " ]] ; then # current is not a right version
	sudo cp $batteryfolder/dist/smc_intel $binfolder/smc
	sudo chown $USER $binfolder/smc
	sudo chmod 755 $binfolder/smc
	sudo chmod +x $binfolder/smc
	# check again
	check_smc=$(smc 2>&1)
	if [[ $check_smc =~ " Bad " ]] || [[ $check_smc =~ " bad " ]] ; then # current is not a right version
		echo "Error: BatteryOptimizer seems not compatible with your MAC yet"
		exit
	fi
fi

echo "[ 4 ] Writing script to $binfolder/battery for user $calling_user"
sudo cp $batteryfolder/battery.sh $binfolder/battery

echo "[ 5 ] Setting correct file permissions for $calling_user"
# Set permissions for battery executables
sudo chown -R $calling_user $binfolder/battery
sudo chmod 755 $binfolder/battery
sudo chmod +x $binfolder/battery

# Set permissions for logfiles
mkdir -p $configfolder
sudo chown -R $calling_user $configfolder

touch $logfile
sudo chown $calling_user $logfile
sudo chmod 755 $logfile

touch $pidfile
sudo chown $calling_user $pidfile
sudo chmod 755 $pidfile

sudo chown $calling_user $binfolder/battery

echo "[ 6 ] Setting up visudo declarations"
sudo $batteryfolder/battery.sh visudo $USER
sudo chown -R $calling_user $configfolder

# Run battery maintain with default percentage 80
echo "[ 7 ] Set default battery maintain percentage to 80%, can be changed afterwards"
# Setup configuration file
version=$(echo $(battery version))
touch $config_file
write_config calibrate_method 1
write_config calibrate_schedule
write_config calibrate_next
write_config informed_version $version
write_config language
write_config maintain_percentage
write_config daily_last
write_config clamshell_discharge
write_config webhookid

$binfolder/battery maintain 80 >/dev/null &

# Remove tempfiles
cd ../..
echo "[ Final ] Removing temp folder $tempfolder"
rm -rf $tempfolder

#echo -e "\n🎉 Battery tool installed. Type \"battery help\" for instructions.\n"
