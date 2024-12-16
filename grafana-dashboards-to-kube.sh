#!/bin/bash

# This script targets a Grafana instance and downloads its dashboards
# The dashbaords are then rewritten as Kubernetes objects which can be
# understood by Grafana operator (https://grafana.github.io/grafana-operator/docs/dashboards/)

# Complete these with your values
GRAFANA_URL=
USER=
PASSWORD=
NAMESPACE=

# Template of the kube object which will be created
KUBE_TEMPLATE=$(cat <<-END
apiVersion: grafana.integreatly.org/v1beta1
kind: GrafanaDashboard
metadata:
  name: DASHBOARD_NAME
  namespace: NAMESPACE
spec:
  resyncPeriod: 30s
  instanceSelector:
    matchLabels:
      dashboards: "grafana"
  json: >
END
)

# Get UIDs for all dashboards in Grafana
for uid in $(curl -u "$USER:$PASSWORD" $GRAFANA_URL/api/search | jq -r '.[] | .uid')
do 
  # Download each JSON dashboard individually
  curl -u "$USER:$PASSWORD" "$GRAFANA_URL/api/dashboards/uid/$uid" | jq -r ".dashboard" > $uid.temp.yaml
done

for f in $(ls | grep temp.yaml)
do
  # Rendered title should be something like xxx-yyy-zzz
  title=$(jq -r '.title' "$f" | sed 's/\ /_/g' | sed 's/\//_/g' | sed 's/(/-/g' | sed 's/)//g'| tr 'A-Z_' 'a-z-' | tr -s '-')

  # Rewrite dashboard as kube object in new file
  cat << EOF > "02-$title.yaml"
$KUBE_TEMPLATE
$(awk '{ print "    " $0 }' $f)
EOF

  # Replace the dashboard name
  sed -i "s/DASHBOARD_NAME/$title/g" "02-$title.yaml"
  sed -i "s/NAMESPACE/$NAMESPACE/g" "02-$title.yaml"

  # Remove downloaded file
  rm $f
done
