variable "region" { type = string, default = "ap-southeast-1" }
variable "name"   { type = string, default = "cmdb" }
variable "tags"   { type = map(string) default = { Project = "CMDB" } }
