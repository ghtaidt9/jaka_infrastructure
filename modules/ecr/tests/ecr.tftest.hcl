mock_provider "aws" {}

variables {
  name_prefix = "jaka-mod-test"
  services    = ["order", "payment"]
}

# --- for_each: 1 repository + 1 lifecycle policy per service -------------------------------

run "one_repo_per_service" {
  command = plan

  assert {
    condition     = length(aws_ecr_repository.this) == 2
    error_message = "Expected 1 repository per service (2)."
  }

  assert {
    condition     = aws_ecr_repository.this["order"].name == "jaka-mod-test-order-service"
    error_message = "Repository name must stay <name_prefix>-<service>-service (renaming = AWS creates a new, empty repo)."
  }

  assert {
    condition     = length(aws_ecr_lifecycle_policy.this) == 2
    error_message = "Every repository needs a lifecycle policy."
  }
}

# --- lifecycle policy: keep_tagged_images reaches the rule -----------------------------------

run "keep_tagged_images_in_policy" {
  command = plan

  variables {
    keep_tagged_images = 5
  }

  assert {
    condition     = jsondecode(aws_ecr_lifecycle_policy.this["order"].policy).rules[1].selection.countNumber == 5
    error_message = "Rule 2 must keep exactly keep_tagged_images tagged images."
  }
}

# --- output: map keyed by short service name (envs/dev-eks reads ["order"]) ------------------

run "output_keyed_by_service" {
  command = apply # mock provider: nothing is created in AWS, but repository_url gets a value

  assert {
    condition     = toset(keys(output.repository_urls)) == toset(["order", "payment"])
    error_message = "repository_urls must be keyed by the short service name."
  }
}
