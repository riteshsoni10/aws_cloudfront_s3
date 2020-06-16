# Public Cloud (AWS) Infrastructure Automation

Automated resource creation in AWS Public Cloud using Jenkins to execute terraform code.

<p align="center">
  <img src="/screenshots/infra_flow.png" width="950" title="Infrastructure Flow">
  <br>
  <em>Fig 1.: Project Flow Diagram </em>
</p>

## Scope of this project
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


The **website code** that is used in this repository for *deployment* on EC2 web server [Github URL](https://github.com/riteshsoni10/demo_website.git)

 	
## Package Pre-Requisites
- awscli 
- terraform
- git


### Create IAM User in AWS Account

1. Login using root account into AWS Console
2. Go to IAM Service

<p align="center">
  <img src="/screenshots/iam_user_creation.png" width="950" title="IAM Service">
  <br>
  <em>Fig 2.: IAM User creation </em>
</p>

3. Click on User
4. Add User
5. Enable Access type `Programmatic Access`

<p align="center">
  <img src="/screenshots/iam_user_details.png" width="950" title="Add User">
  <br>
  <em>Fig 3.: Add new User </em>
</p>

6. Attach Policies to the account
	For now, you can click on `Attach existing policies directly` and attach `Administrator Access`

<p align="center">
  <img src="/screenshots/iam_user_policy_attach.png" width="950" title="User Policies">
  <br>
  <em>Fig 4.: IAM User policies </em>
</p>

7. Copy Access and Secret Key Credentials


### Configure the AWS Profile in Controller Node

The best and secure way to configure AWS Secret and Access Key is by using aws cli on the controller node

```sh
aws configure --profile <profile_name>
```

<p align="center">
  <img src="/screenshots/aws_profile_creation.png" width="950" title="AWS Profile">
  <br>
  <em>Fig 5.: Configure AWS Profile </em>
</p>


**Initalising Terraform in workspace Directory**

```sh
terraform init 
```

 
<p align="center">
  <img src="/screenshots/terraform_init.png" width="950" title="Initialising Terraform">
  <br>
  <em>Fig 6.: Initialisng Terraform </em>
</p>


### Create Key Pair

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

<p align="center">
  <img src="/screenshots/key_pair_generation.png" width="950" title="SSH-Keygen SSH Key Pair">
  <br>
  <em>Fig 7.: SSH Keygen Key Pair </em>
</p>


Terraform Validate to check for any syntax errors in Terraform Configuration file

```sh
terraform validate
```

<p align="center">
  <img src="/screenshots/terraform_validate.png" width="950" title="Syntax Validation">
  <br>
  <em>Fig 8.: Terraform Validate </em>
</p>


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
  <img src="/screenshots/terraform_create_key_pair.png" width="950" title="Create Key Pair">
  <br>
  <em>Fig 9.: Create Key Pair </em>
</p>

 
 ### Create Security  Groups
 
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


### Launch EC2 instance

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
  <img src="/screenshots/terraform_create_ec2_instance.png" width="950" title="Create EC2 instance">
  <br>
  <em>Fig 10.: Launching EC2 instance </em>
</p>


### Create EBS Volume

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


<p align="center">
  <img src="/screenshots/terraform_create_ebs_volume.png" width="950" title="EBS Volume">
  <br>
  <em>Fig 11.: Create EBS Volume </em>
</p>


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


### Configuration changes using Ansible Automation

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

<p align="center">
  <img src="/screenshots/terraform_install_python3_in_remote.png" width="950" title="Automation using Ansible">
  <br>
  <em>Fig 12.: Installation of Python Packages </em>
</p>


In `remote-exec` provisioners, we can use any one of following attributes: 

1. inline

	It helps in providing commands in combination of multiple lines
2. script  

	Path of local script, that is to be copied to remote system and then executed.
3. scripts 
	
	List of scripts that will be copied to remote system and then executed on remote.


<p align="center">
  <img src="/screenshots/terraform_invoke_ansible_playbook.png" width="950" title="Automation using Ansible">
  <br>
  <em>Fig 13.: Configuration and Installation of Web Server Packages </em>
</p>


### S3 Bucket

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
	force_destroy => This boolean parameter, deletes all the objects in the bucket during tearing down
			 of infrastructure. Do not use this parameter in PRODUCTION environment
```


### Upload Images to S3 bucket

The Images stored in the wbsite code repository, is uploaded in S3 for serving the images from Cloudfront. Content Delivery Network helps in lowering the latency of accessing of objects i.e image access time will be reduced, if accessed from another region.

For uploading the images, we will be cloning the repository in current workspace using `local-exec` provisioner and then will be uploading only the images to the S3 bucket OR we can configure Jenkins Job to clone the repository for us.

```sh
resource "null_resource" "download_website_code"{
        depends_on = [
                aws_s3_bucket.s3_image_store
        ]
        provisioner local-exec {
                command =
		"rm -rf /opt/code/*"
		"git clone https://github.com/riteshsoni10/demo_website.git /opt/code/"
        }
}
```

Uploading all the images to S3 Bucket
```sh
resource "aws_s3_bucket_object" "website_image_files" {
        depends_on = [
                null_resource.download_website_code
        ]
        for_each      = fileset("/opt/code/images/", "**/*.*")
        bucket        = aws_s3_bucket.s3_image_store.bucket
        key           = replace(each.value, "/opt/code/images/", "")
        source        = "/opt/code/images/${each.value}"
        acl           = "public-read"
        etag          = filemd5("/opt/code/images/${each.value}")
}
```

>Parameters:
```
	for_each =>  to get list of all the images
	bucket   => Name of the bucket to upload the images
	key      => The file name on S3 after uploading the image
	source   => The source of the images
	acl      => The Access Control on the images
	etag     => To keep in track the and alwways upload data as soon as it changes
```


<p align="center">
  <img src="/screenshots/terraform_upload_images.png" width="950" title="Upload Images">
  <br>
  <em>Fig 14.: Upload Images (Terraform Plan) </em>
</p>


<p align="center">
  <img src="/screenshots/terraform_upload_images_success.png" width="950" title="Upload Images">
  <br>
  <em>Fig 15.: Upload Images (Terraform Apply) </em>
</p>


### CloudFront Distribution

Content Delivery Network as Service is provided using CloudFront in AWS Public Cloud. The cloudfront distribution is created to serve the images stored in S3 bucket with the lower latency across the globe. 

First we will be creating Origin Access Identity, which will be helpfulin hiding S3 endpoint publicly to the world.

```sh
resource "aws_cloudfront_origin_access_identity" "s3_objects" {
        comment = "S3-Images-Source"
}
```

Create Cloudfront Distribution

The Web Cloudfront Distribution is created to serve objects over http or https protocol.

```sh
resource "aws_cloudfront_distribution" "image_distribution" {
        depends_on = [
                aws_s3_bucket.s3_image_store
        ]
        origin {
                domain_name = aws_s3_bucket.s3_image_store.bucket_regional_domain_name
                origin_id = var.s3_origin_id
                s3_origin_config {
                  origin_access_identity = aws_cloudfront_origin_access_identity.s3_objects.cloudfront_access_identity_path
                }
        }
        enabled = var.enabled
        is_ipv6_enabled = var.ipv6_enabled
        default_cache_behavior {
                allowed_methods  = var.cache_allowed_methods
                cached_methods   = var.cached_methods
                target_origin_id = var.s3_origin_id
                forwarded_values {
                        query_string = false
                        cookies {
                                forward = "none"
                        }
                }
                viewer_protocol_policy =  var.viewer_protocol_policy
                min_ttl                = var.min_ttl
                default_ttl            = var.default_ttl
                max_ttl                = var.max_ttl
                compress               = var.compression_objects_enable
        }
        wait_for_deployment = var.wait_for_deployment
        price_class = var.price_class
        restrictions {
                geo_restriction {
                        restriction_type = var.geo_restriction_type
                        locations        = var.geo_restriction_locations
                }
        }
        tags = {
                Environment = "test-Environment"
        }
        viewer_certificate {
                 cloudfront_default_certificate = true
        }

}
```

>Parameters:
```
	origin              => Configuration for the origin. It can be S3, ELB, EC2 instance etc.
	domain_name         => domain name over which the origin can accessed
	geo_restriction     => The website or the content delivered using CDN can be blocked or 
				whitelisted in certain countries.
	price_class         => Determines the deployment of code in edge_locations
	viewer_certificate  => SSL Certificate  for the viewer access. 
	wait_for_deployment => Boolean Parameter to wait until the Distribution status is deployed
```

We have used Cloudfront's, but custom aliases and SSL certificates can also be used


### Configure Wesbite to use CDN domain 

We will be using remote-exec provisioner to replace the src with CDN domain name. The resource will be dependent on CDN and invoke playbook resource

```sh
resource "null_resource" "configure_image_url" {
        depends_on = [
                aws_cloudfront_distribution.image_distribution, null_resource.invoke_playbook
        ]
        connection{
                type = var.connection_type
                host = aws_instance.web_server.public_ip
                user  = var.connection_user
                private_key = file("/opt/keys/ec2")
        }

        provisioner remote-exec {
                inline =[
                        "grep -rli 'images' * | xargs -i sed -i \ 
			's+images+https://${aws_cloudfront_distribution.image_distribution.domain_name}+g' "
                ]
        }
}
```


# Usage Instructions
You should have configured IAM profile in the controller node by following instructions.

1. Clone this repository
2. Change the working directory to `automation_script`
3. Run `terraform init`
4. Then, `terraform plan`, to see the list of resources that will be created
5. Then, `terraform apply -auto-approve`

When you are done playing
```sh
terraform destroy -auto-approve
```



## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| region_name | Default Region Name for Infrastructure and S3 Bucket | string | `` | yes |
| user_profile | IAM Credentials of AWS Account with required priviledges | string | `` | yes |
| instance_ami_id | AMI Id for launching EC2 Instances | string | `` | yes |
| instance_type | EC2 Instance Type | string | `` | yes |
| automation_public_ip | Controller Node Public IP to allow ssh connection on EC2 instance | string | `0.0.0.0/0` | no |
| connection_user | Username for SSH connection to EC2 instance | string | `ec2-user` | yes |
| connection_type | Type of connection for remote-exec provisioner like (ssh,winrm) | string | `ssh` | no |
| s3_image_bucket_name | S3 bucket name | string | `` | yes |
| force_destroy_bucket | Delete all objects from the bucket so that the bucket can be destroyed without error (e.g. `true` or `false`) | bool | `true` | no |
| s3_origin_id | S3 Origin Name for Cloudfront Distribution | string | `` | yes |
| bucket_acl | ACL Permissions for S3 bucket | string | `private` | no |
| cache_allowed_methods | List of allowed methods (e.g. GET, PUT, POST, DELETE, HEAD) for AWS CloudFront | list(string) | `<list>` | no |
| cached_methods | List of cached methods (e.g. GET, PUT, POST, DELETE, HEAD) | list(string) | `<list>` | no |
| compression_objects_enable | Parameter for compression of content served using Cloudfront Distribution for web requests | bool | `true` | no |
| default_ttl | Default amount of time (in seconds) that an object is in a CloudFront cache | number | `60` | no |
| max_ttl | Maximum amount of time (in seconds) that an object is in a CloudFront cache | number | `31536000` | no |
| min_ttl | Minimum amount of time that you want objects to stay in CloudFront caches | number | `0` | no |
| enabled | Select Enabled if you want CloudFront to begin processing requests as soon as the distribution is created, or select Disabled if you do not want CloudFront to begin processing requests after the distribution is created. | bool | `true` | no |
| ipv6_enabled | Set to true to ipv6 | bool | `true` | no |
| geo_restriction_locations | List of country codes for which  CloudFront either to distribute content (whitelist) or not distribute your content (blacklist) | list(string) | `<list>` | no |
| geo_restriction_type | Method that use to restrict distribution of your content by country: `none`, `whitelist`, or `blacklist` | string | `none` | no |
| price_class | Price class for this distribution: `PriceClass_All`, `PriceClass_200`, `PriceClass_100` | string | `PriceClass_ALL` | no |
| viewer_protocol_policy | allow-all, redirect-to-https | string | `redirect-to-https` | no |
| wait_for_deployment | When set to 'true' the resource will wait for the distribution status to change from InProgress to Deployed | bool | `true` | no |


## Outputs

| Name | Description |
|------|-------------|
| instance_key | Key Pair Name used during launching EC2 instance |
| security_group_name | Name of Security Group Attached with EC2 instance |
| ec2_instance_public_ip | Public IP of EC2 instance |
| ebs_volume |ID of EBS Volume |
| s3_bucket | Name of S3 bucket |
| s3_bucket_domain_name | Domain of S3 bucket |
| cf_id | ID of AWS CloudFront distribution |
| cf_status | Current status of the distribution |
| cf_domain_name | Domain name corresponding to the distribution |


Now, if you want to get yourself relieved from all the manual terraform commands. **Let's integrate Terraform with Jenkins**.

## Integration of Jenkins with Terraform

1. Create a Job to copy images from the code repository
2. Create a Job for AWS Infrastructure Automation

### Job1: Code Deployment

1. Create new Freestyle Job with name code_deployment

<p align="center">
  <img src="/screenshots/code_deployment.png" width="950" title="Code Deployment Job">
  <br>
  <em>Fig 16.: Job Creation </em>
</p>

2. Configure Project URL

<p align="center">
  <img src="/screenshots/code_deployment_project_description.png" width="950" title="Project URL Configuration">
  <br>
  <em>Fig 17.: Project URL Configuration </em>
</p>

3. Configure Git SCM 

<p align="center">
  <img src="/screenshots/code_deployment_project_description.png" width="950" title="Github Repository Configuration">
  <br>
  <em>Fig 18.:  GitHub Repository Configuration </em>
</p>

4. Configure Build Triggers

Currently we don't have public connectivity from Github to local Jenkins Server. So, we will be using *Poll SCM* as trigger.

<p align="center">
  <img src="/screenshots/code_deployment_build_triggers.png" width="950" title="Build Trigger Configuration">
  <br>
  <em>Fig 19.:  Build Trigger Configuration </em>
</p>

5. Build Step

Click on `Execute Shell` form the `Add Build Step` dropdown. The Bash script is present in the repository at location *jenkins_script/code_deployment.sh*

<p align="center">
  <img src="/screenshots/code_deployment_build_step.png" width="950" title="Build Step Configuration">
  <br>
  <em>Fig 20.:  Build Step Configuration </em>
</p>

6. Save and Apply

## Job2 : Infrastructure Deployement

1. Same as in `Job1`

2. Configure Project URL

<p align="center">
  <img src="/screenshots/infrastructure_deployment_description.png" width="950" title="Project URL">
  <br>
  <em>Fig 21.:  Project URL </em>
</p>

3. Git Configuration

<p align="center">
  <img src="/screenshots/infrastructure_deployment_scm.png" width="950" title="SCM">
  <br>
  <em>Fig 22.:  Source Code Management </em>
</p>

4. Build Trigger

	The job will be triggered only on successful/stable execution of `code_deployment` Job.
	
<p align="center">
  <img src="/screenshots/infrastructure_deployment_build_trigger.png" width="950" title="Build Trigger Configuration">
  <br>
  <em>Fig 23.:  Build Trigger Configuration </em>
</p>

5. Build Step

	In Build Step we will be copying our automation code in `/opt/aws_infra` directory. The directory will help us in maintaining the terraform state. We can also upload the terraform state to S3 and utilise whenver a build is triggered. The bash script is present in repository at location *jenkins_script/infrastructure_deployment.sh*
	
<p align="center">
  <img src="/screenshots/infrastructure_deployment_build.png" width="950" title="Build Step Configuration">
  <br>
  <em>Fig 20.:  Build Step </em>
</p>

6. Save and Apply


> **Source**: LinuxWorld Informatics Pvt Ltd. Jaipur
>
> **Under the Guidance of** : [Vimal Daga](https://in.linkedin.com/in/vimaldaga)

