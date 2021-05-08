{% from './map.jinja' import k8s_salt %}

{% if k8s_salt is defined %}
{% if 'k8s_binaries' in k8s_salt %}
{% if k8s_salt['k8s_binaries'] | length > 0 %}

get_kubernetes_binaries:
  file.managed:
  - names:
{% for binary in k8s_salt['k8s_binaries'] %}
    - /usr/local/bin/{{ binary }}:
      - source: {{ k8s_salt['k8s_proxy_repo'] }}/v{{ k8s_salt['version_kubernetes'] }}/bin/linux/{{ k8s_salt['arch'] }}/{{ binary }}
      - source_hash: {{ k8s_salt['k8s_proxy_repo'] }}/v{{ k8s_salt['version_kubernetes'] }}/bin/linux/{{ k8s_salt['arch'] }}/{{ binary }}.sha256
      - user: root
      - mode: '0755'
      - makedirs: True
{% endfor %}

{% endif %}
{% endif %}
{% endif %}
