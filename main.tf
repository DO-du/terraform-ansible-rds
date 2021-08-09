resource "aws_instance" "my_instance" {
  ami                    = "ami-0f49ee52a88cc2435"
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.my_dh_web.id]
  key_name               = aws_key_pair.my_sshkey.key_name

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file("./my_sshkey")
    host        = self.public_ip
  }

  provisioner "file" {
    source      = "wpsite.yaml"
    destination = "/home/ubuntu/wpsite.yaml"
  }

  provisioner "file" {
    source      = "roles"
    destination = "/home/ubuntu/"
  }

  provisioner "file" {
    source      = "group_vars"
    destination = "/home/ubuntu/"
  }



  provisioner "local-exec" {
    command = <<-EOF
      ssh-keyscan -t ssh-rsa ${self.public_ip} >> ~/.ssh/known_hosts
      echo "${self.public_ip} ansible_ssh_user=ubuntu ansible_ssh_private_key_file=./my_sshkey" > inventory.ini
      echo "private_ip: ${self.public_ip}" >> group_vars/all.yaml
      echo "service_port: ${var.wp_port}" >> group_vars/all.yaml   
      echo "rds_pw: ${aws_db_instance.rds_instance.password}" >> group_vars/all.yaml     
      echo "rds_name: ${aws_db_instance.rds_instance.name}" >> group_vars/all.yaml
      echo "rds_host: ${aws_db_instance.rds_instance.endpoint}" >> group_vars/all.yaml
      echo "rds_user: ${aws_db_instance.rds_instance.username}" >> group_vars/all.yaml       
      sudo apt-get update
      EOF
  }

  provisioner "local-exec" {
    command = "ansible-playbook -i inventory.ini wpsite.yaml -b"
  }

  depends_on = [aws_db_instance.rds_instance]


}

resource "aws_db_instance" "rds_instance" {
  allocated_storage      = 20
  engine                 = "mysql"
  engine_version         = "5.7"
  instance_class         = "db.t3.micro"
  name                   = "mydb"
  username               = "wpadm"
  password               = "qwer1234"
  parameter_group_name   = "default.mysql5.7"
  skip_final_snapshot    = true
  publicly_accessible    = true
  vpc_security_group_ids = [aws_security_group.my_dh_rds.id]
  port                   = 3306
}

resource "aws_key_pair" "my_sshkey" {
  key_name   = "my_sshkey"
  public_key = file("./my_sshkey.pub")
}
