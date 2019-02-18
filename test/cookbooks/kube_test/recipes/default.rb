# Client

remote_file 'kubectl binary' do
  path '/usr/bin/kubectl'
  mode '0755'
  source 'https://storage.googleapis.com/kubernetes-release/release'\
         '/v1.9.2/bin/linux/amd64/kubectl'
  checksum '455999c8232c57748f4cee4b5446ee39fe8af093434d732ddcd628a02f3d9118'
end

# Master

etcd_service 'default' do
  action %w(create start)
end # Needed by the kube_apiserver[default]

kube_apiserver 'default' do
  service_cluster_ip_range '10.0.0.1/24'
  etcd_servers 'http://127.0.0.1:2379'
  insecure_bind_address '0.0.0.0' # for convenience
  allow_privileged true
  action %w(create start)
end

group 'docker' do
  members %w(kubernetes)
end

kube_scheduler 'default' do
  master '127.0.0.1:8080' # make sure to include the port!
  action %w(create start)
end

kube_controller_manager 'default' do
  master '127.0.0.1:8080' # make sure to include the port!
  action %w(create start)
end

# Node

if platform_family?('debian')
  package 'apt-transport-https'

  apt_update
end

docker_service 'default' do
  iptables false
  ip_masq false
  storage_driver node['kube_test']['docker']['storage_driver']
  install_method 'tarball'
  version '18.06.0'
end # needed by kubelet_service[default]

kubelet_service 'default' do
  config '/var/lib/kubelet/config.yaml'
  kubeconfig '/etc/kubernetes/kubelet.conf'
  pod_manifest_path '/etc/kubernetes/manifests'
  cluster_dns '10.96.0.10'
  cluster_domain 'cluster.local'
  fail_swap_on false
  action %w(create start)
end

kube_proxy 'default' do
  master '127.0.0.1:8080' # make sure to include the port!
  action %w(create start)
end

# test running a sample pod
directory '/etc/kubernetes/manifests' do
  recursive true
end

t = template '/etc/kubernetes/manifests/busybox.yaml'

execute 'kubectl create -f /etc/kubernetes/manifests/busybox.yaml' do
  action :nothing
  subscribes :run, "template[#{t.name}]", :immediately
end
