  plugin "terraform" {
    enabled = true
    preset  = "recommended"
  }

  plugin "aws" {
    enabled = true
    version = "0.29.0"
    source  = "github.com/terraform-linters/tflint-ruleset-aws"
  }

  rule "terraform_unused_declarations" {
    enabled = true
  }

  rule "terraform_naming_convention" {
    enabled = true
    format  = "snake_case"
  }
