provider "digitalocean" {
  token = "${var.do_token}"
  spaces_access_id  = "${var.access_id}"
  spaces_secret_key = "${var.secret_key}"
}

#Create a Wordpress droplet using the Marketplace
resource "digitalocean_droplet" "scaling-wordpress" {
    image = "wordpress-18-04"
    name = "scaling-wordpress"
    region = "nyc3"
    size = "s-1vcpu-1gb"
    ssh_keys = [
      "${var.ssh_fingerprint}"
    ]
    connection {
      user = "root"
      type = "ssh"
      private_key = "${file(var.pvt_key)}"
      timeout = "2m"
    }
}

#Create a Space
resource "digitalocean_spaces_bucket" "scaling-spaces" {
  name   = "scaling-spaces"
  region = "nyc3"
}

#Create a PostgreSQL dbaas
# Create a new database cluster
resource "digitalocean_database_cluster" "scaling-dbass-postgresql" {
  name = "scaling-dbass-postgresql"
  engine     = "pg"
  version    = "11"
  size       = "db-s-1vcpu-1gb"
  region     = "nyc3"
  node_count = 1
}

resource "digitalocean_database_cluster" "scaling-dbass-mysql" {
  name = "scaling-dbass-mysql"
  engine     = "mysql"
  version    = "8"
  size       = "db-s-1vcpu-1gb"
  region     = "nyc3"
  node_count = 1
}

#Create Kubernetes cluster
resource "digitalocean_kubernetes_cluster" "scaling-k8s" {
  name    = "scaling-k8s"
  region  = "nyc3"
  version = "1.15.5-do.0"

  node_pool {
    name       = "scaling-k8s--pool"
    size       = "s-2vcpu-2gb"
    node_count = 2
  }
}

#Creating a load balancer with two droplets
resource "digitalocean_droplet" "scaling-droplet1" {
    image = "ubuntu-18-04-x64"
    name = "scaling-droplet1"
    region = "nyc3"
    size = "s-1vcpu-1gb"
}

resource "digitalocean_droplet" "scaling-droplet2" {
    image = "ubuntu-18-04-x64"
    name = "scaling-droplet2"
    region = "nyc3"
    size = "s-1vcpu-1gb"
}

resource "digitalocean_certificate" "scaling-certificate" {
  name    = "scaling-certificate"
  type    = "lets_encrypt"
  domains = ["demos.fred.dev"]
}

resource "digitalocean_loadbalancer" "scaling-lbass" {
  name = "scaling-lbass"
  region = "nyc3"

  forwarding_rule {
    entry_port = 443
    entry_protocol = "https"

    target_port = 80
    target_protocol = "http"

    certificate_id = "${digitalocean_certificate.scaling-certificate.id}"
  }

  droplet_ids = [
    "${digitalocean_droplet.scaling-droplet1.id}",
    "${digitalocean_droplet.scaling-droplet2.id}"
  ]
}

#Add those to a project
resource "digitalocean_project" "scaling" {
  name        = "scaling"
  description = "Contains the resources I need for my scaling with DO talk"
  resources   = [
    "${digitalocean_droplet.scaling-wordpress.urn}",
    "${digitalocean_database_cluster.scaling-dbass-postgresql.urn}",
    "${digitalocean_database_cluster.scaling-dbass-mysql.urn}",
    "${digitalocean_loadbalancer.scaling-lbass.urn}",
    "${digitalocean_droplet.scaling-droplet1.urn}",
    "${digitalocean_droplet.scaling-droplet2.urn}",
    "${digitalocean_spaces_bucket.scaling-spaces.urn}",
  ]
}