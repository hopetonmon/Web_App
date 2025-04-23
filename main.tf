terraform {
    required_providers {
        aws = {
        source  = "hashicorp/aws"
        version = "~> 4.0"
        }
    }
    
    required_version = ">= 1.0.0"
}

#-----------------------VARIABLES-----------------------------
variable "TERRY_ACCESS_KEY" {
    description = "Terry's AWS Access Key"
    type        = string
    sensitive = true
}

variable "TERRY_SECRET_KEY" {
    description = "Terry's AWS Secret Key"
    type        = string
    sensitive = true
  
}

variable "AWS_REGION" {
    description = "AWS Region"
    type        = string
}

#------------------PROVIDERS----------------------
provider "aws" {
    region     = var.AWS_REGION
    access_key = var.TERRY_ACCESS_KEY
    secret_key = var.TERRY_SECRET_KEY
  
}

#-------------------VPC---------------------
resource "aws_vpc" "web_vpc" {
    cidr_block = "10.0.0.0/16"
    enable_dns_support = true
    enable_dns_hostnames = true
    tags = {
        Name = "web_vpc"
    }
}
