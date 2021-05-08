
### Checks if worth trying to run state
{% if salt['pillar.get']('k8s_salt:enabled') and salt['pillar.get']('k8s_salt:cluster') %}
{% set authorities = salt['mine.get']('I@k8s_salt:roles:ca:True', 'get_authorities', 'compound') %}
{% if authorities | length == 1 %}
{% set authorities = authorities.popitem()[1] %}

{% set cluster = salt['pillar.get']('k8s_salt:cluster') %}
{% set kube_ca          = '/etc/kubernetes-authority/' + cluster +          '/kube-ca.pem' %}
{% set etcd_peer_ca     = '/etc/kubernetes-authority/' + cluster +     '/etcd-peer-ca.pem' %}
{% set etcd_trusted_ca  = '/etc/kubernetes-authority/' + cluster +  '/etcd-trusted-ca.pem' %}
{% set requestheader_ca = '/etc/kubernetes-authority/' + cluster + '/requestheader-ca.pem' %}

Place CA certificates:
  x509.pem_managed:
  - makedirs: True
  - names:
    # Just in case there are no matching roles
    - /etc/kubernetes/pki/dummy.pem:
      - text: |-
          -----BEGIN PUBLIC KEY-----
          MIIC
          -----END PUBLIC KEY-----
{% if salt['pillar.get']('k8s_salt:roles:controlplane') or salt['pillar.get']('k8s_salt:roles:worker') or salt['pillar.get']('k8s_salt:roles:admin') %}
  {% if kube_ca in authorities %}
    - /etc/kubernetes/pki/kube-ca.pem:
      - text: {{ authorities[kube_ca] | tojson }}
  {% endif %}
{% endif %}

{% if salt['pillar.get']('k8s_salt:roles:controlplane') or salt['pillar.get']('k8s_salt:roles:etcd') or salt['pillar.get']('k8s_salt:roles:admin') %}
  {% if etcd_trusted_ca in authorities %}
    - /etc/kubernetes/pki/etcd-trusted-ca.pem:
      - text: {{ authorities[etcd_trusted_ca] | tojson }}
  {% endif %}
{% endif %}

{% if salt['pillar.get']('k8s_salt:roles:controlplane') %}
  {% set sa_key = salt['mine.get']('I@k8s_salt:roles:ca:True', 'get_' + cluster + '_sa_keypair', 'compound') %}
  {% if sa_key | length == 1 %}
    {% set sa_key = sa_key.popitem()[1] %}
    {% set sa_key_path = '/etc/kubernetes-authority/' + cluster + '/sa-key.pem' %}
    {% if sa_key_path in sa_key %}
      {% set sa_key = sa_key[sa_key_path] %}
    - /etc/kubernetes/pki/sa-key.pem:
      - text: {{ sa_key | tojson }}
    - /etc/kubernetes/pki/sa.pem:
      - text: {{ salt['x509.get_public_key'](sa_key) }}
    {% endif %}
  {% endif %}
  {% if requestheader_ca in authorities %}
    - /etc/kubernetes/pki/requestheader-ca.pem:
      - text: {{ authorities[requestheader_ca] | tojson }}
  {% endif %}
{% endif %}

{% if salt['pillar.get']('k8s_salt:roles:etcd') %}
  {% if etcd_peer_ca in authorities %}
    - /etc/kubernetes/pki/etcd-peer-ca.pem:
      - text: {{ authorities[etcd_peer_ca] | tojson }}
  {% endif %}
{% endif %} #}

### End checks
{% endif %}
{% endif %}
