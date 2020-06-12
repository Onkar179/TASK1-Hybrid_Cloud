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
  description = "Allow TLS inbound traffic"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
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
  bucket = "my-tf45-test-bucket"
  acl    = "public-read"

  versioning {
    enabled = true
  }
}
resource "aws_s3_bucket_object" "object1" {
bucket = "my-tf45-test-bucket"
key    = "cloud.jpg"
source = "cloud.jpg"
acl    = "public-read"
}

resource "aws_cloudfront_distribution" "cloudfront1" {
    origin {
        domain_name = "my-tf45-test-bucket.s3.amazonaws.com"
        origin_id = "S3-my-tf45-test-bucket" 


        custom_origin_config {
            http_port = 80
            https_port = 80
            origin_protocol_policy = "match-viewer"
            origin_ssl_protocols = ["TLSv1", "TLSv1.1", "TLSv1.2"] 
        }
    }
       
    enabled = true


    default_cache_behavior {
        allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
        cached_methods = ["GET", "HEAD"]
        target_origin_id = "S3-my-tf45-test-bucket"
      forwarded_values {
            query_string = false
        
            cookies {
               forward = "none"
            }
        }
        
        viewer_protocol_policy = "allow-all"
        min_ttl = 0
        default_ttl = 3600
        max_ttl = 86400
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
