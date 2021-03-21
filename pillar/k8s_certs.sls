{% import_yaml "roles.yaml" as r %}
{% set cluster = r[grains['id']]['cluster'] %}
{% set pki_dir = "files/kubernetes/" + cluster + "/pki/" %}

k8s_certs:
{% import_text (pki_dir + "kube-ca.pem") as f %}
  kube-ca: {{ f|tojson }}
{% import_text (pki_dir + "kube-ca-key.pem") as f %}
  kube-ca-key: {{ f|tojson }}


{% if 'controlplane' in r[grains['id']]['roles'] %}
{% import_text (pki_dir + "requestheader-ca.pem") as f %}
  requestheader-ca: {{ f|tojson }}
{% import_text (pki_dir + "requestheader-ca-key.pem") as f %}
  requestheader-ca-key: {{ f|tojson }}
{% import_text (pki_dir + "sa-key.pem") as f %}
  sa-key: {{ f|tojson }}
{% endif %}

