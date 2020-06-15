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


The website code that is used in this repository for deployment on EC2 web server Github URL[https://github.com/riteshsoni10/demo_website.git]

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


## Launch EC2 instance

We are going to launch the EC2 instance with the Key and security group generated above. For now, we will be using the Amazon Linux AMI i.e` ami-005956c5f0f757d37`.

```sh
#Creating EC2 instance
resource "aws_instance" "web_server" {
        ami = "ami-005956c5f0f757d37"
        instance_type = var.instance_type
        security_groups = [aws_security_group.instance_sg.name]
        key_name = aws_key_pair.instance_key_pair.key_name
}
```

 
<p align="center">
  <img src="/screenshots/terraform_create_key_pair.png" width="650" title="Create Key Pair">
  <br>
  <em>Fig .: Launching EC2 instance </em>
</p>


## Create EBS Volume

We will be creating EBS volume for data persistency i.e for permanent storage of our website code. The EBS volume should be launched in the same availability zone as the EC2 instance, otherwise the volume will not be attachable normally.

```sh
resource "aws_ebs_volume" "web_server_volume" {
        availability_zone = aws_instance.web_server.availability_zone
        size              = 1
        tags = {
                Name = "Web-Server"
        }
}
```

> Parameters:
```
	availability_zone => Availability Zone for the EBS Volume creation
	size              => It defines the Volume Hard disk size requested
```

Attaching EBS Volume to the launched EC2 instance

```sh
resource "aws_volume_attachment" "ec2_volume_attach" {
        device_name = "/dev/sdf"
        volume_id   = aws_ebs_volume.web_server_volume.id
        instance_id = aws_instance.web_server.id
        force_detach = true
}
```

> Parameters:
```
	device_name => The device name to expose to the instance
	volume_id   => The Id of the EBS Volume Created
	instance_id => Instance id of already launched instance
	force_detach => This Option helps during teraing down of infrastructure, if the EBS volume is busy
```


## Configuration changes using Ansible Automation

We will be using automation of configuration changes i.e *installation* of packages, *clone* of code from github, *format* the EBS volume and *mount* it to */var/www/html*. The automation script is uploaded in the repository with name "configuration.yml". 

The `local-exec` provisioner is used to invoke the ansible-playbook i.e ansible should be installed on the controller node. The provisioner should **always be inside a resource** block. So, if no resource is to be launched, then resource type `null_resource` comes to our rescue.

```sh
resource  "null_resource" "invoke_playbook"{
	provisioner local-exec {
		command = "ansible-playbook -u ${var.connection_user} -i ${aws_instance.web_server.public_ip},\
		--private-key /opt/keys/ec2 configuration.yml  --ssh-extra-args=\"-o stricthostkeychecking=no\""
	}
}
```

For code modularity, and clarification all the values are stored in `variables.tf` file and the values can be passed using `terraform.tf` file which the terraform loads and reads the values defined for the variables.

>Parameters:
```
	command => to run or execute any command on the controller node, 
	on condition that the command binary is installed or configured in the node controller system
```

`--ssh-extra-args="-o stricthostkeychecking=no"`, parameter is configured to disable HostKeyChecking during Automation.

The `remote-exec` provisioner is used to install python package required for automatio suing ansible. The null_resource of remote-exec is always executed first before any resource, i.e it takes precedence over other resource type. So, we need to tell or define the resource type on which the remote-exec provisioner depends, for example; in our scenario it depends on EBS volume attachment since we are executing local-exec and remote-exec in one resource block.

The remote-exec provisioner requires connection object to connect to the remote system launched.

```sh
resource  "null_resource" "invoke_playbook"{
        depends_on = [
                aws_volume_attachment.ec2_volume_attach,
        ]
        connection{
                type = var.connection_type
                host = aws_instance.web_server.public_ip
                user  = var.connection_user
                private_key = file("/opt/keys/ec2")
        }

        provisioner remote-exec {
                inline =[
                        "sudo yum install python36 -y"
		]
	}
}                                                 
```
> Parameters
```
	type        => Connection type i.e ssh (for Linux Operating System) or winRM (for Windows Operating System)
	host        => Public IP or domain name of the remote system
	user        => Username for the login
	private_key => For authentication of the user. 
```
We can also use **password** in case, we have configured password based authentication rather than Key Based authentication for User login

In `remote-exec` provisioners, we can use any one of following attributes: 

1. inline

	It helps in providing commands in combination of multiple lines
2. script  

	Path of local script, that is to be copied to remote system and then executed.
3. scripts 
	
	List of scripts that will be copied to remote system and then executed on remote.


## S3 Bucket

Create S3 bucket to serve images from S3 rather than from EC2 instance. The resource type `aws_s3_bucket` is used to create the S3 bucket.

```sh
resource "aws_s3_bucket" "s3_image_store" {
        bucket = var.s3_image_bucket_name
        acl = var.bucket_acl
        tags = {
                Name = "WebPage Image Source"
        }
        region = var.region_name
        force_destroy = var.force_destroy_bucket
}
```

>Parameters:
```
	bucket        => The Bucket name 
	acl           => The ACL for the objects stored in the bucket,
	region        => The region in which the S3 bucket will be created
	force_destroy => This boolean parameter, deletes all the objects in the bucket during tearing down of infrastructure.
			Do not use this parameter in PRODUCTION environment
```

## Upload Images to S3 bucket

The Images stored in the wbsite code repository, is uploaded in S3 for serving the images from Cloudfront. Content Delivery Network helps in lowering the latency of accessing of objects i.e image access time will be reduced, if accessed from another region.

For uploading the images, we will be cloning the repository in current workspace using `local-exec` provisioner and then will be uploading only the images to the S3 bucket

```sh
resource "null_resource" "download_website_code"{
        depends_on = [
                aws_s3_bucket.s3_image_store
        ]
        provisioner local-exec {
                command = "git clone https://github.com/riteshsoni10/demo_website.git"
        }
}
```

Uploading all the images to S3 Bucket
```sh
resource "aws_s3_bucket_object" "website_image_files" {
        depends_on = [
                null_resource.download_website_code
        ]
        for_each      = fileset("demo_website/images/", "**/*.*")
        bucket        = aws_s3_bucket.s3_image_store.bucket
        key           = replace(each.value, "demo_website/images/", "")
        source        = "demo_website/images/${each.value}"
        acl           = "public-read"
        etag          = filemd5("demo_website/images/${each.value}")
}
```

>Paramters:
```
	for_each =>  to get list of all the images
	bucket   => Name of the bucket to upload the images
	key      => The file name on S3 after uploading the image
	source   => The source of the images
	acl      => The Access Control on the images
	etag     => To keep in track the and alwways upload data as soon as it changes
```
