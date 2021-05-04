{% set k8s_salt_version_etcd = salt['pillar.get']('k8s_salt:version:etcd') or 'v3.4.15' %}
{% set k8s_salt_etcd_proxy_repo = salt['pillar.get']('k8s_salt:etcd_proxy_repo') or 'https://github.com/etcd-io/etcd/releases/download' %}
{% set k8s_salt_arch = salt['pillar.get']('k8s_salt:arch') or salt['grains.get']('osarch') or 'amd64' %}
{% set k8s_salt_cas = ['kube-ca','etcd-peer-ca','etcd-trusted-ca','etcd-server-ca','requestheader-ca'] %}

# Try to infer the node's IP 
# TODO: this ain't easy. There will be a bunch of edge cases to sort out.
{% if salt['pillar.get']('k8s_salt:ipv6') %}
  {% if salt['pillar.get']('k8s_salt:network_interface') %}
    {% set k8s_salt_network_interface = salt['pillar.get']('k8s_salt:network_interface') %}
    {% set k8s_salt_ip = salt['grains.get']('ip6_interfaces')[k8s_salt_network_interface] | first %}
  {% else %} 
    {% set k8s_salt_ip = salt['grains.get']('fqdn_ip6') | first %}
  {% endif %}
{% else %}
  {% if salt['pillar.get']('k8s_salt:network_interface') %}
    {% set k8s_salt_network_interface = salt['pillar.get']('k8s_salt:network_interface') %}
    {% set k8s_salt_ip = salt['grains.get']('ip4_interfaces')[k8s_salt_network_interface] | first %}
  {% else %} 
    {% set k8s_salt_ip = salt['grains.get']('fqdn_ip4') | first %}
  {% endif %}
{% endif %}
