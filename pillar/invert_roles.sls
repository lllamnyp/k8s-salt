{% import_yaml "roles.yaml" as r %}
{% set all_roles = [] %}
{% set all_clust = [] %}
{% set all_hosts = [] %}
{% for host, roles in r.items() %}
{% for role in roles['roles'] %}
{% do all_roles.append(role) %}
{% endfor %}
{% do all_clust.append(roles['cluster']) %}
{% do all_hosts.append(host) %}
{% endfor %}
{% set all_roles = all_roles|unique %}
{% set all_clust = all_clust|unique %}
by_role: 
{% for role in all_roles %}
  {{ role }}:
{% for host in all_hosts %}
{% if role in r[host]['roles'] %}
  - {{ host }}
{% endif %}
{% endfor %}
{% endfor %}
by_cluster: 
{% for clust in all_clust %}
  {{ clust }}:
{% for host in all_hosts %}
{% if clust == r[host]['cluster'] %}
  - {{ host }}
{% endif %}
{% endfor %}
{% endfor %}
