# TODO: needs validity checks (if k8s_salt is defined, etc)
{% from './map.jinja' import k8s_salt %}

{% if salt['pillar.get']('k8s_salt:roles:controlplane') %}

  {% set cluster = salt['pillar.get']('k8s_salt:cluster') %}

Controller-manager private key:
  x509.private_key_managed:
  - replace: False
  - makedirs: True
  - names:
    - /etc/kubernetes/pki/controller-key.pem:
      - bits: 4096

place_controller_files:
  file.managed:
  - makedirs: True
  - names:
    - /etc/kubernetes/config/controller.kubeconfig:
      - source: salt://{{ slspath }}/templates/controller.kubeconfig
        mode: '0644'
  x509.certificate_managed:
  - makedirs: True
  - names:
    - /etc/kubernetes/pki/controller.pem:
      - CN: system:kube-controller-manager
      - ca_server: {{ k8s_salt['ca_server'] }}
      - public_key: /etc/kubernetes/pki/controller-key.pem
      - signing_policy: {{ cluster }}_kube-ca
      - keyUsage: "critical Digital Signature, Key Encipherment"
      - extendedKeyUsage: "TLS Web Client Authentication"

place_controller_service:
  file.managed:
  - name: /etc/systemd/system/kube-controller-manager.service
  - source: salt://{{ slspath }}/templates/kube-controller-manager.service
  - mode: '0644'
  - template: 'jinja'
  - defaults:
      k8s_salt: {{ k8s_salt }}
  module.run:
  - name: service.systemctl_reload
  - onchanges:
    - file: place_controller_service

run_controller_unit:
  service.running:
  - name: kube-controller-manager
  - enable: True
  - watch:
    - module: place_controller_service
{% endif %}
