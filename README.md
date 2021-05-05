# TerraformTest
Testing Terraform pipeline

# Getting started with Terraform on Google Cloud
Author(s): @chrisst ,   Published: 2018-08-17

Chris Stephens | Software Engineer | Google
Contributed by Google employees.
# URL - https://cloud.google.com/community/tutorials/getting-started-on-gcp-with-terraform


One of the things I find most time consuming when starting on a new stack or technology is moving from reading documentation to a working prototype serving HTTP requests. This can be especially frustrating when trying to tweak configurations and keys, as it can be hard to make incremental progress. However, once I have a shell of a web service stood up, I can add features, connect to other APIs, or add a datastore. I'm able to iterate very quickly with feedback at each step of the process. To help get through those first set up steps I've written this tutorial to cover the following:

Using Terraform to create a VM in Google Cloud
Starting a basic Python Flask server
Before you begin
You will be starting a single Compute Engine VM instance, which can incur real, although usually minimal, costs. Pay attention to the pricing on the account. If you don't already have a Google Cloud account, you can sign up for a free trial and get $300 of free credit, which is more than you'll need for this tutorial.

Have the following tools locally:

An existing SSH key
Terraform
This tutorial is written using Terraform 0.12 syntax. If you're using a different version of Terraform, some of the syntax will be slightly different.

Create a Google Cloud project
A default project is often set up by default for new accounts, but you will start by creating a new project to keep this separate and easy to tear down later. After creating it, be sure to copy down the project ID as it is usually different then the project name.

How to find your project ID.

Getting project credentials
Next, set up a service account key, which Terraform will use to create and manage resources in your Google Cloud project. Go to the create service account key page. Select the default service account or create a new one. If you're creating a new service account for this tutorial, you can use the Project Owner role, but we recommend that you remove the service account or restrict its scope after you have completed the tutorial. Select JSON as the key type and click Create.

This downloads a JSON file with all the credentials that will be needed for Terraform to manage the resources. This file should be located in a secure place for production projects, but for this example move the downloaded JSON file to the project directory.

Setting up Terraform
Create a new directory for the project to live and create a main.tf file for the Terraform config. The contents of this file describe all of the Google Cloud resources that will be used in the project.


// Configure the Google Cloud provider
provider "google" {
 credentials = file("CREDENTIALS_FILE.json")
 project     = "flask-app-211918"
 region      = "us-west1"
}
Set the project ID from the first step to the project property and point the credentials section to the file that was downloaded in the last step. The provider “google” line indicates that you are using the Google Cloud Terraform provider and at this point you can run terraform init to download the latest version of the provider and build the .terraform directory.


terraform init

Initializing provider plugins...
- Checking for available provider plugins on https://releases.hashicorp.com...
- Downloading plugin for provider "google" (1.16.2)...

The following providers do not have any version constraints in configuration,
so the latest version was installed.

To prevent automatic upgrades to new major versions that may contain breaking
changes, it is recommended to add version = "..." constraints to the
corresponding provider blocks in configuration, with the constraint strings
suggested below.

* provider.google: version = "~> 1.16"

Terraform has been successfully initialized!
Configure the Compute Engine resource
Next you will create a single Compute Engine instance running Debian. For this demo you can use the smallest instance possible (check out all machine types here) but you can upgrade to a larger instance later. Add the google_compute_instance resource to the main.tf:


// Terraform plugin for creating random ids
resource "random_id" "instance_id" {
 byte_length = 8
}

// A single Compute Engine instance
resource "google_compute_instance" "default" {
 name         = "flask-vm-${random_id.instance_id.hex}"
 machine_type = "f1-micro"
 zone         = "us-west1-a"

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
The random_id Terraform plugin allows you to create a somewhat random instance name that still complies with the Google Cloud instance naming requirements but requires an additional plugin. To download and install the extra plugin, run terraform init again.

Validate the new Compute Engine instance
You can now validate the work that has been done so far. Run terraform plan which will:

Verify the syntax of main.tfis correct
Ensure the credentials file exists (contents will not be verified until terraform apply)
Show a preview of what will be created
Output:


An execution plan has been generated and is shown below.
Resource actions are indicated with the following symbols:
  + create

Terraform will perform the following actions:

  + google_compute_instance.default
      id:                                                  [computed]
...

  + random_id.instance_id
      id:                                                  [computed]
...


Plan: 2 to add, 0 to change, 0 to destroy.
Now it's time to run terraform apply and Terraform will call Google Cloud APIs to set up the new instance. Check the VM Instances page, and the new instance will be there.

Running a server on Google Cloud
There is now a new instance running in Google Cloud, so your next steps are getting a web application created, deploying it to the instance, and exposing an endpoint for consumption.

Add SSH access to the Compute Engine instance
You will need to add a public SSH key to the Compute Engine instance to access and manage it. Add the local location of your public key to the google_compute_instance metadata in main.tf to add your SSH key to the instance. More information on managing ssh keys is available here.


resource "google_compute_instance" "default" {
 ...
metadata = {
   ssh-keys = "INSERT_USERNAME:${file("~/.ssh/id_rsa.pub")}"
 }
}
Be sure to replace INSERT_USERNAME with your username and then run terraform plan and verify the output looks correct. If it does, run terraform apply to apply the changes.

The output shows that it will modify the existing compute instance:


An execution plan has been generated and is shown below.
Resource actions are indicated with the following symbols:
  ~ update in-place

Terraform will perform the following actions:

  ~ google_compute_instance.default
      metadata.%:       "0" => "1"
…

Apply complete! Resources: 0 added, 1 changed, 0 destroyed.
Use output variables for the IP address
Use a Terraform output variable to act as a helper to expose the instance's ip address. Add the following to the Terraform config:


// A variable for extracting the external IP address of the instance
output "ip" {
 value = google_compute_instance.default.network_interface.0.access_config.0.nat_ip
}
Run terraform apply followed by terraform output ip to return the instance's external IP address. Validate that everything is set up correctly at this point by connecting to that IP address with SSH.

This tutorial needs the default network's default-allow-ssh firewall rule to be in place before you can use SSH to connect to the instance. If you are starting with a new project, this can take a few minutes. You can check the firewall rules list to make sure that the firewall rule has been created.


ssh `terraform output ip`
Building the Flask app
You will be building a Python Flask app for this tutorial so that you can have a single file describing your web server and test endpoints. Inside the VM instance, add the following to a new file called app.py:


from flask import Flask
app = Flask(__name__)

@app.route('/')
def hello_cloud():
   return 'Hello Cloud!'

app.run(host='0.0.0.0')
Then run this command:


python app.py
Flask serves traffic on localhost:5000 by default. Run curl in a separate SSH instance to confirm that your greeting is being returned. To connect to this from your local computer, you must expose port 5000.

Run this command to validate the server:


curl http://0.0.0.0:5000
The output from this command is Hello Cloud.

Open port 5000 on the instance
Google Cloud allows for opening ports to traffic via firewall policies, which can also be managed in your Terraform configuration. Add the following to the config and proceed to run plan/apply to create the firewall rule.


resource "google_compute_firewall" "default" {
 name    = "flask-app-firewall"
 network = "default"

 allow {
   protocol = "tcp"
   ports    = ["5000"]
 }
}
Congratulations! You can now point your browser to the instance's IP address and port 5000 and see your server running.

Cleaning up
Now that you are finished with the tutorial, you will likely want to delete everything that was created so that you don't incur any further costs. Thankfully, Terraform will let you remove all the resources defined in the configuration file with terraform destroy:


terraform destroy
random_id.instance_id: Refreshing state... (ID: ZNS6E3_1miU)
google_compute_firewall.default: Refreshing state... (ID: flask-app-firewall)
google_compute_instance.default: Refreshing state... (ID: flask-vm-64d4ba137ff59a25)

An execution plan has been generated and is shown below.
Resource actions are indicated with the following symbols:
  - destroy

Terraform will perform the following actions:

  - google_compute_firewall.default

  - google_compute_instance.default

  - random_id.instance_id
...

google_compute_firewall.default: Destroying... (ID: flask-app-firewall)
google_compute_instance.default: Destroying... (ID: flask-vm-64d4ba137ff59a25)
google_compute_instance.default: Still destroying... (ID: flask-vm-64d4ba137ff59a25, 10s elapsed)
google_compute_firewall.default: Still destroying... (ID: flask-app-firewall, 10s elapsed)
google_compute_firewall.default: Destruction complete after 11s
google_compute_instance.default: Destruction complete after 18s
random_id.instance_id: Destroying... (ID: ZNS6E3_1miU)
random_id.instance_id: Destruction complete after 0s

# Integration with GitHub
# Url - https://towardsdatascience.com/git-actions-terraform-for-data-engineers-scientists-gcp-aws-azure-448dc7c60fcc

Data Ops – Git Actions & Terraform for Data Engineers & Scientists — GCP/AWS/Azure
Within the next 10 minutes, you will learn something that will enrich your data journey altogether. With this post, Data Engineers and Scientists can CICD Infrastructure with ease.
Gagandeep Singh
Gagandeep Singh

Apr 15·7 min read


I strongly believe in POCing a new design or code template and get it review by other engineers because you never know what efficient nuances you are missing and it is always good to have a fresh set of eyes reviewing the code. And I tend to make POC as near to MVP (Minimum viable product) as possible to make myself and the team more confident of the design and to not waste any time in Regression testing later. It also helps in estimating my delivery task better and more accurately. But issues arise when I have to be dependent upon the DevOps team to ‘Infrastructure as code’ (IAC) my project in the dev environment. In the Prod environment, it is desirable to involve them in DevOps the infrastructure based on the best practices they have learned but in Dev, it can derail your MVP by just waiting for them to prioritize your task.
So a couple of years ago I started learning DevOps/DataOps and I started with Cloudformation (CFN) and Atlassian Bamboo since I was mostly working on AWS and the organization was using Bamboo. But lately, I got the chance to get my hands dirty in Terraform (TF) and Github Actions, because I was required to work on GCP, and dear oh dear it is way too easy to grasp and good to learn because with TF and Actions you can deploy in any cloud. And for a Data Engineer or Scientist or Analyst, it becomes really handy if you know an IAC tool. Since Github Actions sit closer to your code, it becomes all the more convenient for me.
So, I will break this down into 3 easy sections:
Integrating TF cloud to Github
Github Actions workflow to run TF steps
Overview of TF files based on Best Practices
Integrating Terraform cloud to Github
Step 1: First thing first, TF has a community version so go ahead and create an account there. Here is the link: https://www.terraform.io/cloud. It will ask you to confirm your email address and everything so I am assuming that is done at the end of this step. Also, to complete the steps, it would be really great if you have your own account in the GCP or for that matter in any of the cloud. And your own Github account.
Step 2: TF has its hierarchy where each Organization has multiple workspaces and each Workspace has a one-to-one mapping with your IAC Github branch in repo where you will be pushing the updated Terraform files (Best practice). Files are written in Hashicorp Configuration Language (HCL) which is somewhat similar to YAML. So the idea is, whenever you will push a new update (or merge a PR) to a Github branch, Github-actions will execute and run the plan with a new changeset on TF cloud. Since TF cloud is linked to GCP (later), it will update the resource in GCP.

CICD Process flow
Create an organization and workspace inside of it in your Terraform community account.
Step 3: Assumingly, you have your own GCP account, create a service account in your project where you want the resource to be deployed, copy its key and put it in environment variable as GOOGLE_CREDENTIALS in Terraform variable. If you are using AWS then you need to put AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY.


This variable has content of the service account secret in JSON
This GCP Service account will be used to deploy the resource so it should have an Edit role or access level that has authority to deploy the resource.
You can also create a secret in Github secrets as shown below and pass the Credentials from there by using ${{ secrets.GOOGLE_CREDENTIALS }} in Github Actions as I did below.

Step 4: While creating a workspace, it will let you choose the github repo so that it can authenticate with it internally otherwise you have to generate a token in Terraform and save it in Github secrets to be used in ‘Setup Terraform’ step in Github actions.


By choosing any one of these, it automatically will authenticate when required
Github Actions workflow to run TF steps
The following Github actions script needs to be put in .github/workflow/ folder as anyname.yml. This has sequential steps in a particular job on what to do when someone pushes a new change in the repo. In the following, github actions will use bash in ubuntu-latest to checkout the code, setup terraform and run terraform init, plan and apply.
name: 'Terraform CI'
on:
  push:
    branches:
    - main
  pull_request:
jobs:
  terraform:
    name: 'Terraform'
    runs-on: ubuntu-latest
# Use the Bash shell regardless whether the GitHub Actions runner is ubuntu-latest, macos-latest, or windows-latest
    defaults:
      run:
        shell: bash
steps:
    # Checkout the repository to the GitHub Actions runner
    - name: Checkout
      uses: actions/checkout@v2
# Install the latest version of Terraform CLI and configure the Terraform CLI configuration file with a Terraform Cloud user API token
    - name: Setup Terraform
      uses: hashicorp/setup-terraform@v1
# Initialize a new or existing Terraform working directory by creating initial files, loading any remote state, downloading modules, etc.
    - name: Terraform Init
      run: terraform init
      env:
        GOOGLE_CREDENTIALS: ${{ secrets.GOOGLE_CREDENTIALS }}
# Checks that all Terraform configuration files adhere to a canonical format
#    - name: Terraform Format
#      run: terraform fmt -check
# Generates an execution plan for Terraform
    - name: Terraform Plan
      run: terraform plan
      env:
        GOOGLE_CREDENTIALS: ${{ secrets.GOOGLE_CREDENTIALS }}
# On push to main, build or change infrastructure according to Terraform configuration files # && github.event_name == 'push'
      # Note: It is recommended to set up a required "strict" status check in your repository for "Terraform Cloud". See the documentation on "strict" required status checks for more information: https://help.github.com/en/github/administering-a-repository/types-of-required-status-checks
    - name: Terraform Apply
      if: github.ref == 'refs/heads/master'
      run: terraform apply -auto-approve
      env:
        GOOGLE_CREDENTIALS: ${{ secrets.GOOGLE_CREDENTIALS }}

Overview of Terraform files
Now terraform only reads those files that have .tf extension to it or .tfvars but there are some files that it needs to be named as is whereas others are just resource abstraction and will be executed in the no order unless you mention the dependencies using depends_on. Main.tf, variables.tf and terraform.tfvars are the files that need to be created with the same name.

Terraform files for a Data Engineering Project
main.tf: All the resources can be mentioned here with its appropriate configuration values. So for example if you want to create a storage bucket then it can be written in HCL as below:
resource “google_storage_bucket” “bucket” { 
    name = “dev-bucket-random-12345”
}
variables.tf: As the name suggests, it has variables like below with its default value which you want to re-use in other resources or .tf file like ${var.region}. This is more like a convention to put the variables in different variables.tf file but you can put it in main.tf too.
variable “region” { 
    type = string 
    default = “australia-southeast1”
}
terraform.tfvars: This will have the actual values of the variables defined above. Essentially, if region is not mentioned below then it will take the above default value.
project_id = “bstate-xxxx-yyyy”
region = “australia-southeast1”
The rest of the files are to abstract different types of resources into different files. For example networks.tf will have VPC and Subnet resources, stackdriver.tf will have alerts and monitoring dashboards, dataproc.tf will have cluster and nodes resources in it and similarly for firewalls, GKE, etc.
For all those who don’t know, TF and CFN have documentation where these predefined functions or Resource configurations are there to help us understand what options mean. Following is of GCP: https://registry.terraform.io/providers/hashicorp/google/latest/docs
Example Monitoring channel
In the following example, a monitoring channel is created for the Stackdriver alerts. All the fields are self-explanatory and come from the GCP Terraform documentation and with the help of the output variable ‘gsingh_id’, you can directly use it in any .tf file or if you don’t want to specify the output, you can directly use it like this: google_monitoring_notification_channel.gsingh
resource "google_monitoring_notification_channel" "gsingh" {
  display_name = "xxxx@yyyy.com"
  type = "email"
  labels = {
    email_address = "xxxx@yyyy.com"
  }
}

output "gsingh_id" {
  value = "${google_monitoring_notification_channel.gsingh.name}"
}
Below a Subnet is getting created and VPC is specified as a dependency for the subnet in a similar fashion.
resource "google_compute_subnetwork" "vpc_subnetwork" {
  name          = "subnet-01"
  network       = google_compute_network.vpc_network.self_link
  private_ip_google_access = true
  ip_cidr_range = "10.xx.xx.xx/19"
  region        = "australia-southeast1"
  depends_on = [
    google_compute_network.vpc_network,
  ]
}
Conclusion
Now as explained earlier, whenever you push a new change to this repo, Git actions will checkout the code from the master branch and run Terraform Init, Plan and Apply to deploy the changes in the cloud. In the next couple of days, I will be publishing a series of articles on how to Deploy a Flink application on GKE cluster through Git actions which will also let you know how to build a Scala app using Git Actions. So stay tuned.

