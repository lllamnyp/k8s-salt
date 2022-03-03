{% from './map.jinja' import k8s_salt %}

{% if salt['pillar.get']('k8s_salt:roles:admin') %}

Deploy raw addon manifests:
  file.managed:
  - makedirs: True
  - mode: '0644'
  - template: 'jinja'
  - defaults:
      k8s_salt: {{ k8s_salt }}
      cluster: {{ pillar.k8s_salt.cluster }}
  - names:
    - /tmp/dummy.yml
  {% for k, v in k8s_salt['addons'].get('manifests', {}).items() %}
    - /etc/kubernetes/cluster-wide-manifests/{{ k }}.yml:
      - contents_pillar: k8s_salt:addons:manifests:{{ k }}
  {% endfor %}
  cmd.run:
  - names:
    - 'true'
  {% for k, v in k8s_salt['addons'].get('manifests', {}).items() %}
    - '/usr/local/bin/kubectl --kubeconfig /etc/kubernetes/config/admin.kubeconfig apply -f /etc/kubernetes/cluster-wide-manifests/{{ k }}.yml'
  {% endfor %}
{% endif %}
