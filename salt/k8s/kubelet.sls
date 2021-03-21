{% if 'worker' in salt['pillar.get']('roles') %}

install_kubelet_package:
  pkgrepo.managed:
    - humanname: Kubernetes repo
    - name: deb https://apt.kubernetes.io kubernetes-xenial main
    - key_url:  https://apt.kubernetes.io/doc/apt-key.gpg
    - require_in:
      - pkg: kubelet
  pkg.installed:
    - name: kubelet
    - pkgs:
      - kubelet: {{ salt['pillar.get']('kubelet:version', '1.17.4-00') }}
    - hold: True
    - refresh: True
    - cache_valid_time: 86400 # 1 day
    - version: {{ salt['pillar.get']('kubelet:version', '1.17.4-00') }}

place_kubelet_files:
  file.managed:
    - makedirs: True
    - names:
      - /etc/kubernetes/pki/kube-ca.pem:
        - contents_pillar: k8s_certs:kube-ca
          mode: '0644'
      - /etc/kubernetes/config/kubelet-config.yaml:
        - source: salt://files/kubernetes/config/kubelet-config.yaml
          mode: '0644'
      - /etc/kubernetes/config/kubelet.kubeconfig:
        - source: salt://files/kubernetes/config/kubelet.kubeconfig
          mode: '0644'
          template: jinja
  x509.certificate_managed:
    - makedirs: True
    - names:
      - /etc/kubernetes/pki/kubelet.pem:
        - CN: system:node:{{salt['grains.get']('fqdn_ip4')[0]}}
        - O: system:nodes
        - signing_private_key: {{ salt['pillar.get']('k8s_certs:kube-ca-key', '') | tojson }}
        - signing_cert: {{ salt['pillar.get']('k8s_certs:kube-ca', '') | tojson }}
        - managed_private_key:
            name: /etc/kubernetes/pki/kubelet-key.pem
            bits: 2048
        - keyUsage: "critical Digital Signature, Key Encipherment"
        - extendedKeyUsage: "TLS Web Server Authentication, TLS Web Client Authentication"
        - basicConstraints: "critical CA:FALSE"
        - subjectAltName: "IP Address:{{salt['grains.get']('fqdn_ip4')[0]}}"


place_kubelet_service:
  file.managed:
    - name: /etc/systemd/system/kubelet.service
    - source: salt://files/kubernetes/systemd/kubelet.service
    - mode: 644
    - template: jinja
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
