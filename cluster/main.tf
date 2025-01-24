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


resource "yandex_kubernetes_cluster" "regional_cluster_resource_name" {
  name        = "hw-netology-2"
  description = "description"
  network_id = yandex_vpc_network.develop.id
  master {
    master_location {
      zone      = yandex_vpc_subnet.public-a.zone
      subnet_id = yandex_vpc_subnet.public-a.id
   }
    master_location {
      zone      = yandex_vpc_subnet.public-b.zone
      subnet_id = yandex_vpc_subnet.public-b.id
    }
    master_location {
      zone      = yandex_vpc_subnet.public-d.zone
      subnet_id = yandex_vpc_subnet.public-d.id
    }
    

    public_ip = true

   # security_group_ids = ["${yandex_vpc_security_group.security_group_name.id}"]

    maintenance_policy {
      auto_upgrade = true

#      maintenance_window {
#        start_time = "15:00"
#        duration   = "3h"
#      }
    }

    master_logging {
      enabled                    = true
      kube_apiserver_enabled     = true
      cluster_autoscaler_enabled = true
      events_enabled             = true
      audit_enabled              = true
    }
  }

  service_account_id      = yandex_iam_service_account.sa.id
  node_service_account_id = yandex_iam_service_account.sa.id

  labels = {
    my_key       = "my_value"
    my_other_key = "my_other_value"
  }

  release_channel         = "RAPID"
  network_policy_provider = "CALICO"

  kms_provider {
    key_id = yandex_kms_symmetric_key.key-a.id
  }

  depends_on = [
    yandex_vpc_subnet.public-a,
    yandex_vpc_subnet.public-b,
    yandex_vpc_subnet.public-d
  ]

}

// Create SA
resource "yandex_iam_service_account" "sa" {
  folder_id = local.folder_id
  name      = "tf-test-sa"
}

// Grant permissions
resource "yandex_resourcemanager_folder_iam_member" "sa-editor" {
  folder_id = local.folder_id
  role      = "editor"
  member    = "serviceAccount:${yandex_iam_service_account.sa.id}"
}

// Create Static Access Keys
resource "yandex_iam_service_account_static_access_key" "sa-static-key" {
  service_account_id = yandex_iam_service_account.sa.id
  description        = "static access key for object storage"
}

resource "yandex_kms_symmetric_key" "key-a" {
  name              = "example-symetric-key"
  description       = "description for key"
  default_algorithm = "AES_128"
  rotation_period   = "8760h" // equal to 1 year
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

resource "yandex_vpc_subnet" "public-d" {
  name           = local.subnet_name_d
  zone           = var.default_zone_d
  network_id     = yandex_vpc_network.develop.id
  v4_cidr_blocks = ["192.168.30.0/24"]
}

resource "yandex_kubernetes_node_group" "k8s-ng" {
  cluster_id = yandex_kubernetes_cluster.regional_cluster_resource_name.id
  name        = "k8s-ng"
  description = "node group"
  version     = "1.28"
  instance_template {
    name = "test-{instance.short_id}-{instance_group.id}"
    platform_id = "standard-v3"
    network_acceleration_type = "standard"
    network_interface {
      nat        = true
      subnet_ids = ["${yandex_vpc_subnet.public-b.id}"]
    }

    resources {
      memory = 2
      cores  = 2
      core_fraction = 20
    }

    boot_disk {
      type = "network-hdd"
      size = 50
    }

    scheduling_policy {
      preemptible = true
    }

    container_runtime {
      type = "containerd"
    }

    metadata = {
      user-data = "${file("./meta.yml")}"
    }

  }

  scale_policy {
    auto_scale {
      min     = 3
      max     = 6
      initial = 3
    }
  }

  allocation_policy {
    location {
      zone = "ru-central1-b"
    }
  }

}
