#AWS Region Variable
variable "region" {
  description = "AWS Region"
  type = string
  default = "us-east-1"
}

#Security Group Allowed ports
variable "allowed_ports" {
  type = list(number)
  default = [80, 3000]
}