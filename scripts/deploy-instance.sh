#!/usr/bin/env bash

CLUSTER_TYPE="$1"
NAMESPACE="$2"
INGRESS_SUBDOMAIN="$3"
NAME="$4"
TLS_SECRET_NAME="$5"

if [[ -z "${NAME}" ]]; then
  NAME=amq
fi

if [[ -z "${TLS_SECRET_NAME}" ]]; then
  TLS_SECRET_NAME=$(echo "${INGRESS_SUBDOMAIN}" | sed -E "s/([^.]+).*/\1/g")
fi

if [[ -z "${TMP_DIR}" ]]; then
  TMP_DIR=".tmp"
fi
mkdir -p "${TMP_DIR}"

HOST="${NAME}-${NAMESPACE}.${INGRESS_SUBDOMAIN}"

if [[ "${CLUSTER_TYPE}" == "kubernetes" ]]; then
  TYPE="ingress"
else
  TYPE="route"
fi

YAML_FILE=${TMP_DIR}/amq-instance-${NAME}.yaml

cat <<EOL > ${YAML_FILE}
apiVersion: broker.amq.io/v2alpha1
kind: ActiveMQArtemis
metadata: 
  name: ${NAME}
  application: ${NAME}-app
  namespace: ${NAMESPACE}          
spec: 
  deploymentPlan: 
    image: placeholder
    size: 2
    requireLogin: false
    persistenceEnabled: false
    journalType: nio
    messageMigration: false
    jolokiaAgentEnabled: false
    managementRBACEnabled: true
EOL

kubectl apply -f ${YAML_FILE} -n "${NAMESPACE}" || exit 1

AMQ_RESOURCE="statefulset/${NAME}-amq"

count=0
until kubectl get ${AMQ_RESOURCE} -n "${NAMESPACE}" 1> /dev/null 2> /dev/null; do
  if [[ ${count} -eq 12 ]]; then
    echo "Timed out waiting for ${AMQ_RESOURCE} rollout to start"
    exit 1
  else
    count=$((count + 1))
  fi

  echo "Waiting for ${AMQ_RESOURCE} rollout to start"
  sleep 30
done


