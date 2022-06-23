resource "google_logging_organization_sink" "my-sink" {
  name   = "my-sink"
  description = "some explanation on what this is"
  org_id = "123456789"

  # Can export to pubsub, cloud storage, or bigquery
  destination = "storage.googleapis.com/${google_storage_bucket.log-bucket.name}"

  # Log all WARN or higher severity messages relating to instances
  filter = "resource.type = gce_instance AND severity >= WARNING"
}


#0 create [security logs] folder
resource "google_folder" "secuirty-logs" {
  display_name = var.folder_name
  parent       = var.org_name # not each org has: display_name & name (which is like id)
}

#1 vpc: [splunk-vpc]
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

#2 pub/sub: topic [splunk-dataflow-sink]
module "splunk-dataflow-sink" {
  source  = "terraform-google-modules/log-export/google//modules/pubsub"
  project_id = var.project_id
  topic_name = "splunk-dataflow-sink"
  log_sink_writer_identity = module.splunk-dataflow-export.writer_identity
}


#3 pub/sub: subscriber [dataflow]
resource "google_pubsub_subscription" "dataflow" {
  depends_on = [
    module.splunk-dataflow-sink
  ]
  name = "dataflow"
  project = var.project_id
  topic = module.splunk-dataflow-sink.resource_name
}




#4 log router sink: [splunk-dataflow-export]
module "splunk-dataflow-export" {
  source  = "terraform-google-modules/log-export/google"
  parent_resource_id = var.project_id
  log_sink_name = "splunk-dataflow-export"
  destination_uri = module.splunk-dataflow-sink.destination_uri
  filter = "resource.type!=\"dataflow_step\""
}

#5 add role [roles/dataflow.admin] to [compute@developer.gserviceaccount.com]
resource "google_project_iam_binding" "dataflow_admin_to_svc_compute" {
  project = var.project_id
  role    = "roles/dataflow.admin"
  members = [
    "serviceAccount:${var.project_number}-compute@developer.gserviceaccount.com",
  ]
}

#6 gcs: [<project-id>-dataflow] is a dead letter queue 
module "dead-letter-queue-gcs" {
  source  = "terraform-google-modules/cloud-storage/google"
  version = "3.2.0"
  project_id = var.project_id
  names = ["dataflow"]
  prefix = var.project_id
  location = var.region
}

#7 pub/sub: [splunk-dataflow-deadletter]
module "splunk-dataflow-deadletter" {
  source  = "terraform-google-modules/pubsub/google"
  version = "3.2.0"
  project_id = var.project_id
  topic = "splunk-dataflow-deadletter"
  pull_subscriptions = [
    {
      name = "deadletter"
    }
  ]
}

#8 dataflow job: [splunk-dataflow]
module "splunk-dataflow]" {
  source  = "terraform-google-modules/dataflow/google"
  version = "0.1.0"

  project_id  = var.project_id
  name = "splunk-dataflow"
  on_delete = "cancel"
  zone = var.region
  max_workers = 1
  template_gcs_path =  "gs://dataflow-templates-us-central1/latest/Cloud_PubSub_to_Splunk"
  temp_gcs_location = "gs:/${var.project_id}-dataflow/tmp"
  parameters = {
        bar = "example string"
        foo = 123
  }
}