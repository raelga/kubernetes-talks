terraform {
  required_version = ">= 1.11.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.100.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "3.5.0"
    }
    mysql = {
      source  = "petoju/mysql"
      version = "3.0.103"
    }
  }

  # Supply only bucket at init; keep this state separate from infrastructure.
  backend "s3" {
    key          = "wordpress-database/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = data.terraform_remote_state.infra.outputs.aws_region
}

# AWS 5.100 supports ephemeral secret reads: administrator credentials are used
# only for provider configuration and are not persisted in this root's state.
ephemeral "aws_secretsmanager_secret_version" "administrator" {
  secret_id = data.terraform_remote_state.infra.outputs.database_secret_arn
}


data "http" "rds_ca" {
  url = "https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem"
}

provider "mysql" {
  # Preserve the RDS hostname for TLS verification. The local SOCKS bridge maps
  # only this hostname and port through an SSM remote-host port forward.
  endpoint = "${data.terraform_remote_state.infra.outputs.database_endpoint}:3306"
  username = jsondecode(ephemeral.aws_secretsmanager_secret_version.administrator.secret_string).username
  password = jsondecode(ephemeral.aws_secretsmanager_secret_version.administrator.secret_string).password
  proxy    = "socks5://127.0.0.1:1080"
  no_proxy = ""

  # Verify the RDS certificate chain while retaining the real endpoint hostname.
  custom_tls {
    config_key  = "rds"
    ca_cert     = data.http.rds_ca.response_body
    client_cert = ""
    client_key  = ""
  }
}
