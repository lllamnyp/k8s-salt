{% from './map.jinja' import k8s_salt %}

# TODO: needs validity checks (if k8s_salt is defined, etc)
{% if k8s_salt %}
{% if salt['pillar.get']('k8s_salt:roles:controlplane') %}

  {% set cluster = salt['pillar.get']('k8s_salt:cluster') %}

Scheduler private key:
  x509.private_key_managed:
  - replace: False
  - makedirs: True
  - names:
    - /etc/kubernetes/pki/scheduler-key.pem:
      - bits: 4096

place_scheduler_config:
  file.serialize:
  - makedirs: True
  - name: /etc/kubernetes/config/kube-scheduler-config.yaml
  - dataset: {{ k8s_salt['kube-scheduler']['config'] | yaml }}
  - formatter: yaml

place_scheduler_files:
  file.managed:
  - makedirs: True
  - template: 'jinja'
  - defaults:
      k8s_salt: {{ k8s_salt }}
      component: scheduler
  - names:
    - /etc/kubernetes/config/scheduler.kubeconfig:
      - source: salt://{{ slspath }}/templates/component.kubeconfig
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
  - source: salt://{{ slspath }}/templates/component.service
  - mode: '0644'
  - template: 'jinja'
  - defaults:
      k8s_salt: {{ k8s_salt }}
      component: kube-scheduler
      description: Kubernetes Scheduler
      version: {{ k8s_salt['version_kubernetes'] }}
      doc: https://github.com/kubernetes/kubernetes
      service_params: ""
  module.run:
  - name: service.systemctl_reload
  - onchanges:
    - file: place_scheduler_service
    - file: place_scheduler_config

run_scheduler_unit:
  service.running:
  - name: kube-scheduler
  - enable: True
  - watch:
    - module: place_scheduler_service
{% endif %}
{% endif %}
