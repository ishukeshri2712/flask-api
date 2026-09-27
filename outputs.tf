output "instance_id" {
  value = aws_instance.app_server.id
}

output "public_ip" {
  value = aws_instance.app_server.public_ip
}

output "ami_used" {
  value = data.aws_ami.latest_amazon_linux.id
}

output "kms_key_arn" {
  value = aws_kms_key.ebs_kms_key.arn
}

output "app_url" {
  value = "http://${aws_instance.app_server.public_ip}:8081/api/v1"
}