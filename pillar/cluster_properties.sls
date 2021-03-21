{% import_yaml "roles.yaml" as r %}

cluster_properties: {{ {
  "mycluster": {
    "apiserver_vip": ["10.0.0.11"], # IP of loadbalancer to API server
    "apiserver_dns": []
  }
}[r[grains['id']]['cluster']] | default({
  "apiserver_vip": [],
  "apiserver_dns": []
  }) }}

