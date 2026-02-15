terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

locals {
  app = "encuentrame"
  env = "dev"
}

resource "aws_dynamodb_table" "users" {
  name         = "${local.app}-${local.env}-users"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "pk"

  attribute {
    name = "pk"
    type = "S"
  }
}

resource "aws_dynamodb_table" "stalls" {
  name         = "${local.app}-${local.env}-stalls"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "pk"

  attribute {
    name = "pk"
    type = "S"
  }

  attribute {
    name = "gsi1pk"
    type = "S"
  }

  attribute {
    name = "gsi1sk"
    type = "S"
  }

  global_secondary_index {
    name            = "gsi1"
    hash_key        = "gsi1pk"
    range_key       = "gsi1sk"
    projection_type = "ALL"
  }
}

resource "aws_dynamodb_table" "opening_logs" {
  name         = "${local.app}-${local.env}-openinglogs"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "pk"
  range_key    = "sk"

  attribute {
    name = "pk"
    type = "S"
  }

  attribute {
    name = "sk"
    type = "S"
  }
}

output "users_table_name" {
  value = aws_dynamodb_table.users.name
}
output "stalls_table_name" {
  value = aws_dynamodb_table.stalls.name
}
output "openinglogs_table_name" {
  value = aws_dynamodb_table.opening_logs.name
}

output "users_table_arn" {
  value = aws_dynamodb_table.users.arn
}
output "stalls_table_arn" {
  value = aws_dynamodb_table.stalls.arn
}
output "openinglogs_table_arn" {
  value = aws_dynamodb_table.opening_logs.arn
}
