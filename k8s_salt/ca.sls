{% from './map.jinja' import k8s_salt %}

{% set clusters = salt['mine.get']('I@k8s_salt:enabled and I@k8s_salt:cluster', 'get_k8s_cluster', 'compound').values() | unique %}

### Check if state worth running
{% if clusters | length > 0 and k8s_salt is defined %}
{% if ('ip' in k8s_salt) and ('cas' in k8s_salt) and (k8s_salt['cas'] | length > 0) %}

{% if salt['pillar.get']('k8s_salt:roles:ca') %}
Generate k8s CA private keys:
  x509.private_key_managed:
  - replace: False
  - makedirs: True
  - names:
  {% for cluster in clusters %}
    {% for ca in k8s_salt['cas'] %}
    - /etc/kubernetes-authority/{{ cluster }}/{{ ca }}-key.pem:
      - bits: 4096
    {% endfor %}
  {% endfor %}

Generate serviceaccount private key:
  x509.private_key_managed:
  - replace: False
  - makedirs: True
  - bits: 4096
  - names:
  {% for cluster in clusters %}
    - /etc/kubernetes-authority/{{ cluster }}/sa-key.pem
  {% endfor %}

Generate corresponding sa public key:
  x509.pem_managed:
  - makedirs: True
  - names:
    # Just in case there are no matching roles
    - /etc/kubernetes/pki/dummy.pem:
      - text: |-
          -----BEGIN PUBLIC KEY-----
          MIIC
          -----END PUBLIC KEY-----
  {% for cluster in clusters %}
    {% if salt['file.file_exists']('/etc/kubernetes-authority/' + cluster + '/sa-key.pem') -%}
    - /etc/kubernetes-authority/{{ cluster }}/sa.pem:
      - text: {{ salt['x509.get_public_key']('/etc/kubernetes-authority/' + cluster + '/sa-key.pem') }}
    {% endif %}
  {% endfor %}

  - require:
    - x509: Generate serviceaccount private key

Generate k8s CA root certs:
  x509.certificate_managed:
  - makedirs: True
  - replace: False
  - names:
  {% for cluster in clusters %}
    {% for ca in k8s_salt['cas'] %}
    - /etc/kubernetes-authority/{{ cluster }}/{{ ca }}.pem:
      - CN: {{ ca }}
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

  {% for cluster in clusters %}
Serviceaccount keypair of {{ cluster }} to mine:
  module.run:
  - name: mine.send
  - m_name: get_{{ cluster }}_sa_keypair
  - kwargs:
      mine_function: x509.get_pem_entries
      allow_tgt: 'I@k8s_salt:roles:controlplane:True and I@k8s_salt:cluster:{{ cluster }}'
      allow_tgt_type: compound
  - args:
    - /etc/kubernetes-authority/{{ cluster }}/sa-*.pem
  {% endfor %}

Create directory for copypath:
  file.directory:
  - name: /etc/pki/issued_certs

Place signing policy on CA server:
  file.managed:
  - names:
    - /etc/salt/minion.d/signing_policies.conf:
      - source: salt://k8s_salt/templates/signing_policies.conf
      - template: jinja
      - defaults:
          k8s_salt: {{ k8s_salt }}
          clusters: {{ clusters }}
  cmd.run:
  - name: 'sleep 5; salt-call service.restart salt-minion'
  - bg: True
  - onchanges:
    - file: Place signing policy on CA server
{% endif %}

# End check if state worth running
{% endif %}
{% endif %}

# This happens on potentially different machine so can run anyway
{% if salt['service.status']('salt-master') %}
Allow minions to request certs:
  file.managed:
  - names:
    - /etc/salt/master.d/peer.conf:
      - source: salt://k8s_salt/templates/peer.conf
  cmd.run:
  - name: 'sleep 5; salt-call service.restart salt-master'
  - bg: True
  - onchanges:
    - file: Allow minions to request certs
{% endif %}

