variable "region" {
  type = string
}

variable "profile" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "subnet_count" {
  type = number
}

variable "control_nodes_count" {
  type = number
}

variable "worker_nodes_count" {
  type = number
}

variable "inbound_rules" {
  type = list(object({
    from        = number
    to          = optional(number)
    description = optional(string)
    protocol    = optional(string)
    cidr_block  = optional(list(string))
  }))
  default = []
}

variable "outbound_rules" {
  type = list(object({
    from        = number
    to          = optional(number)
    description = optional(string)
    protocol    = optional(string)
    cidr_block  = optional(list(string))
  }))
  default = []
}


variable "key" {
  type = string
}

variable "worker_instance_type" {
  type = string
}

variable "control_instance_type" {
  type = string
}
