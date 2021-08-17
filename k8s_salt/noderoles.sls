Create file with roles:
  file.managed:
  - makedirs: True
  - template: 'jinja'
  - names:
    - /etc/kubernetes/roles/roles.json:
      - source: salt://{{ slspath }}/templates/roles.json

{% if salt['pillar.get']('k8s_salt:roles:admin') %}
Deploy node-role daemon:
  file.managed:
  - makedirs: True
  - mode: '0644'
  - names:
    - /etc/kubernetes/cluster-wide-manifests/node-roles.yml:
      - source: salt://{{ slspath }}/cluster-wide-manifests/node-roles.yml
  cmd.run:
  - names:
    - '/usr/local/bin/kubectl --kubeconfig /etc/kubernetes/config/admin.kubeconfig apply -f /etc/kubernetes/cluster-wide-manifests/node-roles.yml'
  - require:
    - file: Deploy node-role daemon
    - file: Create file with roles
{% endif %}
