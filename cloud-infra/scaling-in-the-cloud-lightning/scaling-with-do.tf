provider "digitalocean" {
  token = var.do_token
}

#Create a Wordpress droplet using the Marketplace
resource "digitalocean_droplet" "scaling-wordpress" {
  image  = "wordpress-18-04"
  name   = "scaling-wordpress"
  region = "nyc3"
  size   = "s-1vcpu-1gb"
  ssh_keys = [
    var.ssh_fingerprint,
  ]
  connection {
    host        = self.ipv4_address
    user        = "root"
    type        = "ssh"
    private_key = file(var.pvt_key)
    timeout     = "2m"
  }
}

#Create a MySQL dbaas
resource "digitalocean_database_cluster" "scaling-dbass-mysql" {
  name       = "scaling-dbass-mysql"
  engine     = "mysql"
  version    = "8"
  size       = "db-s-1vcpu-1gb"
  region     = "nyc3"
  node_count = 1
}

#Add those to a project
resource "digitalocean_project" "scaling" {
  name        = "scaling"
  description = "Contains the resources I need for my scaling with DO talk"
  resources = [
    digitalocean_droplet.scaling-wordpress.urn,
    digitalocean_database_cluster.scaling-dbass-mysql.urn,
  ]
}

