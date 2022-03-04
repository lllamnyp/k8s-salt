{% from './map.jinja' import k8s_salt %}

{% if ('hostname_fqdn' in k8s_salt) and ('ca_server' in k8s_salt) %}
{% if salt['pillar.get']('k8s_salt:roles:worker') and not k8s_salt['kube-proxy'].get('disabled', False) %}

  {% set cluster = salt['pillar.get']('k8s_salt:cluster') %}
# TODO: factor out private key into macro
Proxy private key:
  x509.private_key_managed:
  - replace: False
  - makedirs: True
  - names:
    - /etc/kubernetes/pki/proxy-key.pem:
      - bits: 4096

place_kubeproxy_config:
  file.serialize:
  - makedirs: True
  - name: /etc/kubernetes/config/kube-proxy-config.yaml
  - dataset: {{ k8s_salt['kube-proxy']['config'] | yaml }}
  - formatter: yaml

place_kubeproxy_files:
  file.managed:
  - makedirs: True
  - template: 'jinja'
  - defaults:
      k8s_salt: {{ k8s_salt | json }}
      component: proxy
  - names:
    - /etc/kubernetes/config/proxy.kubeconfig:
      - source: salt://{{ slspath }}/templates/component.kubeconfig
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
  - source: salt://{{ slspath }}/templates/component.service
  - mode: '0644'
  - template: jinja
  - defaults:
      k8s_salt: {{ k8s_salt | json }}
      component: kube-proxy
      description: Kubernetes Kube Proxy
      version: {{ k8s_salt['version_kubernetes'] }}
      doc: https://github.com/kubernetes/kubernetes
      service_params: |-
        LimitNOFILE=32768
        LimitNOFILESoft=16384

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
{% else %}
Dont run kubeproxy:
  service.dead:
  - name: kube-proxy
  - enable: False
{% endif %}
{% endif %}
