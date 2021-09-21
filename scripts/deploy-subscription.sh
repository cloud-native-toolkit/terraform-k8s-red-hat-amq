#!/usr/bin/env bash

CLUSTER_TYPE="$1"
OPERATOR_NAMESPACE="$2"
OLM_NAMESPACE="$3"

if [[ -z "${TMP_DIR}" ]]; then
  TMP_DIR=".tmp"
fi
mkdir -p "${TMP_DIR}"

if [[ "${CLUSTER_TYPE}" == "ocp4" ]]; then
  SOURCE="community-operators"
else
  SOURCE="operatorhubio-catalog"
fi

if [[ -z "${OLM_NAMESPACE}" ]]; then
  if [[ "${CLUSTER_TYPE}" == "ocp4" ]]; then
    OLM_NAMESPACE="openshift-marketplace"
  else
    OLM_NAMESPACE="olm"
  fi
fi

YAML_FILE=${TMP_DIR}/amq-subscription.yaml

cat <<EOL > ${YAML_FILE}
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: amq-broker  
spec:
  channel: 7.x
  installPlanApproval: Automatic
  name: amq-broker
  source: redhat-operators
  sourceNamespace: $OLM_NAMESPACE
EOL

set -e

echo "Installing amq operator into ${OPERATOR_NAMESPACE} namespace"
kubectl apply -f ${YAML_FILE} -n "${OPERATOR_NAMESPACE}"

set +e

sleep 2
count=0
until kubectl get crd/activemqartemises.broker.amq.io 1>/dev/null 2>/dev/null; do
  if [[ $count -eq 10 ]]; then
    echo "Timed out waiting for amq CRD to be installed"
    exit 1
  fi

  echo "Waiting for amq CRD to be installed"
  sleep 15

  count=$((count+1))
done

count=0
until kubectl get csv -n "${OPERATOR_NAMESPACE}" | grep -q strimzi-cluster-operator; do
  if [[ $count -eq 10 ]]; then
    echo "Timed out waiting for amq CSV install to be started in ${OPERATOR_NAMESPACE}"
    exit 1
  fi

  echo "Waiting for amq CSV install to be started in ${OPERATOR_NAMESPACE}"
  sleep 15
done

CSV_NAME=$(kubectl get csv -n "${OPERATOR_NAMESPACE}" -o custom-columns=name:.metadata.name | grep strimzi-cluster-operator)

count=0
until [[ $(kubectl get csv -n "${OPERATOR_NAMESPACE}" "${CSV_NAME}" -o jsonpath='{.status.phase}') == "Succeeded" ]]; do
  if [[ $count -eq 10 ]]; then
    echo "Timed out waiting for amq CSV to be successfully installed in ${OPERATOR_NAMESPACE}"
    exit 1
  fi

  echo "Waiting for amq CSV to be successfully installed in ${OPERATOR_NAMESPACE}"
  sleep 15
done

echo "AMQ CSV started successfully"
kubectl get csv -n "${OPERATOR_NAMESPACE}" "${CSV_NAME}"
