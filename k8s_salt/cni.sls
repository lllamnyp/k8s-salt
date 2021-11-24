{% from './map.jinja' import k8s_salt %}
{% if 'arch' in k8s_salt and salt['pillar.get']('k8s_salt:roles:worker') and salt['pillar.get']('k8s_salt:install_loopback_plugin') %}
get_cni_archive:
  file.managed:
  - name: /data/cni/cni.tar.gz
  - source: {{ k8s_salt['cni_proxy_repo'] }}/{{ k8s_salt['version_cni'] }}/cni-plugins-linux-{{ k8s_salt['arch'] }}-{{ k8s_salt['version_cni'] }}.tgz
  {% if not k8s_salt['cni_ignore_distib_checksum'] %}
  - source_hash: {{ k8s_salt['cni_proxy_repo'] }}/{{ k8s_salt['version_cni'] }}/cni-plugins-linux-{{ k8s_salt['arch'] }}-{{ k8s_salt['version_cni'] }}.tgz.sha256
  {% endif %}
  - user: root
  - mode: '0644'
  - makedirs: True

unpack_cni_archive:
  archive.extracted:
  - name: /data/cni
  - source: /data/cni/cni.tar.gz
  - require:
    - get_cni_archive

place_cni_binaries:
  file.managed:
  - mode: '0755'
  - names:
    - /opt/cni/bin/loopback:
      - source: /data/cni/loopback
  - require:
    - unpack_cni_archive
{% else %}
Do not install loopback plugin:
  test.nop
{% endif %}
