# terraform-provider-azurerm 3.0 beta: function app with key vault references
Some notes:
* terraform-provider-azurerm v2.98.0 is required with [this PR](https://github.com/hashicorp/terraform-provider-azurerm/pull/15740) applied to fix the dedup of merged user settings
* Enable 3.0 beta in the provider via ENV var: `export ARM_THREEPOINTZERO_BETA_RESOURCES=true`
* Configuration assumes that an existing Azure Resource Group, specified via var: `terraform apply -var 'resource_group_name=myRGP'`
