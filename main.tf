# vpc:splunk-vpc
module "network" {
  source = "github.com/terraform-google-modules/terraform-google-network"
  project_id  = var.project_id
  network_name = var.network_name
  subnets = [
    {
        subnet_name = var.subnets[0]
        subnet_ip = var.subnets_ip[0]
        subnet_region = var.region
    },
  ]

  secondary_ranges = {
        subnet-01 = [
            {
                range_name    = var.subnets_range_name[0]
                ip_cidr_range = var.ip_cidr_ranges[0]
            },
        ]
    }

}

