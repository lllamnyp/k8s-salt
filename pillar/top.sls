{% import_yaml "roles.yaml" as r %}
base:
  '*':
    - invert_roles
    - mine
    - testsalt
    #     - versions
    #     - k8s_certs
    #     - cluster_properties
