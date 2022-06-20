# vpc: splunk-vpc
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

# pub/sub: splunk-dataflow-sink
module "splunk-dataflow-sink" {
  source  = "terraform-google-modules/log-export/google//modules/pubsub"
#   version = "3.2.0"
  project_id = var.project_id
  topic_name      = "splunk-dataflow-sink"
  log_sink_writer_identity = module.splunk-dataflow-export.writer_identity
}

# log router sink: splunk-dataflow-export
module "splunk-dataflow-export" {
  source  = "terraform-google-modules/log-export/google"
  parent_resource_id = var.project_id
  log_sink_name = "splunk-dataflow-export"
  destination_uri = module.splunk-dataflow-sink.destination_uri
  filter = "resource.type!=\"dataflow_step\""
}