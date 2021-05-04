{% if 'ca' in salt['pillar.get']('k8s_salt:roles') %}
  {% set k8s_salt_clusters = [] %}
  {% for cluster in salt['mine.get']('I@k8s_salt:enabled and I@k8s_salt:cluster', 'get_k8s_data', 'compound').values() | map(attribute='cluster') | unique %}
    {% do k8s_salt_clusters.append(cluster) %}
  {% endfor %}
  {% if k8s_salt_clusters %}
Generate k8s CA private keys:
  x509.private_key_managed:
  - replace: False
  - makedirs: True
  - names:
    {% for cluster in k8s_salt_clusters %}
      {% for ca in k8s_salt_cas %}
    - /etc/kubernetes-authority/{{ cluster }}/{{ ca }}-key.pem:
      - bits: 4096
      {% endfor %}
    {% endfor %}

Generate serviceaccount private key:
  x509.private_key_managed:
  - replace: False
  - makedirs: True
  - names:
    {% for cluster in k8s_salt_clusters %}
    - /etc/kubernetes-authority/{{ cluster }}/sa-key.pem:
      - bits: 4096
    {% endfor %}

Generate k8s CA root certs:
  x509.certificate_managed:
  - makedirs: True
  - replace: False
  - names:
    {% for cluster in k8s_salt_clusters %}
      {% for ca in k8s_salt_cas %}
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

{% for cluster in k8s_salt_clusters %}
Serviceaccount keypair of {{ cluster }} to mine:
  module.run:
  - name: mine.send
  - m_name: get_{{ cluster }}_sa_keypair
  - kwargs:
      mine_function: x509.get_pem_entries
      allow_tgt: 'I@k8s_salt:roles:controlplane and I@k8s_salt:cluster:{{ cluster }}'
      allow_tgt_type: compound
  - args:
    - /etc/kubernetes-authority/{{ cluster }}/sa-*.pem
{% endfor %}
{% endif %}

# {% set pem_dict = salt['mine.get']('I@k8s_salt:roles:ca', 'get_authorities', 'compound') %}
# {% if pem_dict %}
#   {% set cluster = salt['pillar.get']('k8s_salt:cluster') %}
#   {% set authorities = pem_dict.popitem()[1] %}
# Place k8s CAs on minions:
#   file.managed:
#   - makedirs: True
#   - names:
#   {% for ca in k8s_salt_cas %}
#     {% if '/etc/kubernetes-authority/' + cluster + '/' + ca + '.pem' in authorities %}
#     - /etc/kubernetes/pki/{{ ca }}.pem:
#       - contents: {{ authorities['/etc/kubernetes-authority/' + cluster + '/' + ca + '.pem']|tojson }}
#     {% endif %}
#   {% endfor %}
# {% endif %}

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
          k8s_salt_cas: {{ k8s_salt_cas }}
          k8s_salt_clusters: {{ k8s_salt_clusters }}
  cmd.run:
  - name: 'salt-call service.restart salt-minion'
  - bg: True
  - onchanges:
    - file: Place signing policy on CA server
{% endif %}
