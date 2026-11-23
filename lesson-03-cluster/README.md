# Код до заняття 3: Kubernetes на Proxmox

Цей каталог містить приклад, який:

1. Клонує з Proxmox три Ubuntu 24.04 cloud-init VM за допомогою Terraform.
2. Налаштовує вузли та встановлює `containerd`, `kubeadm`, `kubelet` і `kubectl` через Ansible.
3. Ініціалізує один control-plane вузол, встановлює Flannel CNI та приєднує два worker-вузли.
4. Перевіряє, що всі вузли перейшли у стан `Ready`.

Це навчальний одно-control-plane кластер, не production-конфігурація і не HA-кластер. Код параметризований: перед запуском потрібно підставити реальні імена Proxmox вузла, VM-шаблону, bridge, адреси, шлюз і ресурси. Ці значення не можна надійно вгадати без доступу до конкретного Proxmox.

## Передумови

- Proxmox VE із доступним API та cloud-init шаблоном **Ubuntu 24.04 amd64**.
- У шаблоні встановлено QEMU Guest Agent; його cloud-init user має дозволяти SSH ключем і `sudo`.
- Шаблон і VM створюються на одному Proxmox вузлі. Шаблон має бути підготовлений так, щоб повні клони мали окремі MAC-адреси та cloud-init диски.
- Для control-plane та worker-ів є достатньо CPU/RAM, унікальні VM ID й статичні IP-адреси.
- VM мають бачити одна одну в приватній мережі, мати DNS і доступ до пакетних репозиторіїв та образів.
- Terraform 1.9+ та Ansible Core 2.15+ на робочій машині.
- SSH key pair для доступу до Linux VM.

Приклад у `terraform.tfvars.example` використовує `192.0.2.0/24`, TEST-NET діапазон для документації. Він **не маршрутизується**: замініть усі ці адреси на вільні адреси своєї лабораторної VLAN.

Поточний приклад зафіксовано на провайдері `bpg/proxmox` версії `0.123.x` та Kubernetes minor `v1.37`. Перед запуском звірте сумісність провайдера з версією вашого Proxmox та чинну політику Kubernetes. У документації провайдера основною ціллю є Proxmox VE 9.x; для Proxmox 8.x є обмеження, а Proxmox 7.x не підтримується цією лінійкою.

## 1. Підготовка Terraform

```bash
cd lesson-03-cluster/terraform
cp terraform.tfvars.example terraform.tfvars
```

Відредагуйте `terraform.tfvars`: задайте endpoint свого Proxmox API, ім'я Proxmox вузла, ID cloud-init шаблону, bridge, gateway, доступні DNS-сервери, SSH key paths, VM IDs, IP-и та ресурси. Для вашого середовища в `proxmox_endpoint` локально вкажіть наданий вами Proxmox URL; `terraform.tfvars` вже ігнорується Git.

API token не записуйте ні у `.tf` файли, ні у `terraform.tfvars`. Передайте його у змінній середовища `PROXMOX_VE_API_TOKEN` або через локальне сховище секретів. Не вимикайте TLS-перевірку у провайдері; якщо Proxmox використовує внутрішній CA, додайте цей CA до довірених на робочій машині.

## 2. Створення VM

Перевірте, що Terraform встановлений, файли відформатовані та план створює тільки ресурси навчальної лабораторії:

```bash
terraform fmt -check
terraform init
terraform validate
terraform plan -out=tfplan
terraform show tfplan
```

Лише після перегляду плану:

```bash
terraform apply tfplan
mkdir -p ../ansible/inventory
terraform output -raw ansible_inventory > ../ansible/inventory/hosts.yml
```

План `tfplan`, state і локальні tfvars містять дані про інфраструктуру; не комітьте їх. `terraform destroy` знищить створені Terraform VM — перед ним обов'язково створіть та перегляньте окремий destroy plan.

## 3. Налаштування вузлів через Ansible

З каталогу `lesson-03-cluster/ansible`:

```bash
cd ../ansible
```

У `ansible.cfg` перевірка SSH host key увімкнена. Перед першим запуском Ansible звірте fingerprint кожної VM через Proxmox console, а потім підключіться до VM по SSH і підтвердьте лише перевірений ключ. Не вимикайте host-key checking для обходу цього кроку.

Після перевірки SSH host keys:

```bash
ansible-inventory --graph
ansible all -m ping
ansible-playbook --syntax-check site.yml
ansible-playbook site.yml
```

У `group_vars/all.yml` зафіксовані Kubernetes minor, Pod CIDR, CRI socket і версія Flannel. Якщо змінюєте Pod CIDR або версії, перевірте їхню сумісність і змінюйте значення узгоджено. Під час виконання playbook join token генерується тимчасово, прихований від Ansible output і передається лише worker-вузлам.

## 4. Перевірка

Ansible налаштовує kubeconfig користувача, під яким ви підключилися до control-plane VM. Під'єднайтеся до неї та перевірте:

```bash
kubectl get nodes -o wide
kubectl get pods -A
```

Очікувано всі вузли мають бути `Ready`, а системні Pod-и — працювати. `NotReady` до встановлення CNI є очікуваним; якщо стан не змінився після playbook, перевірте `kubectl describe node`, події, мережеву доступність і журнали компонентів.

API Proxmox не надається курсантам. Для наступних практичних видайте їм окремі обмежені kubeconfig/namespace, а не admin kubeconfig із control-plane VM.

## Мережева модель

- Proxmox API використовується лише з машини адміністратора та не має бути відкритим у публічний інтернет.
- Вузли мають зв'язок між собою та з необхідними репозиторіями.
- Kubernetes API слухає TCP 6443; обмежте доступ до нього лабораторною мережею.
- Flannel VXLAN за типової конфігурації використовує UDP 8472 між вузлами. Дозвольте його лише всередині мережі кластера, якщо між VM є firewall.
- Pod CIDR `10.244.0.0/16` не повинен перетинатися з адресами Proxmox/VLAN/маршрутами лабораторії.

## Очищення лабораторії

Видаляйте тільки ці тестові VM після перевірки, що вони належать цьому Terraform state:

```bash
terraform plan -destroy -out=tfplan
terraform show tfplan
terraform apply tfplan
```

Не використовуйте `destroy` у спільному або чужому Terraform state.

## Типові проблеми

| Симптом | Перевірка |
|---|---|
| Terraform не може клонувати шаблон | PVE API endpoint, сертифікат, права токена, ID шаблону та його доступність на вузлі |
| Terraform не бачить IP або Ansible не підключається | Cloud-init, статична адреса/шлюз, QEMU guest agent, SSH public key та користувач |
| `kubeadm init` падає на runtime | Стан `containerd`, CRI plugin, socket `/run/containerd/containerd.sock`, `SystemdCgroup` |
| Вузли не `Ready` після `init` | CNI manifest, Pod CIDR, мережа між VM, відсутність перетину CIDR |
| `ImagePullBackOff` у системних Pod-ів | DNS/маршрут і доступ вузлів до registry |
| Worker не приєднується | API TCP 6443 доступний, token не прострочений; повторити playbook, щоб створити короткоживучий token |

## Офіційні джерела

- [bpg/proxmox provider](https://github.com/bpg/terraform-provider-proxmox)
- [Ресурс VM `proxmox_virtual_environment_vm`](https://github.com/bpg/terraform-provider-proxmox/blob/main/docs/resources/virtual_environment_vm.md)
- [Створення VM з cloud-init image](https://github.com/bpg/terraform-provider-proxmox/blob/main/docs/guides/cloud-image.md)
- [Офіційна інструкція встановлення kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/)
- [Створення кластера kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/)
- [Container runtimes та cgroup driver](https://kubernetes.io/docs/setup/production-environment/container-runtimes/)
