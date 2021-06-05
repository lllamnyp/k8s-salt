{% from './map.jinja' import k8s_salt %}

{% if ('hostname_fqdn' in k8s_salt) and ('ca_server' in k8s_salt) %}
{% if salt['pillar.get']('k8s_salt:roles:worker') %}

  {% set cluster = salt['pillar.get']('k8s_salt:cluster') %}
# TODO: factor out private key into macro
Proxy private key:
  x509.private_key_managed:
  - replace: False
  - makedirs: True
  - names:
    - /etc/kubernetes/pki/proxy-key.pem:
      - bits: 4096

place_kubeproxy_files:
  file.managed:
  - makedirs: True
  - names:
    - /etc/kubernetes/config/kube-proxy-config.yaml:
      - source: salt://{{ slspath }}/templates/kube-proxy-config.yaml
      - mode: '0644'
      - template: jinja
      - defaults:
          k8s_salt: {{ k8s_salt }}
    - /etc/kubernetes/config/proxy.kubeconfig:
      - source: salt://{{ slspath }}/templates/proxy.kubeconfig
      - mode: '0644'
      - template: 'jinja'
  x509.certificate_managed:
  - makedirs: True
  - names:
    - /etc/kubernetes/pki/proxy.pem:
      - ca_server: {{ k8s_salt['ca_server'] }}
      - public_key: /etc/kubernetes/pki/proxy-key.pem
      - signing_policy: {{ cluster }}_kube-ca
      - CN: system:kube-proxy
      - O: system:node-proxier
      - keyUsage: "critical Digital Signature, Key Encipherment"
      - extendedKeyUsage: "TLS Web Server Authentication, TLS Web Client Authentication"
      - basicConstraints: "critical CA:FALSE"

place_kubeproxy_service:
  file.managed:
  - name: /etc/systemd/system/kube-proxy.service
  - source: salt://{{ slspath }}/templates/kube-proxy.service
  - mode: 644
  - template: jinja
  - defaults:
      k8s_salt: {{ k8s_salt }}

reload_kubeproxy_service:
  module.run:
  - name: service.systemctl_reload
  - onchanges:
    - file: place_kubeproxy_service

run_kubeproxy_unit:
  service.running:
  - name: kube-proxy
  - enable: True
  - watch:
    - module: reload_kubeproxy_service
{% endif %}
{% endif %}
