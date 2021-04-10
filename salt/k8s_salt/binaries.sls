{% set k8sV = salt['pillar.get']('k8s_salt:version:kubernetes') or '1.21.0' %}
{% set repo = salt['pillar.get']('k8s_salt:k8s_repo_proxy') or 'https://storage.googleapis.com/kubernetes-release/release' %}
{% set arch = salt['pillar.get']('k8s_salt:arch') or salt['grains.get']('osarch') or 'amd64' %}
{% set binaries = [] %}
{% if 'controlplane' in salt['pillar.get']('k8s_salt:roles') %}
{% do binaries.append('kube-apiserer') %}
{% do binaries.append('kube-scheduler') %}
{% do binaries.append('kube-controller-manager') %}
{% endif %}
{% if 'worker' in salt['pillar.get']('k8s_salt:roles') %}
{% do binaries.append('kube-proxy') %}
{% do binaries.append('kubelet') %}
{% endif %}
get_kubernetes_binaries:
  file.managed:
  - names:
{% for binary in binaries %}
    - /usr/local/bin/{{ binary }}:
      - source: {{ repo }}/v{{ k8sV }}/bin/linux/{{ arch }}/{{ binary }}
      - source_hash: {{ repo }}/v{{ k8sV }}/bin/linux/{{ arch }}/{{ binary }}.sha256
      - user: root
      - mode: '0755'
      - makedirs: True
{% endfor %}
