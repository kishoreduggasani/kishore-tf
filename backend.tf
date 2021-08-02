terraform {
  backend "s3" {
    encrypt = true
    bucket = "kishore-test-tf"
    region = "us-east-2"
    key = "tf.tfstate"
  }
}
