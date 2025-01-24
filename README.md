# Домашнее задание к занятию «Кластеры. Ресурсы под управлением облачных провайдеров»

### Цели задания 

1. Организация кластера Kubernetes и кластера баз данных MySQL в отказоустойчивой архитектуре.
2. Размещение в private подсетях кластера БД, а в public — кластера Kubernetes.

---
## Задание 1. Yandex Cloud

1. Настроить с помощью Terraform кластер баз данных MySQL.

 - Используя настройки VPC из предыдущих домашних заданий, добавить дополнительно подсеть private в разных зонах, чтобы обеспечить отказоустойчивость. 
 - Разместить ноды кластера MySQL в разных подсетях.
 - Необходимо предусмотреть репликацию с произвольным временем технического обслуживания.
 - Использовать окружение Prestable, платформу Intel Broadwell с производительностью 50% CPU и размером диска 20 Гб.
 - Задать время начала резервного копирования — 23:59.
 - Включить защиту кластера от непреднамеренного удаления.
 - Создать БД с именем `netology_db`, логином и паролем.

2. Настроить с помощью Terraform кластер Kubernetes.

 - Используя настройки VPC из предыдущих домашних заданий, добавить дополнительно две подсети public в разных зонах, чтобы обеспечить отказоустойчивость.
 - Создать отдельный сервис-аккаунт с необходимыми правами. 
 - Создать региональный мастер Kubernetes с размещением нод в трёх разных подсетях.
 - Добавить возможность шифрования ключом из KMS, созданным в предыдущем домашнем задании.
 - Создать группу узлов, состояющую из трёх машин с автомасштабированием до шести.
 - Подключиться к кластеру с помощью `kubectl`.
 - *Запустить микросервис phpmyadmin и подключиться к ранее созданной БД.
 - *Создать сервис-типы Load Balancer и подключиться к phpmyadmin. Предоставить скриншот с публичным адресом и подключением к БД.

Полезные документы:

- [MySQL cluster](https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs/resources/mdb_mysql_cluster).
- [Создание кластера Kubernetes](https://cloud.yandex.ru/docs/managed-kubernetes/operations/kubernetes-cluster/kubernetes-cluster-create)
- [K8S Cluster](https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs/resources/kubernetes_cluster).
- [K8S node group](https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs/resources/kubernetes_node_group).

## Решение 1. Yandex Cloud

1. Настроил с помощью Terraform кластер баз данных MySQL.

[main.tf](https://github.com/stepynin-georgy/hw_cloud_4/blob/main/main.tf):

```
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
```

[locals.tf](https://github.com/stepynin-georgy/hw_cloud_4/blob/main/locals.tf):

```
locals {
  network_name     = "develop"
  subnet_name_a    = "public-a-subnet"
  subnet_name_b    = "public-b-subnet"
  subnet_name_pa   = "private-a-subnet"
  subnet_name_pb   = "private-b-subnet"
  disk1_name       = "vm-disk-public"
  disk2_name       = "vm-disk-private"
  vm_nat_name      = "nat-instance"
  vm_private_name  = "vm-private"
  route_table_name = "nat-instance-route"
  folder_id        = "b1gbaccuaasnld9i4p6h"
}
```

[variables.tf](https://github.com/artmur1/23-03-hw/blob/main/files/variables.tf):

```
###cloud vars
variable "default_zone" {
  type        = string
  default     = "ru-central1-b"
  description = "https://cloud.yandex.ru/docs/overview/concepts/geo-scope"
}

variable "vm_resources" { 
  type         = map(map(number))
  default      = {
    nat_res = {
      cores = 2
      memory = 4
      core_fraction = 20
      disk_size = 20
    }
  }
}
```

![изображение](https://github.com/stepynin-georgy/hw_cloud_4/blob/main/img/Screenshot_24.png)

![изображение](https://github.com/stepynin-georgy/hw_cloud_4/blob/main/img/Screenshot_25.png)

![изображение](https://github.com/stepynin-georgy/hw_cloud_4/blob/main/img/Screenshot_26.png)

![изображение](https://github.com/stepynin-georgy/hw_cloud_4/blob/main/img/Screenshot_27.png)

2. Настроил с помощью Terraform кластер Kubernetes.

[main.tf](https://github.com/stepynin-georgy/hw_cloud_4/blob/main/cluster/main.tf):

```
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
```

[locals.tf](https://github.com/stepynin-georgy/hw_cloud_4/blob/main/cluster/locals.tf):

```
locals {
  network_name     = "develop"
  subnet_name_a    = "public-a-subnet"
  subnet_name_b    = "public-b-subnet"
  subnet_name_d    = "public-d-subnet"
  subnet_name_pa   = "private-a-subnet"
  subnet_name_pb   = "private-b-subnet"
  disk1_name       = "vm-disk-public"
  disk2_name       = "vm-disk-private"
  vm_nat_name      = "nat-instance"
  vm_private_name  = "vm-private"
  route_table_name = "nat-instance-route"
  folder_id        = "b1gbaccuaasnld9i4p6h"
}
```

[variables.tf](https://github.com/stepynin-georgy/hw_cloud_4/blob/main/cluster/variables.tf):

```
###cloud vars
variable "default_zone_a" {
  type        = string
  default     = "ru-central1-a"
  description = "https://cloud.yandex.ru/docs/overview/concepts/geo-scope"
}

variable "default_zone_b" {
  type        = string
  default     = "ru-central1-b"
  description = "https://cloud.yandex.ru/docs/overview/concepts/geo-scope"
}

variable "default_zone_d" {
  type        = string
  default     = "ru-central1-d"
  description = "https://cloud.yandex.ru/docs/overview/concepts/geo-scope"
}

variable "token" {
  type        = string
  description = "OAuth-token; https://cloud.yandex.ru/docs/iam/concepts/authorization/oauth-token"
}

variable "cloud_id" {
  type        = string
  description = "https://cloud.yandex.ru/docs/resource-manager/operations/cloud/get-id"
}

variable "folder_id" {
  type        = string
  description = "https://cloud.yandex.ru/docs/resource-manager/operations/folder/get-id"
}

variable "vpc_name" {
  type        = string
  default     = "develop"
  description = "имя сети"
} 

variable "vm_resources" { 
  type         = map(map(number))
  default      = {
    nat_res = {
      cores = 2
      memory = 4
      core_fraction = 20
      disk_size = 20
    }
    priv_res = {
      cores = 2
      memory=2
      core_fraction=20
      disk_size = 20
    }
  }
}
```

![изображение](https://github.com/stepynin-georgy/hw_cloud_4/blob/main/img/Screenshot_28.png)

![изображение](https://github.com/stepynin-georgy/hw_cloud_4/blob/main/img/Screenshot_29.png)

![изображение](https://github.com/stepynin-georgy/hw_cloud_4/blob/main/img/Screenshot_31.png)

![изображение](https://github.com/stepynin-georgy/hw_cloud_4/blob/main/img/Screenshot_32.png)

Установил kubectl:

```
[user@netology opt]$ kubectl version --client --output=yaml
clientVersion:
  buildDate: "2025-01-15T14:40:53Z"
  compiler: gc
  gitCommit: e9c9be4007d1664e68796af02b8978640d2c1b26
  gitTreeState: clean
  gitVersion: v1.32.1
  goVersion: go1.23.4
  major: "1"
  minor: "32"
  platform: linux/amd64
kustomizeVersion: v5.5.0
```

Чтобы получить учетные данные для подключения к публичному IP-адресу кластера через интернет, выполнил команду:

```
    yc managed-kubernetes cluster \
       get-credentials name2 \
       --external

    kubectl cluster-info
```

```
[user@netology opt]$ yc managed-kubernetes cluster get-credentials hw-netology-2 --external

Context 'yc-hw-netology-2' was added as default to kubeconfig '/home/user/.kube/config'.
Check connection to cluster using 'kubectl cluster-info --kubeconfig /home/user/.kube/config'.

Note, that authentication depends on 'yc' and its config profile 'default'.
To access clusters using the Kubernetes API, please use Kubernetes Service Account.
[user@netology opt]$ kubectl cluster-info
Kubernetes control plane is running at https://158.160.156.239
CoreDNS is running at https://158.160.156.239/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.
```

Проверка подключения к кластеру:

```
[user@netology opt]$ kubectl get svc
NAME         TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)   AGE
kubernetes   ClusterIP   10.96.128.1   <none>        443/TCP   20m
[user@netology opt]$ kubectl get nodes
NAME                             STATUS   ROLES    AGE   VERSION
test-ehec-cl1m7h7i0p7qh6ck8ehe   Ready    <none>   16m   v1.28.9
test-ojot-cl1m7h7i0p7qh6ck8ehe   Ready    <none>   16m   v1.28.9
test-unup-cl1m7h7i0p7qh6ck8ehe   Ready    <none>   16m   v1.28.9
[user@netology opt]$ kubectl describe svc kubernetes
Name:                     kubernetes
Namespace:                default
Labels:                   component=apiserver
                          provider=kubernetes
Annotations:              <none>
Selector:                 <none>
Type:                     ClusterIP
IP Family Policy:         SingleStack
IP Families:              IPv4
IP:                       10.96.128.1
IPs:                      10.96.128.1
Port:                     https  443/TCP
TargetPort:               443/TCP
Endpoints:                192.168.10.25:443
Session Affinity:         None
Internal Traffic Policy:  Cluster
Events:                   <none>
```

--- 
## Задание 2*. Вариант с AWS (задание со звёздочкой)

Это необязательное задание. Его выполнение не влияет на получение зачёта по домашней работе.

**Что нужно сделать**

1. Настроить с помощью Terraform кластер EKS в три AZ региона, а также RDS на базе MySQL с поддержкой MultiAZ для репликации и создать два readreplica для работы.
 
 - Создать кластер RDS на базе MySQL.
 - Разместить в Private subnet и обеспечить доступ из public сети c помощью security group.
 - Настроить backup в семь дней и MultiAZ для обеспечения отказоустойчивости.
 - Настроить Read prelica в количестве двух штук на два AZ.

2. Создать кластер EKS на базе EC2.

 - С помощью Terraform установить кластер EKS на трёх EC2-инстансах в VPC в public сети.
 - Обеспечить доступ до БД RDS в private сети.
 - С помощью kubectl установить и запустить контейнер с phpmyadmin (образ взять из docker hub) и проверить подключение к БД RDS.
 - Подключить ELB (на выбор) к приложению, предоставить скрин.

Полезные документы:

- [Модуль EKS](https://learn.hashicorp.com/tutorials/terraform/eks).

### Правила приёма работы

Домашняя работа оформляется в своём Git репозитории в файле README.md. Выполненное домашнее задание пришлите ссылкой на .md-файл в вашем репозитории.
Файл README.md должен содержать скриншоты вывода необходимых команд, а также скриншоты результатов.
Репозиторий должен содержать тексты манифестов или ссылки на них в файле README.md.
