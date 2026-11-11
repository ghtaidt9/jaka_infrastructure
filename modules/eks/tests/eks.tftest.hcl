mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
      arn        = "arn:aws:iam::123456789012:user/test"
      user_id    = "AIDATEST"
    }
  }
  mock_data "aws_iam_session_context" {
    defaults = {
      issuer_arn = "arn:aws:iam::123456789012:user/test"
    }
  }
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
  mock_data "aws_partition" {
    defaults = {
      partition  = "aws"
      dns_suffix = "amazonaws.com"
    }
  }
}

mock_provider "tls" {}
mock_provider "time" {}
mock_provider "cloudinit" {}
mock_provider "null" {}

variables {
  name_prefix        = "jaka-mod-dev-eks"
  kubernetes_version = "1.35"
  vpc_id             = "vpc-123"
  private_subnet_ids = ["subnet-a", "subnet-b"]
  node_instance_type = "t3.medium"
  node_min           = 2
  node_max           = 4
}

run "block_node_min_less_than_2" {
  command = plan
  variables {
    node_min = 1
  }
  expect_failures = [var.node_min]
}

run "block_1_subnet" {
  command = plan
  variables {
    private_subnet_ids = ["subnet-a"]
  }
  expect_failures = [var.private_subnet_ids]
}

run "valid" {
  command = plan
}