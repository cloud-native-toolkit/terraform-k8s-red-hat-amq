#!/usr/bin/env bash

NAMESPACE="$1"
NAME="$2"

if [[ -z "${NAME}" ]]; then
  NAME=amq
fi

if [[ -z "${TMP_DIR}" ]]; then
  TMP_DIR=".tmp"
fi
mkdir -p "${TMP_DIR}"

YAML_FILE=${TMP_DIR}/amq-instance-${NAME}.yaml

kubectl delete -f ${YAML_FILE} -n "${NAMESPACE}"

AMQ_RESOURCE="statefulset/${NAME}-amq"


count=0
while kubectl get ${AMQ_RESOURCE} -n "${NAMESPACE}" 1> /dev/null 2> /dev/null; do
  if [[ ${count} -eq 12 ]]; then
    echo "Timed out waiting for ${AMQ_RESOURCE} to be removed"
    exit 1
  else
    count=$((count + 1))
  fi

  echo "Waiting for ${AMQ_RESOURCE} to be removed"
  sleep 30
done


