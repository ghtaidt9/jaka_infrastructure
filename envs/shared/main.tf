locals {
  project = "jaka-mod"
}

module "ecr" {
  source = "../../modules/ecr"

  name_prefix = local.project
  services    = ["order", "payment", "inventory", "notification"]

  image_tag_mutability = "IMMUTABLE"
  tag_prefixes         = ["sha-"]
  keep_tagged_images   = 15
}
