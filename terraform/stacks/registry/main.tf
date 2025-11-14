
# This can be improved by using a for_each loop if the number of repositories increases
module "create_repositories" {
  for_each = toset(var.repositories_names)
  source = "../../modules/repository"
  keep_tags_number = var.keep_tags_number
  repository_name  = each.value
}
  
# module "add_repository" {
#   source = "../../modules/repository"
#   keep_tags_number = var.keep_tags_number
#   repository_name  = var.add_repository_name
# }

# module "multiply_repository" {
#   source = "../../modules/repository"
#   keep_tags_number = var.keep_tags_number
#   repository_name  = var.multiply_repository_name
# }