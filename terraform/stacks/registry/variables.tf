variable "region" { 
  description = "La región de AWS donde se desplegarán los recursos."
  type        = string
  nullable    = false
}

variable "owner" {
  description = "Dueño de los recursos. Para propósito acadmémico."
  type        = string
  nullable    = false
}

variable "keep_tags_number" {
  description = "Number of tags to keep in the registry"
  type        = number
}

variable "repositories_names" {
  description = "Name of the repositories to be created"
  type        = list(string)
  nullable    = false
}