# aws_cloudfront_s3
Automated resource creation in AWS Public Cloud using Jenkins to execute terraform code.

# List of Operations Perfomed in this project
1. Create the key and security group which allow the port 80.
2. Launch EC2 instance.
3. In this Ec2 instance use the key and security group which we have created in step 1.
4. Launch one Volume (EBS) and mount that volume into /var/www/html
5. Developer have uploded the code into github repo also the repo has some images.
6. Copy the github repo code into /var/www/html
7. Create S3 bucket, and copy/deploy the images from github repo into the s3 bucket and change the permission to public readable.
8 Create a Cloudfront using s3 bucket(which contains images) and use the Cloudfront URL to  update in code in /var/www/html

*Optional*
1) Those who are familiar with jenkins or are in devops AL have to integrate jenkins in this task wherever you feel can be integrated
2) create snapshot of ebs


### Create IAM User in AWS Account
### Configure the AWS Profile in Jenkins System

Initalising Terraform in workspace Directory

```sh
terraform init 
```

 
<p align="center">
  <img src="/screenshots/terraform_init.png" width="650" title="Initialising Terraform">
  <br>
  <em>Fig 1.: Initialisng Terraform </em>
</p>


## Create Key Pair

Currently Resource Type `aws_key_pair` supports importing an existing key pair but not creating a new key pair. So we will be creating a key pair in local system

We will be storing Keys in /opt/keys directory in Jenkins Host system
```sh
ssh-keygen	-t rsa -C mastersoni121995@gmai.com -f /opt/keys/ec2 -N ""
```

> SSH-Keygen Options 

```
	-t => Encryption Algorithm
	-f Output Key File
	-C Comment
	-N New Passphrase
```

We will be storing the static variables in `terraform.tfvars` file i.e region_name and iam_profile

Terraform loads variables in the following order, with later sources taking precedence over earlier ones:
 - Environment variables
 - The terraform.tfvars file, if present.
 - The terraform.tfvars.json file, if present.
 - Any *.auto.tfvars or *.auto.tfvars.json files, processed in lexical order of their filenames.
 - Any -var and -var-file options on the command line, in the order they are provided. (This includes variables set by a Terraform Cloud workspace.)

HCL Code to create Instance Key-Pair
```sh
#Creating AWS Key Pair for EC2 Instance Login
resource "aws_key_pair" "instance_key_pair"{
        key_name = "automation-key"
        public_key = file("/opt/keys/ec2.pub")
}
```
 
<p align="center">
  <img src="/screenshots/terraform_create_key_pair.png" width="650" title="Create Key Pair">
  <br>
  <em>Fig 1.: Create Key Pair </em>
</p>

 
 ## Create Security  Groups
 
 We will be allowing HTTP protocol and SSH access to our EC2 instance from worldwide.
 
 ```sh
 resource "aws_security_group" "instance_sg" {
  name        = "web_server_ports"
  description = "Apache Web Server Access Ports"

  ingress {
    description = "HTTP Server Access from worldwide"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "SSH Access from worldwide"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    #cidr_blocks = ["0.0.0.0/0"]
    #cidr_blocks = [ file("/opt/ip.txt")]
    cidr_blocks = [ var.automation_public_ip ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "application_security_group"
  }

}
```


 
