// Configure the Google Cloud provider
provider "google" {
  credentials = var.credentials
  project = var.project
  region  = var.region
}

# Enabling GCP Services
resource "google_project_service" "enable_services" {
  project = var.project
  count   = length(var.service_list)
  service = var.service_list[count.index]

  disable_dependent_services = true # If true, services that are enabled and which depend on this service should also be disabled when this service is destroyed
  disable_on_destroy = false # If false, will not disable the service when the terraform resource is destroyed
}

// Terraform plugin for creating random ids
resource "random_id" "instance_id" {
 byte_length = 8
}

// Set up firewall rules
resource "google_compute_firewall" "default" {
 name    = "flask-app-firewall"
 network = "default"

 allow {
   protocol = "tcp"
   ports    = ["5000"]
 }
}

// A single Compute Engine instance
resource "google_compute_instance" "default" {
 name         = "flask-vm-${random_id.instance_id.hex}"
 machine_type = "f1-micro"
 zone         = "europe-west2-a"
# metadata = {
#   ssh-keys = "soneymanic:${file("C:/Users/358320/.ssh/id_rsa.pub")}"
# }

 boot_disk {
   initialize_params {
     image = "debian-cloud/debian-9"
   }
 }

// Make sure flask is installed on all new instances for later steps
 metadata_startup_script = "sudo apt-get update; sudo apt-get install -yq build-essential python-pip rsync; pip install flask"

 network_interface {
   network = "default"

   access_config {
     // Include this section to give the VM an external ip address
   }
 }
}

// A variable for extracting the external IP address of the instance
output "ip" {
 value = google_compute_instance.default.network_interface.0.access_config.0.nat_ip
}
