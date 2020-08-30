# Cloud Provider
provider "aws" {
        region = var.region_name
        profile = var.user_profile
}


#Creating AWS Key Pair for EC2 Instance Login
resource "aws_key_pair" "instance_key_pair"{
        key_name = "automation-key"
        public_key = file("/opt/keys/ec2.pub")
}

# Fetching Public IP of node Controller System
resource "null_resource" "public_ip_automation_system" {
        provisioner local-exec {
                command = "curl -s ifconfig.co | awk '{print $0 \"/32\"}' >/opt/automation_public_ip.txt"
        }

}

# Cerating Securirty Group to allow ingress on HTTP and SSH port only
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


#Creating EC2 instance
resource "aws_instance" "web_server" {
        ami = var.instance_ami_id
        instance_type = var.instance_type
        security_groups = [aws_security_group.instance_sg.name]
        key_name = aws_key_pair.instance_key_pair.key_name

        tags = {
                Name = "web-server"
        }
}


# Create EBS Volume
resource "aws_ebs_volume" "web_server_volume" {
        availability_zone = aws_instance.web_server.availability_zone
        size              = 1
        tags = {
                Name = "Web-Server"
        }
}


# Attaching EBS Volume to EC2 instance
resource "aws_volume_attachment" "ec2_volume_attach" {
        device_name = "/dev/sdf"
        volume_id   = aws_ebs_volume.web_server_volume.id
        instance_id = aws_instance.web_server.id
        force_detach = true
}

# Configuration and Installation of Packages 
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

        provisioner local-exec {
                command = "ansible-playbook -u ${var.connection_user} -i ${aws_instance.web_server.public_ip}, --private-key /opt/keys/ec2 configuration.yml  --ssh-extra-args=\"-o stricthostkeychecking=no\""
        }

}


# Creating S3 Bucket
resource "aws_s3_bucket" "s3_image_store" {
        bucket = var.s3_image_bucket_name
        acl = var.bucket_acl
        tags = {
                Name = "WebPage Image Source"

        }
        force_destroy = var.force_destroy_bucket
}

#The Below commented code is to be used only when Jenkins Automation system is not used
# Cloning git code repository
#resource "null_resource" "download_website_code"{
#        depends_on = [
#                aws_s3_bucket.s3_image_store
#        ]
#        provisioner local-exec {
#                command = 
#                "rm -rf /opt/code/*"
#                "git clone https://github.com/riteshsoni10/demo_website.git /opt/code/"
#        }
#}



# Upload all the website images to S3 bucket
resource "aws_s3_bucket_object" "website_files" {
        # The below code is commented and only to be used when not using Jenkins for automation
        #depends_on = [
        #        null_resource.download_website_code,
        #]
        for_each      = fileset("/opt/code/images/", "**/*.*")
        bucket        = aws_s3_bucket.s3_image_store.bucket
        key           = replace(each.value, "/opt/code/images/", "")
        source        = "/opt/code/images/${each.value}"
        acl           = "public-read"
        etag          = filemd5("/opt/code/images/${each.value}")
}


#Creating Origin Access Identity
resource "aws_cloudfront_origin_access_identity" "s3_objects" {
        comment = "S3-Images-Source"
}

# Creating CloudFront Distribution for Images source from S3 Bucket
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


# Configure Website to use CDN domain as images source
resource "null_resource" "configure_image_url" {
        depends_on = [
                aws_cloudfront_distribution.image_distribution, null_resource.invoke_playbook,
        ]
        connection{
                type = var.connection_type
                host = aws_instance.web_server.public_ip
                user  = var.connection_user
                private_key = file("/opt/keys/ec2")
        }
        provisioner remote-exec {
                inline =[
                        "grep -rli 'images' /var/www/html/* | xargs -i sed -i \"s+images+https://${aws_cloudfront_distribution.image_distribution.domain_name}+g\" "
                ]
        }
}
