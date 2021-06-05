{% from './map.jinja' import k8s_salt %}

{% if salt['pillar.get']('k8s_salt:roles:admin') %}
{% set cluster = salt['pillar.get']('k8s_salt:cluster') %}
{% set admin_machines = salt['mine.get']('I@k8s_salt:roles:admin:True and I@k8s_salt:cluster:' + cluster, 'get_k8s_data', 'compound') %}
{% if admin_machines | length > 0 %}
{% if salt['grains.get']('id') == admin_machines.popitem()[0] %}

Place cluster manifests:
  file.managed:
  - makedirs: True
  - mode: '0644'
  - template: 'jinja'
  - defaults:
      k8s_salt: {{ k8s_salt }}
    cluster: {{ cluster }}
  - names:
    - /etc/kubernetes/cluster-wide-manifests/cilium.yml:
      - source: salt://{{ slspath }}/cluster-wide-manifests/cilium.yml
    - /etc/kubernetes/cluster-wide-manifests/kubelet-access.yml:
      - source: salt://{{ slspath }}/cluster-wide-manifests/kubelet-access.yml
#   cmd.run:
#   - names:
#     - '/usr/local/bin/kubectl --kubeconfig /etc/kubernetes/config/admin.kubeconfig apply -f /etc/kubernetes/cluster-wide-manifests/':
#       - onchanges:
#         - file: Place cluster manifests


{% endif %}
{% endif %}
{% endif %}
