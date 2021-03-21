{% if ( 'worker' in salt['pillar.get']('roles') ) and not ( 'controlplane' in salt['pillar.get']('roles') ) %}
add_trusted_haproxy_repo:
  file.managed:
    - name: /etc/apt/sources.list.d/haproxy.list
    - user: root
    - group: root
    - mode: 644
    - contents: |
        deb [trusted=yes] http://ppa.launchpad.net/vbernat/haproxy-2.3/ubuntu bionic main

update_haproxy_repo:
  cmd.wait:
    - name: apt-get update > /dev/null || true
    - watch:
      - file: add_trusted_haproxy_repo

install_haproxy_package:
  pkg.installed:
    - name: haproxy
    - pkgs:
      - haproxy: '2.*'
    - hold: True
    - refresh: True
    - cache_valid_time: 86400 # 1 day
    - version: '2.*'
    - require:
      - file: add_trusted_haproxy_repo
      - cmd: update_haproxy_repo

place_haproxy_configuration:
  file.managed:
    - makedirs: True
    - names:
      - /etc/logrotate.d/haproxy_logrotate:
        - source: salt://files/haproxy/haproxy_logrotate
          mode: '0644'
      - /etc/rsyslog.d/40-haproxy_rsyslog.conf:
        - source: salt://files/haproxy/40-haproxy_rsyslog.conf
          mode: '0644'
      - /etc/haproxy/haproxy.cfg:
        - source: salt://files/haproxy/haproxy.cfg
          mode: '0644'
          template: 'jinja'
  x509.certificate_managed:
    - makedirs: True
    - names:
      - /etc/kubernetes/pki/health-checker.crt:
        - CN: health-checker # system:authenticated should be enough to check https://<API>/healthz
        - signing_private_key: {{ salt['pillar.get']('k8s_certs:kube-ca-key', '') | tojson }}
        - signing_cert: {{ salt['pillar.get']('k8s_certs:kube-ca', '') | tojson }}
        - managed_private_key:
            name: /etc/kubernetes/pki/health-checker.key
            bits: 2048
        - basicConstraints: "critical CA:FALSE"
        - keyUsage: "critical Digital Signature, Key Encipherment"
        - extendedKeyUsage: "TLS Web Server Authentication, TLS Web Client Authentication"
  cmd.run:
    - names:
      - 'cat /etc/kubernetes/pki/health-checker.key /etc/kubernetes/pki/health-checker.crt > /etc/kubernetes/pki/health-checker.pem':
        - onchanges:
          - x509: place_haproxy_configuration

remove_wrong_conf:
  file.absent:
    - name: /etc/rsyslog.d/49-haproxy.conf

run_haproxy_service:
  service.running:
    - name: haproxy
    - enable: True
    - reload: True
    - watch:
      - file: place_haproxy_configuration

reload_rsyslog_service:
  service.running:
    - name: rsyslog
    - enable: True
    - watch:
      - file: place_haproxy_configuration
{% endif %}
