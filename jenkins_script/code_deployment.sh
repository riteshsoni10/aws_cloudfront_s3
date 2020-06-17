#Check if image directory already present
if [ ! -d "/opt/code/images" ]
then
	sudo mkdir /opt/code/images
fi

#Using complete command path, since we don't want to have interactive prompt in case the file already exists in the directory
sudo /bin/cp -ap images/ /opt/code/images/
