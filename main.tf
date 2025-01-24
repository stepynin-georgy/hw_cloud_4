terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"
}

provider "yandex" {
    token     = var.token
    cloud_id  = var.cloud_id
    folder_id = var.folder_id
 }

resource "yandex_mdb_mysql_database" "netology_db" {
  cluster_id = yandex_mdb_mysql_cluster.hw-netology.id
  name       = "netology_db"
}

resource "yandex_mdb_mysql_user" "netology" {
  cluster_id = yandex_mdb_mysql_cluster.hw-netology.id
  name       = "netology"
  password   = "netology"

  permission {
    database_name = yandex_mdb_mysql_database.netology_db.name
    roles         = ["ALL"]
  }

  connection_limits {
    max_questions_per_hour   = 10
    max_updates_per_hour     = 20
    max_connections_per_hour = 30
    max_user_connections     = 40
  }

  global_permissions = ["PROCESS"]

  authentication_plugin = "SHA256_PASSWORD"
}

resource "yandex_mdb_mysql_cluster" "hw-netology" {
  name        = "hw-netology"
  environment = "PRESTABLE"
  network_id  = yandex_vpc_network.develop.id
  version     = "8.0"
  deletion_protection = true

  resources {
    resource_preset_id = "b1.medium"
    disk_type_id       = "network-hdd"
    disk_size          = 20
  }

  maintenance_window {
    type = "WEEKLY"
    day  = "SAT"
    hour = 12
  }

  backup_window_start {
    hours = 23
    minutes = 59
  }

  host {
    zone      = "ru-central1-a"
    name      = "na-1"
    subnet_id = yandex_vpc_subnet.public-a.id
  }

  host {
    zone      = "ru-central1-a"
    name      = "na-2"
    subnet_id = yandex_vpc_subnet.public-a.id
  }

  host {
    zone                    = "ru-central1-b"
    name                    = "nb-1"
    replication_source_name = "na-1"
    subnet_id               = yandex_vpc_subnet.public-b.id
  }

  host {
    zone                    = "ru-central1-b"
    name                    = "nb-2"
    replication_source_name = "nb-1"
    subnet_id               = yandex_vpc_subnet.public-b.id
  }
}

resource "yandex_vpc_network" "develop" {
  name = local.network_name
}

resource "yandex_vpc_subnet" "public-a" {
  name           = local.subnet_name_a
  zone           = var.default_zone_a
  network_id     = yandex_vpc_network.develop.id
  v4_cidr_blocks = ["192.168.10.0/24"]
}

resource "yandex_vpc_subnet" "public-b" {
  name           = local.subnet_name_b
  zone           = var.default_zone_b
  network_id     = yandex_vpc_network.develop.id
  v4_cidr_blocks = ["192.168.20.0/24"]
}

resource "yandex_vpc_subnet" "private-a" {
  name           = local.subnet_name_pa
  v4_cidr_blocks = ["192.168.30.0/24"]
  zone           = var.default_zone_a
  network_id     = yandex_vpc_network.develop.id
}

resource "yandex_vpc_subnet" "private-b" {
  name           = local.subnet_name_pb
  v4_cidr_blocks = ["192.168.40.0/24"]
  zone           = var.default_zone_a
  network_id     = yandex_vpc_network.develop.id
}

