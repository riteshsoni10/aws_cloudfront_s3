# Check if infra directory already present
if [ ! -d "/opt/aws_infra" ]
then
	sudo mkdir /opt/aws_infra
fi

#Using complete command path, since we don't want to have interactive prompt in case the file already exists in the directory
sudo /bin/cp -ap automation_script/ /opt/aws_infra

cd /opt/aws_infra

#Initialising Terraform and Creating infrastructure.
#Note: AWS IAM credentials to be configured before hand in Jenkins Server
terraform init
terraform apply -auto-approve