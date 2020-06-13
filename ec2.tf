provider "aws" {
  region   = "ap-south-1"
  profile  = "onkar"
}
resource "aws_key_pair" "key1"{
  key_name   = "key1"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAQEA2PGU/tcymdEtyqarOT+yGcRaU1cb32boh6I5fZXpN1ANl24m0C9DVnZGS4sKhlQHQg2R7AxE6kzpvauObjoJ0h4uWOmaJmDASgvmjREEwvzbSz048RflphrAU0KP1ixWCSij//ATN2AzxV17ZUpdoko93T0/AI1UNxsmZHfNel+r8so6Sdxydpo1Bgr10xyqPmND9lkNLKOz9HZ5Pe5AKWlMc/qgSJemYmCdyRZYhEea0wZBpYSV4zCgw16G2iP1sX4BQR29ECkjU+H8+xHCkEmAS6x8Xnp6e65G3VBaMKtPfk0HMx8Oux0DfySseFonXIncGlHqH5usjASun2v0bw== rsa-key-20200612"
}
 resource "aws_security_group" "group1" {
  name        = "group1"
  description = "allow ssh and http traffic"

 ingress{
from_port =22
to_port =22
protocol ="tcp"
cidr_blocks=["0.0.0.0/0"]
}
ingress{
from_port =80 
to_port =80
protocol ="tcp"
cidr_blocks =["0.0.0.0/0"]
}
ingress{
from_port =443
to_port =443
protocol ="tcp"
cidr_blocks=["0.0.0.0/0"]
}
egress{
from_port =22
to_port = 22
protocol ="tcp"
cidr_blocks = ["0.0.0.0/0"]
}
egress{
from_port =80
to_port = 80
protocol ="tcp"
cidr_blocks = ["0.0.0.0/0"]
}
egress{
from_port =443
to_port = 443
protocol ="tcp"
cidr_blocks = ["0.0.0.0/0"]
}
tags = {
    Name = "group1"
  }
}
  resource "aws_instance" "web" {
  ami           = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  key_name      = "mykey123"
  security_groups = [ "group1" ]

  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("mykey123.pem")
    host     = aws_instance.web.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd  php git -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
    ]
  }

  tags = {
    Name = "onkos1"
  }

}
resource "aws_ebs_volume" "ebs1" {
  availability_zone = aws_instance.web.availability_zone
  size              = 1
  tags = {
    Name = "myvol1"
  }
}

resource "aws_volume_attachment" "ebs_att" {
  device_name = "/dev/sdh"
  volume_id   = "${aws_ebs_volume.ebs1.id}"
  instance_id = "${aws_instance.web.id}"
  force_detach = true
}
resource "null_resource" "nullremote3"  {

depends_on = [
    aws_volume_attachment.ebs_att,
  ]


  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("mykey123.pem")
    host     = aws_instance.web.public_ip
  }

provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4  /dev/xvdh",
      "sudo mount  /dev/xvdh  /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/onkar1-git/HybridCloud.git /var/www/html/"
    ]
  }
}
resource "aws_s3_bucket" "b" {
  bucket = "onkar1bucket"
  acl    = "private"
 tags = {
  Name = "lwbucket"
}
}
locals {
   s3_origin_id = "mes3origin"
}
output "b" {
  value = aws_s3_bucket.b
}
resource "aws_cloudfront_origin_access_identity" "identity" {
  comment = "Some comment"
}
output "origin_access_identity" {
  value = aws_cloudfront_origin_access_identity.identity
}
data "aws_iam_policy_document" "policy" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.b.arn}/*"]
    principals {
      type        = "AWS"
      identifiers = ["${aws_cloudfront_origin_access_identity.identity.iam_arn}"]
    }
  }
  statement {
    actions   = ["s3:ListBucket"]
    resources = ["${aws_s3_bucket.b.arn}"]
    principals {
      type        = "AWS"
      identifiers = ["${aws_cloudfront_origin_access_identity.identity.iam_arn}"]
    }
  }
}
resource "aws_s3_bucket_policy" "policy1" {
  bucket = aws_s3_bucket.b.id
  policy = data.aws_iam_policy_document.policy.json
}

resource "aws_cloudfront_distribution" "cloudfront1" {
    enabled             = true
    is_ipv6_enabled     = true
    wait_for_deployment = false
    origin {
        domain_name = "${aws_s3_bucket.b.bucket_regional_domain_name}"
        origin_id   = local.s3_origin_id
    s3_origin_config {
       origin_access_identity = "${aws_cloudfront_origin_access_identity.identity.cloudfront_access_identity_path}" 
        
}
}
    default_cache_behavior {
        allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
        cached_methods = ["GET", "HEAD"]
        target_origin_id = local.s3_origin_id
      forwarded_values {
            query_string = false
        
            cookies {
               forward = "none"
            }
        }
        
        viewer_protocol_policy = "redirect-to-https"
        min_ttl                =  0
        default_ttl            =  3600
        max_ttl                =  86400
    }
    restrictions {
        geo_restriction {
            restriction_type = "none"
        }
    }
viewer_certificate {
        cloudfront_default_certificate = true
    }
}
resource "aws_s3_bucket_object" "object" {
  bucket = "onkar1bucket"
  key    = "cloud.png"
}