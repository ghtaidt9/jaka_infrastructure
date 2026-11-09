mock_provider "aws" {}

variables {
  name_prefix          = "jaka-mod-test"
  vpc_cidr             = "10.0.0.0/16"
  azs                  = ["ap-southeast-1a", "ap-southeast-1b"]
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]
}

# --- validations: bad input must be rejected -----------------------------------------------

run "rejects_single_az" {
  command = plan
  variables {
    azs                  = ["ap-southeast-1a"]
    public_subnet_cidrs  = ["10.0.1.0/24"]
    private_subnet_cidrs = ["10.0.11.0/24"]
  }
  expect_failures = [var.azs]
}

run "rejects_invalid_vpc_cidr" {
  command = plan
  variables {
    vpc_cidr = "10.0.0.0/33"
  }
  expect_failures = [var.vpc_cidr]
}

run "rejects_cidr_count_mismatch" {
  command = plan
  variables {
    private_subnet_cidrs = ["10.0.11.0/24"]
  }
  expect_failures = [var.private_subnet_cidrs]
}

# --- behaviour of valid input --------------------------------------------------------------

run "ha_nat_one_per_az" {
  command = plan

  assert {
    condition     = length(aws_nat_gateway.this) == 2
    error_message = "single_nat_gateway = false must create one NAT gateway per AZ."
  }
}

run "single_nat_gateway" {
  command = plan
  variables {
    single_nat_gateway = true
  }

  assert {
    condition     = length(aws_nat_gateway.this) == 1 && length(aws_eip.nat) == 1
    error_message = "single_nat_gateway = true must create exactly one NAT gateway and one EIP."
  }
}

run "eks_subnet_tags_are_merged" {
  command = plan
  variables {
    public_subnet_tags  = { "kubernetes.io/role/elb" = "1" }
    private_subnet_tags = { "kubernetes.io/role/internal-elb" = "1" }
  }

  assert {
    condition = alltrue([
      for s in aws_subnet.private : s.tags["kubernetes.io/role/internal-elb"] == "1" && s.tags["Tier"] == "private"
    ])
    error_message = "Private subnets must keep their own tags and get private_subnet_tags merged in."
  }

  assert {
    condition     = alltrue([for s in aws_subnet.public : s.tags["kubernetes.io/role/elb"] == "1"])
    error_message = "Public subnets must get public_subnet_tags merged in."
  }
}
