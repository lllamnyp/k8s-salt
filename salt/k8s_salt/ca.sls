{% set cas = ['kube-ca','etcd-ca','requestheader-ca'] %}
Send list of registered clusters to mine:
  grains.present:
  - name: k8s_salt:cluster
  - value: {{ salt['pillar.get']('k8s_salt:cluster') }}
  module.run:
  - name: mine.send
  - m_name: get_clusters
  - kwargs:
      mine_function: grains.get
  - args:
    - k8s_salt:cluster

{% if 'ca' in salt['pillar.get']('k8s_salt:roles') %}
  {% set clusters = [] %}
  {% for cluster in salt['mine.get']('*', 'get_clusters').values() %}
    {% do clusters.append(cluster) %}
  {% endfor %}
  {% if clusters %}
Generate k8s CA private keys:
  x509.private_key_managed:
  - replace: False
  - makedirs: True
  - names:
    {% for cluster in clusters %}
      {% for ca in cas %}
    - /etc/kubernetes-authority/{{ cluster }}/{{ ca }}-key.pem:
      - bits: 4096
      {% endfor %}
    {% endfor %}

Generate k8s CA root certs:
  x509.certificate_managed:
  - makedirs: True
  - replace: False
  - names:
    {% for cluster in clusters %}
      {% for ca in cas %}
    - /etc/kubernetes-authority/{{ cluster }}/{{ ca }}.pem:
      - CN: kube-ca
      - signing_private_key: /etc/kubernetes-authority/{{ cluster }}/{{ ca }}-key.pem
      - basicConstraints: "critical CA:true"
      - keyUsage: "critical cRLSign, keyCertSign"
      - subjectKeyIdentifier: hash
      - authorityKeyIdentifier: keyid,issuer:always
      - days_valid: 3650
      - days_remaining: 0
      - require:
        - x509: Generate k8s CA private keys
      {% endfor %}
    {% endfor %}
  {% endif %}

Make k8s CAs available in salt mine:
  # TODO: This is deprecated `module.run` syntax, to be changed in Salt Sodium.
  module.run:
  - name: mine.send
  - m_name: get_authorities
  - kwargs:
      mine_function: x509.get_pem_entries
  - args:
    - /etc/kubernetes-authority/*/*-ca.pem
  #   - onchanges:
  #     - x509: ca_root_cert
{% endif %}

{% set pem_dict = salt['mine.get']('*', 'get_authorities') %}
{% if pem_dict %}
  {% set cluster = salt['pillar.get']('k8s_salt:cluster') %}
  {% set authorities = pem_dict.popitem()[1] %}
Place k8s CAs on minions:
  file.managed:
  - names:
  {% for ca in cas %}
    {% if '/etc/kubernetes-authority/' + cluster + '/' + ca + '.pem' in authorities %}
    - /etc/kubernetes/pki/{{ ca }}.pem:
      - contents: {{ authorities['/etc/kubernetes-authority/' + cluster + '/' + ca + '.pem']|tojson }}
    {% endif %}
  {% endfor %}
{% endif %}

{% if salt['service.status']('salt-master') %}
Allow minions to request certs:
  file.managed:
  - names:
    - /etc/salt/master.d/peer.conf:
      - source: salt://k8s_salt/templates/peer.conf
{% endif %}

{% if 'ca' in salt['pillar.get']('k8s_salt:roles') %}
Place signing policy on CA server:
  file.managed:
  - names:
    - /etc/salt/minion.d/signing_policies.conf:
      - source: salt://k8s_salt/templates/signing_policies.conf
      - template: jinja
      - defaults:
          cas: {{ cas }}
          clusters: {{ clusters }}
  cmd.run:
  - name: 'salt-call service.restart salt-minion'
  - bg: True
  - onchanges:
    - file: Place signing policy on CA server
{% endif %}
