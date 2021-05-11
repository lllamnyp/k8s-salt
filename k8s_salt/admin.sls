{% from './map.jinja' import k8s_salt %}

### Check if state worth running
{% if salt['pillar.get']('k8s_salt:roles:admin') and k8s_salt is defined %}
{% if 'ca_server' in k8s_salt and k8s_salt['ca_server'] %}

{% set cluster = salt['pillar.get']('k8s_salt:cluster') %}
Place admin kubeconfig:
  file.managed:
  - makedirs: True
  - names:
    - /etc/kubernetes/config/admin.kubeconfig:
      - source: salt://{{ slspath }}/templates/admin.kubeconfig
      - mode: '0644'
      - template: 'jinja'
      - defaults:
          k8s_salt: {{ k8s_salt }}
  
Kubeadmin private key:
  x509.private_key_managed:
  - replace: False
  - makedirs: True
  - names:
    - /etc/kubernetes/pki/admin-key.pem:
      - bits: 4096

Kubeadmin X509 management:
  x509.certificate_managed:
  - makedirs: True
  - names:
    - /etc/kubernetes/pki/admin.pem:
      - CN: kube-admin
      - O: system:masters
      - ca_server: {{ k8s_salt['ca_server'] }}
      - public_key: /etc/kubernetes/pki/admin-key.pem
      - signing_policy: {{ cluster }}_kube-ca
      - keyUsage: "critical Digital Signature, Key Encipherment"
      - extendedKeyUsage: "TLS Web Client Authentication"
      - basicConstraints: "critical CA:FALSE"
      - subjectAltName: >-
          DNS:localhost,
          DNS:{{ salt['grains.get']('k8s_salt:hostname_fqdn') }},
          IP Address:127.0.0.1,
          IP Address:{{ salt['grains.get']('k8s_salt:ip') }}

### End checks if state worth running
{% endif %}
{% endif %}
