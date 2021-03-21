{% if 'controlplane' in salt['pillar.get']('roles') %}
{% set k8sV = salt['pillar.get']('controlplane:version') %}
get_scheduler_binaries:
  file.managed:
    - name: /data/k8s-controlplane/{{ k8sV }}/kube-scheduler
    - source: https://storage.googleapis.com/kubernetes-release/release/v{{ k8sV }}/bin/linux/amd64/kube-scheduler
    - skip_verify: true
    - user: root
    - mode: 644
    - makedirs: True

place_scheduler_binaries:
  file.managed:
    - mode: '0755'
    - names:
      - /usr/local/bin/kube-scheduler:
        - source: /data/k8s-controlplane/{{ k8sV }}/kube-scheduler
    - require:
      - get_scheduler_binaries

place_scheduler_files:
  file.managed:
    - makedirs: True
    - names:
      - /etc/kubernetes/pki/kube-ca.pem:
        - contents_pillar: k8s_certs:kube-ca
          mode: '0644'
      - /etc/kubernetes/config/kube-scheduler-config.yaml:
        - source: salt://files/kubernetes/config/kube-scheduler-config.yaml
          mode: '0644'
      - /etc/kubernetes/config/scheduler.kubeconfig:
        - source: salt://files/kubernetes/config/scheduler.kubeconfig
          mode: '0644'
  x509.certificate_managed:
    - makedirs: True
    - names:
      - /etc/kubernetes/pki/scheduler.pem:
        - CN: system:kube-scheduler
        - O: system:kube-scheduler
        - signing_private_key: {{ salt['pillar.get']('k8s_certs:kube-ca-key', '') | tojson }}
        - signing_cert: {{ salt['pillar.get']('k8s_certs:kube-ca', '') | tojson }}
        - managed_private_key:
            name: /etc/kubernetes/pki/scheduler-key.pem
            bits: 2048
        - keyUsage: "critical Digital Signature, Key Encipherment"
        - extendedKeyUsage: "TLS Web Server Authentication, TLS Web Client Authentication"
        - basicConstraints: "critical CA:FALSE"


place_scheduler_service:
  file.managed:
    - name: /etc/systemd/system/kube-scheduler.service
    - source: salt://files/kubernetes/systemd/kube-scheduler.service
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
