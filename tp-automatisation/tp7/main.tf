terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5.0"
    }
  }
}

provider "docker" {}

resource "docker_network" "app_network" {
  name = "tp7_network"
}

resource "docker_container" "web" {
  count = 2
  name  = "web-server-${count.index + 1}"
  image = "nginx:alpine"

  networks_advanced {
    name = docker_network.app_network.name
  }

  command = ["nginx", "-g", "daemon off;"]
}

resource "docker_container" "lb" {
  name  = "load-balancer"
  image = "nginx:alpine"

  networks_advanced {
    name = docker_network.app_network.name
  }

  ports {
    internal = 80
    external = 8080
  }
}

resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/templates/inventory.tpl", {
    web_containers = docker_container.web[*].name
    lb_container   = docker_container.lb.name
  })
  filename = "${path.module}/inventory.ini"
}
