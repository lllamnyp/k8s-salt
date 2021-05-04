{% set k8s_salt_version_kubernetes = salt['pillar.get']('k8s_salt:version:kubernetes') or '1.21.0' %}
{% set k8s_salt_k8s_proxy_repo = salt['pillar.get']('k8s_salt:k8s_proxy_repo') or 'https://storage.googleapis.com/kubernetes-release/release' %}
{% set k8s_salt_arch = salt['pillar.get']('k8s_salt:arch') or salt['grains.get']('osarch') or 'amd64' %}
{% set k8s_salt_binaries = [] %}
{% if 'controlplane' in salt['pillar.get']('k8s_salt:roles') %}
{% do k8s_salt_binaries.append('kube-apiserer') %}
{% do k8s_salt_binaries.append('kube-scheduler') %}
{% do k8s_salt_binaries.append('kube-controller-manager') %}
{% endif %}
{% if 'worker' in salt['pillar.get']('k8s_salt:roles') %}
{% do k8s_salt_binaries.append('kube-proxy') %}
{% do k8s_salt_binaries.append('kubelet') %}
{% endif %}
get_kubernetes_binaries:
  file.managed:
  - names:
{% for binary in k8s_salt_binaries %}
    - /usr/local/bin/{{ binary }}:
      - source: {{ k8s_salt_k8s_proxy_repo }}/v{{ k8s_salt_version_kubernetes }}/bin/linux/{{ k8s_salt_arch }}/{{ binary }}
      - source_hash: {{ k8s_salt_k8s_proxy_repo }}/v{{ k8s_salt_version_kubernetes }}/bin/linux/{{ k8s_salt_arch }}/{{ binary }}.sha256
      - user: root
      - mode: '0755'
      - makedirs: True
{% endfor %}
