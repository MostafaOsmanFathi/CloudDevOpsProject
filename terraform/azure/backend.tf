# Partial backend configuration.
# The real values live in backend.hcl (copy it from backend.hcl.example) and are
# passed at init time:
#
#   terraform init -backend-config=backend.hcl
#
terraform {
  backend "azurerm" {}
}
