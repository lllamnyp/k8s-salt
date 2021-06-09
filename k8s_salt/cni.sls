{% from './map.jinja' import k8s_salt %}
{% if 'arch' in k8s_salt %}
{% if salt['pillar.get']('k8s_salt:roles:worker') %}
get_cni_archive:
  file.managed:
  - name: /data/cni/cni.tar.gz
  - source: https://github.com/containernetworking/plugins/releases/download/v0.9.1/cni-plugins-linux-{{ k8s_salt['arch'] }}-v0.9.1.tgz
  - source_hash: https://github.com/containernetworking/plugins/releases/download/v0.9.1/cni-plugins-linux-{{ k8s_salt['arch'] }}-v0.9.1.tgz.sha256
  - user: root
  - mode: 644
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
{% endif %}
{% endif %}
