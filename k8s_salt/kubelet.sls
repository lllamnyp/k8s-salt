{% from './map.jinja' import k8s_salt %}

{% if ('hostname_fqdn' in k8s_salt) and ('ca_server' in k8s_salt) %}
{% if salt['pillar.get']('k8s_salt:roles:worker') %}

  {% set cluster = salt['pillar.get']('k8s_salt:cluster') %}
# TODO: factor out private key into macro
Kubelet private key:
  x509.private_key_managed:
  - replace: False
  - makedirs: True
  - names:
    - /etc/kubernetes/pki/kubelet-key.pem:
      - bits: 4096

place_kubelet_config:
  file.serialize:
  - makedirs: True
  - name: /etc/kubernetes/config/kubelet-config.yaml
  - dataset: {{ k8s_salt['kubelet']['config'] | yaml }}
  - formatter: yaml

place_kubelet_files:
  file.managed:
  - template: 'jinja'
  - defaults:
      k8s_salt: {{ k8s_salt }}
      component: kubelet
  - makedirs: True
  - names:
    - /etc/kubernetes/config/kubelet.kubeconfig:
      - source: salt://{{ slspath }}/templates/component.kubeconfig
      - mode: '0644'
  x509.certificate_managed:
  - makedirs: True
  - names:
    - /etc/kubernetes/pki/kubelet.pem:
      - CN: system:node:{{ k8s_salt['hostname_fqdn'] }}
      - O: system:nodes
      - ca_server: {{ k8s_salt['ca_server'] }}
      - public_key: /etc/kubernetes/pki/kubelet-key.pem
      - signing_policy: {{ cluster }}_kube-ca
      - keyUsage: "critical Digital Signature, Key Encipherment"
      - extendedKeyUsage: "TLS Web Server Authentication, TLS Web Client Authentication"
      - basicConstraints: "critical CA:FALSE"
      - subjectAltName: "DNS:{{ k8s_salt['hostname_fqdn'] }}, IP Address:{{ k8s_salt['ip'] }}"
      - days_valid: 365
      - days_remaining: 90

place_kubelet_service:
  file.managed:
  - name: /etc/systemd/system/kubelet.service
  - source: salt://{{ slspath }}/templates/component.service
  - mode: '0644'
  - template: jinja
  - defaults:
      k8s_salt: {{ k8s_salt }}
      component: kubelet
      description: Kubernetes Node Agent
      version: {{ k8s_salt['version_kubernetes'] }}
      doc: https://github.com/kubernetes/kubernetes
      service_params: ""
  module.run:
  - name: service.systemctl_reload
  - onchanges:
    - file: place_kubelet_service

run_kubelet_unit:
  service.running:
  - name: kubelet
  - enable: True
  - watch:
    - module: place_kubelet_service

{% endif %}
{% endif %}
