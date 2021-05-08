{% from './map.jinja' import k8s_salt %}

# TODO: needs validity checks (if k8s_salt is defined, etc)
{% if salt['pillar.get']('k8s_salt:roles:controlplane') %}

  {% set cluster = salt['pillar.get']('k8s_salt:cluster') %}

Scheduler private key:
  x509.private_key_managed:
  - replace: False
  - makedirs: True
  - names:
    - /etc/kubernetes/pki/scheduler-key.pem:
      - bits: 4096

place_scheduler_files:
  file.managed:
  - makedirs: True
  - names:
    - /etc/kubernetes/config/kube-scheduler-config.yaml:
      - source: salt://{{ slspath }}/templates/kube-scheduler-config.yaml
        mode: '0644'
    - /etc/kubernetes/config/scheduler.kubeconfig:
      - source: salt://{{ slspath }}/templates/scheduler.kubeconfig
        mode: '0644'

  x509.certificate_managed:
  - makedirs: True
  - names:
    - /etc/kubernetes/pki/scheduler.pem:
      - CN: system:kube-scheduler
      - O: system:kube-scheduler
      - ca_server: {{ k8s_salt['ca_server'] }}
      - public_key: /etc/kubernetes/pki/scheduler-key.pem
      - signing_policy: {{ cluster }}_kube-ca
      - keyUsage: "critical Digital Signature, Key Encipherment"
      - extendedKeyUsage: "TLS Web Server Authentication, TLS Web Client Authentication"
      - basicConstraints: "critical CA:FALSE"

place_scheduler_service:
  file.managed:
  - name: /etc/systemd/system/kube-scheduler.service
  - source: salt://{{ slspath }}/templates/kube-scheduler.service
  - mode: '0644'
  - template: 'jinja'
  module.run:
  - name: service.systemctl_reload
  - onchanges:
    - file: place_scheduler_service

run_scheduler_unit:
  service.running:
  - name: kube-scheduler
  - enable: True
  - watch:
    - module: place_scheduler_service
{% endif %}
