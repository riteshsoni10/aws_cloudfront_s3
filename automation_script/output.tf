
output "instance_key"{
         value = aws_key_pair.instance_key_pair.key_name
}

output "security_group_name" {
        value = aws_security_group.instance_sg.name
}

output "ec2_instance_public_ip"{
        value = aws_instance.web_server.public_ip
}

output "ebs_volume"{
        value = aws_ebs_volume.web_server_volume.id
}

output "s3_bucket_name" {
        value = aws_s3_bucket.s3_image_store.bucket
}

output "s3_bucket_domain_name" {
        value = aws_s3_bucket.s3_image_store.bucket_domain_name
}

output "cf_id" {
  value       = aws_cloudfront_distribution.image_distribution.id
}

output "cf_status" {
  value       = aws_cloudfront_distribution.image_distribution.status
}

output "cf_domain_name" {
  value       = aws_cloudfront_distribution.image_distribution.domain_name
}

output "website_s3_files_upload" {
        value= aws_s3_bucket_object.website_files
}
