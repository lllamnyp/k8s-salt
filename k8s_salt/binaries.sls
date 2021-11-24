{% from './map.jinja' import k8s_salt %}


get_kubernetes_binaries:

{% if k8s_salt is mapping and 'k8s_binaries' in k8s_salt and k8s_salt['k8s_binaries'] | length > 0 %}
  file.managed:
  - names:
  {% for binary in k8s_salt['k8s_binaries'] %}
    - /usr/local/bin/{{ binary }}:
      - source: {{ k8s_salt['k8s_proxy_repo'] }}/v{{ k8s_salt['version_kubernetes'] }}/bin/linux/{{ k8s_salt['arch'] }}/{{ binary }}
    {% if not k8s_salt['k8s_binaries_ignore_distib_checksum'] %}
      - source_hash: {{ k8s_salt['k8s_proxy_repo'] }}/v{{ k8s_salt['version_kubernetes'] }}/bin/linux/{{ k8s_salt['arch'] }}/{{ binary }}.sha256
    {% endif %}
      - user: root
      - mode: '0755'
      - makedirs: True
  {% endfor %}
{% else %}
  test.nop:
  - name: Nothing to download
{% endif %}
