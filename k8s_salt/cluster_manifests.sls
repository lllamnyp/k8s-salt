{% from './map.jinja' import k8s_salt %}

{% if salt['pillar.get']('k8s_salt:roles:admin') %}

Place cluster manifests:
  file.managed:
  - makedirs: True
  - mode: '0644'
  - template: 'jinja'
  - defaults:
      k8s_salt: {{ k8s_salt }}
      cluster: {{ pillar.k8s_salt.cluster }}
  - names:
    - /etc/kubernetes/cluster-wide-manifests/coredns.yml:
      - source: salt://{{ slspath }}/cluster-wide-manifests/coredns.yml
    - /etc/kubernetes/cluster-wide-manifests/cilium.yml:
      - source: salt://{{ slspath }}/cluster-wide-manifests/cilium.yml
    - /etc/kubernetes/cluster-wide-manifests/kubelet-access.yml:
      - source: salt://{{ slspath }}/cluster-wide-manifests/kubelet-access.yml
  cmd.run:
  - names:
    - '/usr/local/bin/kubectl --kubeconfig /etc/kubernetes/config/admin.kubeconfig apply -f /etc/kubernetes/cluster-wide-manifests/'
#       - onchanges:
#         - file: Place cluster manifests


{% endif %}
