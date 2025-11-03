terraform {
  backend "s3" {
    bucket         = "tfstate-your-bucket"
    key            = "aws/eks/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
  }
}
