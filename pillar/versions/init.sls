# {% import_yaml "roles.yaml" as r %}
# 
# {% if 'worker' in r[grains['id']]['roles'] %}
# # 
# containerd:
#   version: {{ {
#     "mycluster": "1.3*"
#     }[r[grains['id']]['cluster']] | default("1.3*") }}
# 
# kubelet:
#   version: {{ {
#     "mycluster": "1.17.4"
#     }[r[grains['id']]['cluster']] | default("1.17.4") }}
# 
# proxy:
#   version: {{ {
#     "mycluster": "1.17.4"
#     }[r[grains['id']]['cluster']] | default("1.17.4") }}
# {% endif %}
# 
# {% if 'etcd' in r[grains['id']]['roles'] %}
# etcd:
#   version: {{ {
#     "mycluster": "v3.3.15"
#     }[r[grains['id']]['cluster']] | default("v3.3.15") }}
# {% endif %}
# 
# {% if 'controlplane' in r[grains['id']]['roles'] %}
# controlplane:
#   version: {{ {
#     "mycluster": "1.17.4"
#     }[r[grains['id']]['cluster']] | default("1.17.4") }}
# {% endif %}
# 
