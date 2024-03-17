terraform {
  backend "s3" {
    bucket = "terraform-tfstates-lambda"
    key    = "totemLanchoneteLambda/terraform.tfstate"
    region = "us-east-1"
  }
}