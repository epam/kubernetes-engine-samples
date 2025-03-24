data "aws_subnet" "kafka_loadgen_subnet" {
  vpc_id            = data.aws_vpc.kafka_vpc.id
  availability_zone = "us-east-1a"
}

resource "aws_instance" "kafka_load_vm" {
  ami                    = var.ami_id
  instance_type          = var.machine_type                                
  subnet_id              = data.aws_subnet.kafka_loadgen_subnet.id     
  vpc_security_group_ids = [data.aws_security_group.brokers_sg.id]     # Use the same security group for all brokers and load generator

  # Root Volume Configuration
  root_block_device {
    volume_size           = 20                       # 20 GB size
    volume_type           = "gp3"                    # General Purpose SSD
    iops                  = 3000                     # IOPS for gp3
    throughput            = 125                      # Throughput in MB/s
    delete_on_termination = true                     # Remove on termination
  }

  monitoring = true

  user_data = file("./load_vm_init.sh")

  tags = {
    Name = "load-generator"
  }
}