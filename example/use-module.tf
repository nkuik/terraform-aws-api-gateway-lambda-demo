provider "aws" {
  region     = "eu-west-1"
}

module "test-function" {
  source = "../"
  name = "test-function"
  description = "A very helpful function"
}
