terraform {
  backend "s3" {
    key     = "infrastructure/terraform.tfstate"
    region  = "fsn1"
    profile = "homelab"

    use_lockfile = true

    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    use_path_style              = true
  }
}
