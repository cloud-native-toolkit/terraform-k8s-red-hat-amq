#!/usr/bin/env bash

CLUSTER_TYPE="$1"
NAMESPACE="amq2"
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

cat <<EOL > ${TMP_DIR}/service_account.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: amq-broker-operator

EOL

kubectl apply -f ${TMP_DIR}/service_account.yaml -n "${NAMESPACE}"

echo "service_account created"

cat <<EOL > ${TMP_DIR}/role.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: amq-broker-operator
rules:
- apiGroups:
  - ""
  resources:
  - pods
  - services
  - endpoints
  - persistentvolumeclaims
  - events
  - configmaps
  - secrets
  - routes
  verbs:
  - '*'
- apiGroups:
  - ""
  resources:
  - namespaces
  verbs:
  - get
- apiGroups:
  - apps
  resources:
  - deployments
  - daemonsets
  - replicasets
  - statefulsets
  verbs:
  - '*'
- apiGroups:
  - monitoring.coreos.com
  resources:
  - servicemonitors
  verbs:
  - get
  - create
- apiGroups:
  - broker.amq.io
  resources:
  - '*'
  - activemqartemisaddresses
  - activemqartemisscaledowns
  - activemqartemis
  verbs:
  - '*'
- apiGroups:
  - route.openshift.io
  resources:
  - routes
  - routes/custom-host
  - routes/status
  verbs:
  - get
  - list
  - watch
  - create
  - delete
  - update
- apiGroups:
  - extensions
  resources:
  - ingresses
  verbs:
  - get
  - list
  - watch
  - create
  - delete
- apiGroups:
  - apps
  resources:
  - deployments/finalizers
  verbs:
  - update

EOL

kubectl apply -f ${TMP_DIR}/role.yaml -n "${NAMESPACE}"

echo "Setup RBAC"
echo "role created"



cat <<EOL > ${TMP_DIR}/role_binding.yaml
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: amq-broker-operator
subjects:
- kind: ServiceAccount
  name: amq-broker-operator
roleRef:
  kind: Role
  name: amq-broker-operator
  apiGroup: rbac.authorization.k8s.io
EOL

kubectl apply -f ${TMP_DIR}/role_binding.yaml -n "${NAMESPACE}"

echo "role_binding created"


cat <<EOL > ${TMP_DIR}/broker_activemqartemis_crd.yaml
kind: CustomResourceDefinition
apiVersion: apiextensions.k8s.io/v1beta1
metadata:
  name: activemqartemises.broker.amq.io
spec:
  group: broker.amq.io
  version: v2alpha4
  names:
    plural: activemqartemises
    singular: activemqartemis
    kind: ActiveMQArtemis
    listKind: ActiveMQArtemisList
  scope: Namespaced
  subresources:
    status: {}
    scale:
      specReplicasPath: .spec.replicas
      statusReplicasPath: .status.replicas
  versions:
    - name: v2alpha4
      served: true
      storage: true
      schema:
        openAPIV3Schema:
          required:
            - spec
          properties:
            apiVersion:
              type: string
            kind:
              type: string
            metadata:
              type: object
            spec:
              type: object
              properties:
##### core #####
                acceptors:
                  description: Configuration of all acceptors
                  type: array
                  minItems: 0
                  items:
                    description: A single acceptor configuration
                    type: object
                    properties:
                      amqpMinLargeMessageSize:
                        description: The default value is 102400 (100KBytes). Setting it to -1 will disable large message support.
                        type: integer
                      port:
                        description: Port number
                        type: integer
                      verifyHost:
                        description: >-
                          The CN of the connecting client's SSL certificate will
                          be compared to its hostname to verify they match. This
                          is useful only for 2-way SSL.
                        type: boolean
                      wantClientAuth:
                        description: >-
                          Tells a client connecting to this acceptor that 2-way
                          SSL is requested but not required. Overridden by
                          needClientAuth.
                        type: boolean
                      expose:
                        description: Whether or not to expose this acceptor
                        type: boolean
                      enabledCipherSuites:
                        description: >-
                          Comma separated list of cipher suites used for SSL
                          communication.
                        type: string
                      needClientAuth:
                        description: >-
                          Tells a client connecting to this acceptor that 2-way
                          SSL is required. This property takes precedence over
                          wantClientAuth.
                        type: boolean
                      multicastPrefix:
                        description: To indicate which kind of routing type to use.
                        type: string
                      name:
                        description: The name of the acceptor
                        type: string
                      connectionsAllowed:
                        description: >-
                          Limits the number of connections which the acceptor
                          will allow. When this limit is reached a DEBUG level
                          message is issued to the log, and the connection is
                          refused.
                        type: integer
                      sslEnabled:
                        description: Whether or not to enable SSL on this port
                        type: boolean
                      sniHost:
                        description: >-
                          A regular expression used to match the server_name
                          extension on incoming SSL connections. If the name
                          doesn't match then the connection to the acceptor will
                          be rejected.
                        type: string
                      enabledProtocols:
                        description: >-
                          Comma separated list of protocols used for SSL
                          communication.
                        type: string
                      protocols:
                        description: The protocols to enable for this acceptor
                        type: string
                      sslSecret:
                        description: Name of the secret to use for ssl information
                        type: string
                      sslProvider:
                        description: >-
                          Used to change the SSL Provider between JDK and
                          OPENSSL. The default is JDK.
                        type: string
                      anycastPrefix:
                        description: To indicate which kind of routing type to use.
                        type: string
                adminPassword:
                  description: >-
                    Password for standard broker user. It is required for
                    connecting to the broker. If left empty, it will be
                    generated.
                  type: string
                adminUser:
                  description: >-
                    User name for standard broker user. It is required for
                    connecting to the broker. If left empty, it will be
                    generated.
                  type: string
                connectors:
                  description: Configuration of all connectors
                  type: array
                  minItems: 0
                  items:
                    description: A single connector configuration
                    type: object
                    properties:
                      port:
                        description: Port number
                        type: integer
                      verifyHost:
                        description: >-
                          The CN of the connecting client's SSL certificate will
                          be compared to its hostname to verify they match. This
                          is useful only for 2-way SSL.
                        type: boolean
                      wantClientAuth:
                        description: >-
                          Tells a client connecting to this acceptor that 2-way
                          SSL is requested but not required. Overridden by
                          needClientAuth.
                        type: boolean
                      expose:
                        description: Whether or not to expose this connector
                        type: boolean
                      enabledCipherSuites:
                        description: >-
                          Comma separated list of cipher suites used for SSL
                          communication.
                        type: string
                      host:
                        description: Hostname or IP to connect to
                        type: string
                      needClientAuth:
                        description: >-
                          Tells a client connecting to this acceptor that 2-way
                          SSL is required. This property takes precedence over
                          wantClientAuth.
                        type: boolean
                      name:
                        description: The name of the acceptor
                        type: string
                      sslEnabled:
                        description: Whether or not to enable SSL on this port
                        type: boolean
                      sniHost:
                        description: >-
                          A regular expression used to match the server_name
                          extension on incoming SSL connections. If the name
                          doesn't match then the connection to the acceptor will
                          be rejected.
                        type: string
                      enabledProtocols:
                        description: >-
                          Comma separated list of protocols used for SSL
                          communication.
                        type: string
                      type:
                        description: The type either tcp or vm
                        type: string
                      sslSecret:
                        description: Name of the secret to use for ssl information
                        type: string
                      sslProvider:
                        description: >-
                          Used to change the SSL Provider between JDK and
                          OPENSSL. The default is JDK.
                        type: string
################
                addressSettings:
                  #id: "urn:jsonschema:activemq:core:ConfigurationType:AddressSettings"
                  description: a list of address settings
                  type: object
                  properties:
                    applyRule:
                      description: >-
                        a flag APPLY_RULE that indicates on what parts of address
                        settings in broker.xml to perform the merge. It has 3 possible values:
                        =replace_all
                        The merge performs merge on the address-settings as a whole part.
                        =merge_replace
                        The merge performs merge on each address-setting element
                        =merge_all
                        The merge performs merge on each property of every address-setting
                        This is the default value
                      type: string
                    addressSetting:
                      description: address setting configuration
                      type: array
                      items:
                        #id: "urn:jsonschema:activemq:core:AddressSetting"
                        type: object
                        properties:
                          deadLetterAddress:
                            description: the address to send dead messages to
                            type: string
                          autoCreateDeadLetterResources:
                            description: >-
                              whether or not to automatically create the dead-letter-address and/or a corresponding queue
                              on that address when a message found to be undeliverable
                            type: boolean
                          deadLetterQueuePrefix:
                            description: the prefix to use for auto-created dead letter queues
                            type: string
                          deadLetterQueueSuffix:
                            description: the suffix to use for auto-created dead letter queues
                            type: string
                          expiryAddress:
                            description: the address to send expired messages to
                            type: string
                          autoCreateExpiryResources:
                            description: >-
                              whether or not to automatically create the expiry-address and/or a corresponding queue
                              on that address when a message is sent to a matching queue
                            type: boolean
                          expiryQueuePrefix:
                            description: the prefix to use for auto-created expiry queues
                            type: string
                          expiryQueueSuffix:
                            description: the suffix to use for auto-created expiry queues
                            type: string
                          expiryDelay:
                            description: >-
                              Overrides the expiration time for messages using the default value for expiration time. "-1"
                              disables this setting.
                            type: integer
                          minExpiryDelay:
                            description: Overrides the expiration time for messages using a lower value. "-1" disables this setting.
                            type: integer
                          maxExpiryDelay:
                            description: Overrides the expiration time for messages using a higher value. "-1" disables this setting.
                            type: integer
                          redeliveryDelay:
                            description: the time (in ms) to wait before redelivering a cancelled message.
                            type: integer
                          redeliveryDelayMultiplier:
                            description: multiplier to apply to the redelivery-delay
                            type: number
                          redeliveryCollisionAvoidanceFactor:
                            description: factor by which to modify the redelivery delay slightly to avoid collisions
                            type: number
                          maxRedeliveryDelay:
                            description: Maximum value for the redelivery-delay
                            type: integer
                          maxDeliveryAttempts:
                            description: how many times to attempt to deliver a message before sending to dead letter address
                            type: integer
                          maxSizeBytes:
                            description: >-
                              the maximum size in bytes for an address. -1 means no limits. This is used in PAGING, BLOCK and
                              FAIL policies. Supports byte notation like K, Mb, GB, etc.
                            type: string
                          maxSizeBytesRejectThreshold:
                            description: >-
                              used with the address full BLOCK policy, the maximum size in bytes an address can reach before
                              messages start getting rejected. Works in combination with max-size-bytes for AMQP protocol only.
                              Default = -1 (no limit).
                            type: integer
                          pageSizeBytes:
                            description: >-
                              The page size in bytes to use for an address. Supports byte notation like K, Mb,
                              GB, etc.
                            type: string
                          pageMaxCacheSize:
                            description: Number of paging files to cache in memory to avoid IO during paging navigation
                            type: integer
                          addressFullPolicy:
                            description: what happens when an address where maxSizeBytes is specified becomes full
                            type: string
                            enum:
                            - "DROP"
                            - "FAIL"
                            - "PAGE"
                            - "BLOCK"
                          messageCounterHistoryDayLimit:
                            description: how many days to keep message counter history for this address
                            type: integer
                          lastValueQueue:
                            description: This is deprecated please use default-last-value-queue instead.
                            type: boolean
                          defaultLastValueQueue:
                            description: whether to treat the queues under the address as a last value queues by default
                            type: boolean
                          defaultLastValueKey:
                            description: the property to use as the key for a last value queue by default
                            type: string
                          defaultNonDestructive:
                            description: whether the queue should be non-destructive by default
                            type: boolean
                          defaultExclusiveQueue:
                            description: whether to treat the queues under the address as exclusive queues by default
                            type: boolean
                          defaultGroupRebalance:
                            description: whether to rebalance groups when a consumer is added
                            type: boolean
                          defaultGroupRebalancePauseDispatch:
                            description: whether to pause dispatch when rebalancing groups
                            type: boolean
                          defaultGroupBuckets:
                            description: number of buckets to use for grouping, -1 (default) is unlimited and uses the raw group, 0 disables message groups.
                            type: integer
                          defaultGroupFirstKey:
                            description: key used to mark a message is first in a group for a consumer
                            type: string
                          defaultConsumersBeforeDispatch:
                            description: the default number of consumers needed before dispatch can start for queues under the address.
                            type: integer
                          defaultDelayBeforeDispatch:
                            description: >-
                              the default delay (in milliseconds) to wait before dispatching if number of consumers before
                              dispatch is not met for queues under the address.
                            type: integer
                          redistributionDelay:
                            description: >-
                              how long (in ms) to wait after the last consumer is closed on a queue before redistributing
                              messages.
                            type: integer
                          sendToDlaOnNoRoute:
                            description: >-
                              if there are no queues matching this address, whether to forward message to DLA (if it exists for
                              this address)
                            type: boolean
                          slowConsumerThreshold:
                            description: >-
                              The minimum rate of message consumption allowed before a consumer is considered "slow." Measured
                              in messages-per-second.
                            type: integer
                          slowConsumerPolicy:
                            description: what happens when a slow consumer is identified
                            type: string
                            enum:
                            - "KILL"
                            - "NOTIFY"
                          slowConsumerCheckPeriod:
                            description: How often to check for slow consumers on a particular queue. Measured in seconds.
                            type: integer
                          autoCreateJmsQueues:
                            description: >-
                              DEPRECATED. whether or not to automatically create JMS queues when a producer sends or a consumer connects to a
                              queue
                            type: boolean
                          autoDeleteJmsQueues:
                            description: DEPRECATED. whether or not to delete auto-created JMS queues when the queue has 0 consumers and 0 messages
                            type: boolean
                          autoCreateJmsTopics:
                            description: >-
                              DEPRECATED. whether or not to automatically create JMS topics when a producer sends or a consumer subscribes to
                              a topic
                            type: boolean
                          autoDeleteJmsTopics:
                            description: DEPRECATED. whether or not to delete auto-created JMS topics when the last subscription is closed
                            type: boolean
                          autoCreateQueues:
                            description: >-
                              whether or not to automatically create a queue when a client sends a message to or attempts to consume
                              a message from a queue
                            type: boolean
                          autoDeleteQueues:
                            description: whether or not to delete auto-created queues when the queue has 0 consumers and 0 messages
                            type: boolean
                          autoDeleteCreatedQueues:
                            description: whether or not to delete created queues when the queue has 0 consumers and 0 messages
                            type: boolean
                          autoDeleteQueuesDelay:
                            description: >-
                              how long to wait (in milliseconds) before deleting auto-created queues after the queue has 0
                              consumers.
                            type: integer
                          autoDeleteQueuesMessageCount:
                            description: >-
                              the message count the queue must be at or below before it can be evaluated 
                              to be auto deleted, 0 waits until empty queue (default) and -1 disables this check.
                            type: integer
                          configDeleteQueues:
                            description: >-
                              What to do when a queue is no longer in broker.xml.
                              OFF = will do nothing queues will remain,
                              FORCE = delete queues even if messages remaining.
                            type: string
                            enum:
                            - "OFF"
                            - "FORCE"
                          autoCreateAddresses:
                            description: >-
                              whether or not to automatically create addresses when a client sends a message to or attempts to
                              consume a message from a queue mapped to an address that doesnt exist
                            type: boolean
                          autoDeleteAddresses:
                            description: whether or not to delete auto-created addresses when it no longer has any queues
                            type: boolean
                          autoDeleteAddressesDelay:
                            description: >-
                              how long to wait (in milliseconds) before deleting auto-created addresses after they no longer
                              have any queues
                            type: integer
                          configDeleteAddresses:
                            description: >-
                              What to do when an address is no longer in broker.xml.
                              OFF = will do nothing addresses will remain,
                              FORCE = delete address and its queues even if messages remaining.
                            type: string
                            enum:
                            - "OFF"
                            - "FORCE"
                          managementBrowsePageSize:
                            description: how many message a management resource can browse
                            type: integer
                          defaultPurgeOnNoConsumers:
                            description: purge the contents of the queue once there are no consumers
                            type: boolean
                          defaultMaxConsumers:
                            description: the maximum number of consumers allowed on this queue at any one time
                            type: integer
                          defaultQueueRoutingType:
                            description: the routing-type used on auto-created queues
                            type: string
                            enum:
                            - "ANYCAST"
                            - "MULTICAST"
                          defaultAddressRoutingType:
                            description: the routing-type used on auto-created addresses
                            type: string
                            enum:
                            - "ANYCAST"
                            - "MULTICAST"
                          defaultConsumerWindowSize:
                            description: the default window size for a consumer
                            type: integer
                          defaultRingSize:
                            description: >-
                              the default ring-size value for any matching queue which doesnt have ring-size explicitly
                              defined
                            type: integer
                          retroactiveMessageCount:
                            description: the number of messages to preserve for future queues created on the matching address
                            type: integer
                          enableMetrics:
                            description: whether or not to enable metrics for metrics plugins on the matching address
                            type: boolean
                          match:
                            description: pattern for matching settings against addresses; can use wildards
                            type: string
################
                console:
                  description: Configuration for the embedded web console
                  type: object
                  properties:
                    expose:
                      description: Whether or not to expose this port
                      type: boolean
                    sslEnabled:
                      description: Whether or not to enable SSL on this port
                      type: boolean
                    sslSecret:
                      description: Name of the secret to use for ssl information
                      type: string
                    useClientAuth:
                      description: If the embedded server requires client authentication
                      type: boolean
                deploymentPlan:
                  type: object
                  properties:
                    jolokiaAgentEnabled:
                      description: If true enable the Jolokia JVM Agent
                      type: boolean
                    image:
                      description: The image used for the broker deployment
                      type: string
                    initImage:
                      description: The init container image used to configure broker
                      type: string
                    journalType:
                      description: 'If aio use ASYNCIO, if nio use NIO for journal IO'
                      type: string
                    managementRBACEnabled:
                      description: If true enable the management role based access control
                      type: boolean
                    messageMigration:
                      description: If true migrate messages on scaledown
                      type: boolean
                    persistenceEnabled:
                      description: >-
                        If true use persistent volume via persistent volume
                        claim for journal storage
                      type: boolean
                    requireLogin:
                      description: >-
                        If true require user password login credentials for
                        broker protocol ports
                      type: boolean
                    size:
                      description: The number of broker pods to deploy
                      type: integer
                      maximum: 16
                      minimum: 0
                    storage:
                      description: the storage capacity
                      type: object
                      properties:
                        size:
                          type: string
                    resources:
                      type: object
                      properties:
                        requests:
                          type: object
                          properties:
                            cpu:
                              type: string
                            memory:
                              type: string
                        limits:
                          type: object
                          properties:
                            cpu:
                              type: string
                            memory:
                              type: string
                upgrades:
                  description: >-
                    Specify the level of upgrade that should be allowed when an
                    older product version is detected
                  type: object
                  properties:
                    enabled:
                      description: >-
                        Set true to enable automatic micro version product
                        upgrades, it is disabled by default.
                      type: boolean
                    minor:
                      description: >-
                        Set true to enable automatic minor product version
                        upgrades, it is disabled by default. Requires
                        spec.upgrades.enabled to be true.
                      type: boolean
                version:
                  description: The version of the application deployment.
                  type: string
            status:
              type: object
              required:
                - podStatus
              properties:
                podStatus:
                  type: object
                  properties:
                    ready:
                      type: array
                      items:
                        type: string
                    starting:
                      type: array
                      items:
                        type: string
                    stopped:
                      type: array
                      items:
                        type: string
    - name: v2alpha3
      served: true
      storage: false
      schema:
        openAPIV3Schema:
          required:
            - spec
          properties:
            apiVersion:
              type: string
            kind:
              type: string
            metadata:
              type: object
            spec:
              type: object
              properties:
##### core #####
                acceptors:
                  description: Configuration of all acceptors
                  type: array
                  minItems: 0
                  items:
                    description: A single acceptor configuration
                    type: object
                    properties:
                      amqpMinLargeMessageSize:
                        description: The default value is 102400 (100KBytes). Setting it to -1 will disable large message support.
                        type: integer
                      port:
                        description: Port number
                        type: integer
                      verifyHost:
                        description: >-
                          The CN of the connecting client's SSL certificate will
                          be compared to its hostname to verify they match. This
                          is useful only for 2-way SSL.
                        type: boolean
                      wantClientAuth:
                        description: >-
                          Tells a client connecting to this acceptor that 2-way
                          SSL is requested but not required. Overridden by
                          needClientAuth.
                        type: boolean
                      expose:
                        description: Whether or not to expose this acceptor
                        type: boolean
                      enabledCipherSuites:
                        description: >-
                          Comma separated list of cipher suites used for SSL
                          communication.
                        type: string
                      needClientAuth:
                        description: >-
                          Tells a client connecting to this acceptor that 2-way
                          SSL is required. This property takes precedence over
                          wantClientAuth.
                        type: boolean
                      multicastPrefix:
                        description: To indicate which kind of routing type to use.
                        type: string
                      name:
                        description: The name of the acceptor
                        type: string
                      connectionsAllowed:
                        description: >-
                          Limits the number of connections which the acceptor
                          will allow. When this limit is reached a DEBUG level
                          message is issued to the log, and the connection is
                          refused.
                        type: integer
                      sslEnabled:
                        description: Whether or not to enable SSL on this port
                        type: boolean
                      sniHost:
                        description: >-
                          A regular expression used to match the server_name
                          extension on incoming SSL connections. If the name
                          doesn't match then the connection to the acceptor will
                          be rejected.
                        type: string
                      enabledProtocols:
                        description: >-
                          Comma separated list of protocols used for SSL
                          communication.
                        type: string
                      protocols:
                        description: The protocols to enable for this acceptor
                        type: string
                      sslSecret:
                        description: Name of the secret to use for ssl information
                        type: string
                      sslProvider:
                        description: >-
                          Used to change the SSL Provider between JDK and
                          OPENSSL. The default is JDK.
                        type: string
                      anycastPrefix:
                        description: To indicate which kind of routing type to use.
                        type: string
                adminPassword:
                  description: >-
                    Password for standard broker user. It is required for
                    connecting to the broker. If left empty, it will be
                    generated.
                  type: string
                adminUser:
                  description: >-
                    User name for standard broker user. It is required for
                    connecting to the broker. If left empty, it will be
                    generated.
                  type: string
                connectors:
                  description: Configuration of all connectors
                  type: array
                  minItems: 0
                  items:
                    description: A single connector configuration
                    type: object
                    properties:
                      port:
                        description: Port number
                        type: integer
                      verifyHost:
                        description: >-
                          The CN of the connecting client's SSL certificate will
                          be compared to its hostname to verify they match. This
                          is useful only for 2-way SSL.
                        type: boolean
                      wantClientAuth:
                        description: >-
                          Tells a client connecting to this acceptor that 2-way
                          SSL is requested but not required. Overridden by
                          needClientAuth.
                        type: boolean
                      expose:
                        description: Whether or not to expose this connector
                        type: boolean
                      enabledCipherSuites:
                        description: >-
                          Comma separated list of cipher suites used for SSL
                          communication.
                        type: string
                      host:
                        description: Hostname or IP to connect to
                        type: string
                      needClientAuth:
                        description: >-
                          Tells a client connecting to this acceptor that 2-way
                          SSL is required. This property takes precedence over
                          wantClientAuth.
                        type: boolean
                      name:
                        description: The name of the acceptor
                        type: string
                      sslEnabled:
                        description: Whether or not to enable SSL on this port
                        type: boolean
                      sniHost:
                        description: >-
                          A regular expression used to match the server_name
                          extension on incoming SSL connections. If the name
                          doesn't match then the connection to the acceptor will
                          be rejected.
                        type: string
                      enabledProtocols:
                        description: >-
                          Comma separated list of protocols used for SSL
                          communication.
                        type: string
                      type:
                        description: The type either tcp or vm
                        type: string
                      sslSecret:
                        description: Name of the secret to use for ssl information
                        type: string
                      sslProvider:
                        description: >-
                          Used to change the SSL Provider between JDK and
                          OPENSSL. The default is JDK.
                        type: string
################
                addressSettings:
                  #id: "urn:jsonschema:activemq:core:ConfigurationType:AddressSettings"
                  description: a list of address settings
                  type: object
                  properties:
                    applyRule:
                      description: >-
                        a flag APPLY_RULE that indicates on what parts of address
                        settings in broker.xml to perform the merge. It has 3 possible values:
                        =replace_all
                        The merge performs merge on the address-settings as a whole part.
                        =merge_replace
                        The merge performs merge on each address-setting element
                        =merge_all
                        The merge performs merge on each property of every address-setting
                        This is the default value
                      type: string
                    addressSetting:
                      description: address setting configuration
                      type: array
                      items:
                        #id: "urn:jsonschema:activemq:core:AddressSetting"
                        type: object
                        properties:
                          deadLetterAddress:
                            description: the address to send dead messages to
                            type: string
                          autoCreateDeadLetterResources:
                            description: >-
                              whether or not to automatically create the dead-letter-address and/or a corresponding queue
                              on that address when a message found to be undeliverable
                            type: boolean
                          deadLetterQueuePrefix:
                            description: the prefix to use for auto-created dead letter queues
                            type: string
                          deadLetterQueueSuffix:
                            description: the suffix to use for auto-created dead letter queues
                            type: string
                          expiryAddress:
                            description: the address to send expired messages to
                            type: string
                          autoCreateExpiryResources:
                            description: >-
                              whether or not to automatically create the expiry-address and/or a corresponding queue
                              on that address when a message is sent to a matching queue
                            type: boolean
                          expiryQueuePrefix:
                            description: the prefix to use for auto-created expiry queues
                            type: string
                          expiryQueueSuffix:
                            description: the suffix to use for auto-created expiry queues
                            type: string
                          expiryDelay:
                            description: >-
                              Overrides the expiration time for messages using the default value for expiration time. "-1"
                              disables this setting.
                            type: integer
                          minExpiryDelay:
                            description: Overrides the expiration time for messages using a lower value. "-1" disables this setting.
                            type: integer
                          maxExpiryDelay:
                            description: Overrides the expiration time for messages using a higher value. "-1" disables this setting.
                            type: integer
                          redeliveryDelay:
                            description: the time (in ms) to wait before redelivering a cancelled message.
                            type: integer
                          redeliveryDelayMultiplier:
                            description: multiplier to apply to the redelivery-delay
                            type: number
                          redeliveryCollisionAvoidanceFactor:
                            description: factor by which to modify the redelivery delay slightly to avoid collisions
                            type: number
                          maxRedeliveryDelay:
                            description: Maximum value for the redelivery-delay
                            type: integer
                          maxDeliveryAttempts:
                            description: how many times to attempt to deliver a message before sending to dead letter address
                            type: integer
                          maxSizeBytes:
                            description: >-
                              the maximum size in bytes for an address. -1 means no limits. This is used in PAGING, BLOCK and
                              FAIL policies. Supports byte notation like K, Mb, GB, etc.
                            type: string
                          maxSizeBytesRejectThreshold:
                            description: >-
                              used with the address full BLOCK policy, the maximum size in bytes an address can reach before
                              messages start getting rejected. Works in combination with max-size-bytes for AMQP protocol only.
                              Default = -1 (no limit).
                            type: integer
                          pageSizeBytes:
                            description: >-
                              The page size in bytes to use for an address. Supports byte notation like K, Mb,
                              GB, etc.
                            type: integer
                          pageMaxCacheSize:
                            description: Number of paging files to cache in memory to avoid IO during paging navigation
                            type: integer
                          addressFullPolicy:
                            description: what happens when an address where maxSizeBytes is specified becomes full
                            type: string
                            enum:
                            - "DROP"
                            - "FAIL"
                            - "PAGE"
                            - "BLOCK"
                          messageCounterHistoryDayLimit:
                            description: how many days to keep message counter history for this address
                            type: integer
                          lastValueQueue:
                            description: This is deprecated please use default-last-value-queue instead.
                            type: boolean
                          defaultLastValueQueue:
                            description: whether to treat the queues under the address as a last value queues by default
                            type: boolean
                          defaultLastValueKey:
                            description: the property to use as the key for a last value queue by default
                            type: string
                          defaultNonDestructive:
                            description: whether the queue should be non-destructive by default
                            type: boolean
                          defaultExclusiveQueue:
                            description: whether to treat the queues under the address as exclusive queues by default
                            type: boolean
                          defaultGroupRebalance:
                            description: whether to rebalance groups when a consumer is added
                            type: boolean
                          defaultGroupRebalancePauseDispatch:
                            description: whether to pause dispatch when rebalancing groups
                            type: boolean
                          defaultGroupBuckets:
                            description: number of buckets to use for grouping, -1 (default) is unlimited and uses the raw group, 0 disables message groups.
                            type: integer
                          defaultGroupFirstKey:
                            description: key used to mark a message is first in a group for a consumer
                            type: string
                          defaultConsumersBeforeDispatch:
                            description: the default number of consumers needed before dispatch can start for queues under the address.
                            type: integer
                          defaultDelayBeforeDispatch:
                            description: >-
                              the default delay (in milliseconds) to wait before dispatching if number of consumers before
                              dispatch is not met for queues under the address.
                            type: integer
                          redistributionDelay:
                            description: >-
                              how long (in ms) to wait after the last consumer is closed on a queue before redistributing
                              messages.
                            type: integer
                          sendToDlaOnNoRoute:
                            description: >-
                              if there are no queues matching this address, whether to forward message to DLA (if it exists for
                              this address)
                            type: boolean
                          slowConsumerThreshold:
                            description: >-
                              The minimum rate of message consumption allowed before a consumer is considered "slow." Measured
                              in messages-per-second.
                            type: integer
                          slowConsumerPolicy:
                            description: what happens when a slow consumer is identified
                            type: string
                            enum:
                            - "KILL"
                            - "NOTIFY"
                          slowConsumerCheckPeriod:
                            description: How often to check for slow consumers on a particular queue. Measured in seconds.
                            type: integer
                          autoCreateJmsQueues:
                            description: >-
                              DEPRECATED. whether or not to automatically create JMS queues when a producer sends or a consumer connects to a
                              queue
                            type: boolean
                          autoDeleteJmsQueues:
                            description: DEPRECATED. whether or not to delete auto-created JMS queues when the queue has 0 consumers and 0 messages
                            type: boolean
                          autoCreateJmsTopics:
                            description: >-
                              DEPRECATED. whether or not to automatically create JMS topics when a producer sends or a consumer subscribes to
                              a topic
                            type: boolean
                          autoDeleteJmsTopics:
                            description: DEPRECATED. whether or not to delete auto-created JMS topics when the last subscription is closed
                            type: boolean
                          autoCreateQueues:
                            description: >-
                              whether or not to automatically create a queue when a client sends a message to or attempts to consume
                              a message from a queue
                            type: boolean
                          autoDeleteQueues:
                            description: whether or not to delete auto-created queues when the queue has 0 consumers and 0 messages
                            type: boolean
                          autoDeleteCreatedQueues:
                            description: whether or not to delete created queues when the queue has 0 consumers and 0 messages
                            type: boolean
                          autoDeleteQueuesDelay:
                            description: >-
                              how long to wait (in milliseconds) before deleting auto-created queues after the queue has 0
                              consumers.
                            type: integer
                          autoDeleteQueuesMessageCount:
                            description: >-
                              the message count the queue must be at or below before it can be evaluated 
                              to be auto deleted, 0 waits until empty queue (default) and -1 disables this check.
                            type: integer
                          configDeleteQueues:
                            description: >-
                              What to do when a queue is no longer in broker.xml.
                              OFF = will do nothing queues will remain,
                              FORCE = delete queues even if messages remaining.
                            type: string
                            enum:
                            - "OFF"
                            - "FORCE"
                          autoCreateAddresses:
                            description: >-
                              whether or not to automatically create addresses when a client sends a message to or attempts to
                              consume a message from a queue mapped to an address that doesnt exist
                            type: boolean
                          autoDeleteAddresses:
                            description: whether or not to delete auto-created addresses when it no longer has any queues
                            type: boolean
                          autoDeleteAddressesDelay:
                            description: >-
                              how long to wait (in milliseconds) before deleting auto-created addresses after they no longer
                              have any queues
                            type: integer
                          configDeleteAddresses:
                            description: >-
                              What to do when an address is no longer in broker.xml.
                              OFF = will do nothing addresses will remain,
                              FORCE = delete address and its queues even if messages remaining.
                            type: string
                            enum:
                            - "OFF"
                            - "FORCE"
                          managementBrowsePageSize:
                            description: how many message a management resource can browse
                            type: integer
                          defaultPurgeOnNoConsumers:
                            description: purge the contents of the queue once there are no consumers
                            type: boolean
                          defaultMaxConsumers:
                            description: the maximum number of consumers allowed on this queue at any one time
                            type: integer
                          defaultQueueRoutingType:
                            description: the routing-type used on auto-created queues
                            type: string
                            enum:
                            - "ANYCAST"
                            - "MULTICAST"
                          defaultAddressRoutingType:
                            description: the routing-type used on auto-created addresses
                            type: string
                            enum:
                            - "ANYCAST"
                            - "MULTICAST"
                          defaultConsumerWindowSize:
                            description: the default window size for a consumer
                            type: integer
                          defaultRingSize:
                            description: >-
                              the default ring-size value for any matching queue which doesnt have ring-size explicitly
                              defined
                            type: integer
                          retroactiveMessageCount:
                            description: the number of messages to preserve for future queues created on the matching address
                            type: integer
                          enableMetrics:
                            description: whether or not to enable metrics for metrics plugins on the matching address
                            type: boolean
                          match:
                            description: pattern for matching settings against addresses; can use wildards
                            type: string
################
                console:
                  description: Configuration for the embedded web console
                  type: object
                  properties:
                    expose:
                      description: Whether or not to expose this port
                      type: boolean
                    sslEnabled:
                      description: Whether or not to enable SSL on this port
                      type: boolean
                    sslSecret:
                      description: Name of the secret to use for ssl information
                      type: string
                    useClientAuth:
                      description: If the embedded server requires client authentication
                      type: boolean
                deploymentPlan:
                  type: object
                  properties:
                    image:
                      description: The image used for the broker deployment
                      type: string
                    journalType:
                      description: 'If aio use ASYNCIO, if nio use NIO for journal IO'
                      type: string
                    messageMigration:
                      description: If true migrate messages on scaledown
                      type: boolean
                    persistenceEnabled:
                      description: >-
                        If true use persistent volume via persistent volume
                        claim for journal storage
                      type: boolean
                    requireLogin:
                      description: >-
                        If true require user password login credentials for
                        broker protocol ports
                      type: boolean
                    size:
                      description: The number of broker pods to deploy
                      type: integer
                      maximum: 16
                      minimum: 0
                    storage:
                      description: the storage capacity
                      type: object
                      properties:
                        size:
                          type: string
                    resources:
                      type: object
                      properties:
                        requests:
                          type: object
                          properties:
                            cpu:
                              type: string
                            memory:
                              type: string
                        limits:
                          type: object
                          properties:
                            cpu:
                              type: string
                            memory:
                              type: string
                upgrades:
                  description: >-
                    Specify the level of upgrade that should be allowed when an
                    older product version is detected
                  type: object
                  properties:
                    enabled:
                      description: >-
                        Set true to enable automatic micro version product
                        upgrades, it is disabled by default.
                      type: boolean
                    minor:
                      description: >-
                        Set true to enable automatic minor product version
                        upgrades, it is disabled by default. Requires
                        spec.upgrades.enabled to be true.
                      type: boolean
                version:
                  description: The version of the application deployment.
                  type: string
            status:
              type: object
              required:
                - podStatus
              properties:
                podStatus:
                  type: object
                  properties:
                    ready:
                      type: array
                      items:
                        type: string
                    starting:
                      type: array
                      items:
                        type: string
                    stopped:
                      type: array
                      items:
                        type: string
    - name: v2alpha2
      served: true
      storage: false
      schema:
        openAPIV3Schema:
          required:
            - spec
          properties:
            apiVersion:
              type: string
            kind:
              type: string
            metadata:
              type: object
            spec:
              type: object
              properties:
                acceptors:
                  description: Configuration of all acceptors
                  type: array
                  minItems: 0
                  items:
                    description: A single acceptor configuration
                    type: object
                    properties:
                      port:
                        description: Port number
                        type: integer
                      verifyHost:
                        description: >-
                          The CN of the connecting client's SSL certificate will
                          be compared to its hostname to verify they match. This
                          is useful only for 2-way SSL.
                        type: boolean
                      wantClientAuth:
                        description: >-
                          Tells a client connecting to this acceptor that 2-way
                          SSL is requested but not required. Overridden by
                          needClientAuth.
                        type: boolean
                      expose:
                        description: Whether or not to expose this acceptor
                        type: boolean
                      enabledCipherSuites:
                        description: >-
                          Comma separated list of cipher suites used for SSL
                          communication.
                        type: string
                      needClientAuth:
                        description: >-
                          Tells a client connecting to this acceptor that 2-way
                          SSL is required. This property takes precedence over
                          wantClientAuth.
                        type: boolean
                      multicastPrefix:
                        description: To indicate which kind of routing type to use.
                        type: string
                      name:
                        description: The name of the acceptor
                        type: string
                      connectionsAllowed:
                        description: >-
                          Limits the number of connections which the acceptor
                          will allow. When this limit is reached a DEBUG level
                          message is issued to the log, and the connection is
                          refused.
                        type: integer
                      sslEnabled:
                        description: Whether or not to enable SSL on this port
                        type: boolean
                      sniHost:
                        description: >-
                          A regular expression used to match the server_name
                          extension on incoming SSL connections. If the name
                          doesn't match then the connection to the acceptor will
                          be rejected.
                        type: string
                      enabledProtocols:
                        description: >-
                          Comma separated list of protocols used for SSL
                          communication.
                        type: string
                      protocols:
                        description: The protocols to enable for this acceptor
                        type: string
                      sslSecret:
                        description: Name of the secret to use for ssl information
                        type: string
                      sslProvider:
                        description: >-
                          Used to change the SSL Provider between JDK and
                          OPENSSL. The default is JDK.
                        type: string
                      anycastPrefix:
                        description: To indicate which kind of routing type to use.
                        type: string
                adminPassword:
                  description: >-
                    Password for standard broker user. It is required for
                    connecting to the broker. If left empty, it will be
                    generated.
                  type: string
                adminUser:
                  description: >-
                    User name for standard broker user. It is required for
                    connecting to the broker. If left empty, it will be
                    generated.
                  type: string
                connectors:
                  description: Configuration of all connectors
                  type: array
                  minItems: 0
                  items:
                    description: A single connector configuration
                    type: object
                    properties:
                      port:
                        description: Port number
                        type: integer
                      verifyHost:
                        description: >-
                          The CN of the connecting client's SSL certificate will
                          be compared to its hostname to verify they match. This
                          is useful only for 2-way SSL.
                        type: boolean
                      wantClientAuth:
                        description: >-
                          Tells a client connecting to this acceptor that 2-way
                          SSL is requested but not required. Overridden by
                          needClientAuth.
                        type: boolean
                      expose:
                        description: Whether or not to expose this connector
                        type: boolean
                      enabledCipherSuites:
                        description: >-
                          Comma separated list of cipher suites used for SSL
                          communication.
                        type: string
                      host:
                        description: Hostname or IP to connect to
                        type: string
                      needClientAuth:
                        description: >-
                          Tells a client connecting to this acceptor that 2-way
                          SSL is required. This property takes precedence over
                          wantClientAuth.
                        type: boolean
                      name:
                        description: The name of the acceptor
                        type: string
                      sslEnabled:
                        description: Whether or not to enable SSL on this port
                        type: boolean
                      sniHost:
                        description: >-
                          A regular expression used to match the server_name
                          extension on incoming SSL connections. If the name
                          doesn't match then the connection to the acceptor will
                          be rejected.
                        type: string
                      enabledProtocols:
                        description: >-
                          Comma separated list of protocols used for SSL
                          communication.
                        type: string
                      type:
                        description: The type either tcp or vm
                        type: string
                      sslSecret:
                        description: Name of the secret to use for ssl information
                        type: string
                      sslProvider:
                        description: >-
                          Used to change the SSL Provider between JDK and
                          OPENSSL. The default is JDK.
                        type: string
                console:
                  description: Configuration for the embedded web console
                  type: object
                  properties:
                    expose:
                      description: Whether or not to expose this port
                      type: boolean
                    sslEnabled:
                      description: Whether or not to enable SSL on this port
                      type: boolean
                    sslSecret:
                      description: Name of the secret to use for ssl information
                      type: string
                    useClientAuth:
                      description: If the embedded server requires client authentication
                      type: boolean
                deploymentPlan:
                  type: object
                  properties:
                    image:
                      description: The image used for the broker deployment
                      type: string
                    journalType:
                      description: 'If aio use ASYNCIO, if nio use NIO for journal IO'
                      type: string
                    messageMigration:
                      description: If true migrate messages on scaledown
                      type: boolean
                    persistenceEnabled:
                      description: >-
                        If true use persistent volume via persistent volume
                        claim for journal storage
                      type: boolean
                    requireLogin:
                      description: >-
                        If true require user password login credentials for
                        broker protocol ports
                      type: boolean
                    size:
                      description: The number of broker pods to deploy
                      type: integer
                      maximum: 16
                      minimum: 0
                upgrades:
                  description: >-
                    Specify the level of upgrade that should be allowed when an
                    older product version is detected
                  type: object
                  properties:
                    enabled:
                      description: >-
                        Set true to enable automatic micro version product
                        upgrades, it is disabled by default.
                      type: boolean
                    minor:
                      description: >-
                        Set true to enable automatic minor product version
                        upgrades, it is disabled by default. Requires
                        spec.upgrades.enabled to be true.
                      type: boolean
                version:
                  description: The version of the application deployment.
                  type: string
            status:
              type: object
              required:
                - podStatus
              properties:
                podStatus:
                  type: object
                  properties:
                    ready:
                      type: array
                      items:
                        type: string
                    starting:
                      type: array
                      items:
                        type: string
                    stopped:
                      type: array
                      items:
                        type: string
    - name: v2alpha1
      served: true
      storage: false
      schema:
        openAPIV3Schema:
          type: object
          required:
            - spec
          properties:
            apiVersion:
              type: string
            kind:
              type: string
            metadata:
              type: object
            spec:
              type: object
              properties:
                acceptors:
                  description: Configuration of all acceptors
                  type: array
                  minItems: 0
                  items:
                    description: A single acceptor configuration
                    type: object
                    properties:
                      port:
                        description: Port number
                        type: integer
                      verifyHost:
                        description: >-
                          The CN of the connecting client's SSL certificate will
                          be compared to its hostname to verify they match. This
                          is useful only for 2-way SSL.
                        type: boolean
                      wantClientAuth:
                        description: >-
                          Tells a client connecting to this acceptor that 2-way
                          SSL is requested but not required. Overridden by
                          needClientAuth.
                        type: boolean
                      expose:
                        description: Whether or not to expose this acceptor
                        type: boolean
                      enabledCipherSuites:
                        description: >-
                          Comma separated list of cipher suites used for SSL
                          communication.
                        type: string
                      needClientAuth:
                        description: >-
                          Tells a client connecting to this acceptor that 2-way
                          SSL is required. This property takes precedence over
                          wantClientAuth.
                        type: boolean
                      multicastPrefix:
                        description: To indicate which kind of routing type to use.
                        type: string
                      name:
                        description: The name of the acceptor
                        type: string
                      connectionsAllowed:
                        description: >-
                          Limits the number of connections which the acceptor
                          will allow. When this limit is reached a DEBUG level
                          message is issued to the log, and the connection is
                          refused.
                        type: integer
                      sslEnabled:
                        description: Whether or not to enable SSL on this port
                        type: boolean
                      sniHost:
                        description: >-
                          A regular expression used to match the server_name
                          extension on incoming SSL connections. If the name
                          doesn't match then the connection to the acceptor will
                          be rejected.
                        type: string
                      enabledProtocols:
                        description: >-
                          Comma separated list of protocols used for SSL
                          communication.
                        type: string
                      protocols:
                        description: The protocols to enable for this acceptor
                        type: string
                      sslSecret:
                        description: Name of the secret to use for ssl information
                        type: string
                      sslProvider:
                        description: >-
                          Used to change the SSL Provider between JDK and
                          OPENSSL. The default is JDK.
                        type: string
                      anycastPrefix:
                        description: To indicate which kind of routing type to use.
                        type: string
                adminPassword:
                  description: >-
                    Password for standard broker user. It is required for
                    connecting to the broker. If left empty, it will be
                    generated.
                  type: string
                adminUser:
                  description: >-
                    User name for standard broker user. It is required for
                    connecting to the broker. If left empty, it will be
                    generated.
                  type: string
                connectors:
                  description: Configuration of all connectors
                  type: array
                  minItems: 0
                  items:
                    description: A single connector configuration
                    type: object
                    properties:
                      port:
                        description: Port number
                        type: integer
                      verifyHost:
                        description: >-
                          The CN of the connecting client's SSL certificate will
                          be compared to its hostname to verify they match. This
                          is useful only for 2-way SSL.
                        type: boolean
                      wantClientAuth:
                        description: >-
                          Tells a client connecting to this acceptor that 2-way
                          SSL is requested but not required. Overridden by
                          needClientAuth.
                        type: boolean
                      expose:
                        description: Whether or not to expose this connector
                        type: boolean
                      enabledCipherSuites:
                        description: >-
                          Comma separated list of cipher suites used for SSL
                          communication.
                        type: string
                      host:
                        description: Hostname or IP to connect to
                        type: string
                      needClientAuth:
                        description: >-
                          Tells a client connecting to this acceptor that 2-way
                          SSL is required. This property takes precedence over
                          wantClientAuth.
                        type: boolean
                      name:
                        description: The name of the acceptor
                        type: string
                      sslEnabled:
                        description: Whether or not to enable SSL on this port
                        type: boolean
                      sniHost:
                        description: >-
                          A regular expression used to match the server_name
                          extension on incoming SSL connections. If the name
                          doesn't match then the connection to the acceptor will
                          be rejected.
                        type: string
                      enabledProtocols:
                        description: >-
                          Comma separated list of protocols used for SSL
                          communication.
                        type: string
                      type:
                        description: The type either tcp or vm
                        type: string
                      sslSecret:
                        description: Name of the secret to use for ssl information
                        type: string
                      sslProvider:
                        description: >-
                          Used to change the SSL Provider between JDK and
                          OPENSSL. The default is JDK.
                        type: string
                console:
                  description: Configuration for the embedded web console
                  type: object
                  properties:
                    expose:
                      description: Whether or not to expose this port
                      type: boolean
                    sslEnabled:
                      description: Whether or not to enable SSL on this port
                      type: boolean
                    sslSecret:
                      description: Name of the secret to use for ssl information
                      type: string
                    useClientAuth:
                      description: If the embedded server requires client authentication
                      type: boolean
                deploymentPlan:
                  type: object
                  properties:
                    image:
                      description: The image used for the broker deployment
                      type: string
                    journalType:
                      description: 'If aio use ASYNCIO, if nio use NIO for journal IO'
                      type: string
                    messageMigration:
                      description: If true migrate messages on scaledown
                      type: boolean
                    persistenceEnabled:
                      description: >-
                        If true use persistent volume via persistent volume
                        claim for journal storage
                      type: boolean
                    requireLogin:
                      description: >-
                        If true require user password login credentials for
                        broker protocol ports
                      type: boolean
                    size:
                      description: The number of broker pods to deploy
                      type: integer
                      maximum: 16
                      minimum: 0
            status:
              type: object
              required:
                - podStatus
              properties:
                podStatus:
                  type: object
                  properties:
                    ready:
                      type: array
                      items:
                        type: string
                    starting:
                      type: array
                      items:
                        type: string
                    stopped:
                      type: array
                      items:
                        type: string
    - name: v1alpha1
      served: false
      storage: false
  conversion:
    strategy: None
  preserveUnknownFields: true


EOL

kubectl apply -f ${TMP_DIR}/broker_activemqartemis_crd.yaml -n "${NAMESPACE}"

echo "broker_activemqartemis_crd created"


cat <<EOL > broker_activemqartemisaddress_crd.yaml
kind: CustomResourceDefinition
apiVersion: apiextensions.k8s.io/v1beta1
metadata:
  name: activemqartemisaddresses.broker.amq.io
spec:
  subresources:
    status: {}
  names:
    plural: activemqartemisaddresses
    singular: activemqartemisaddress
    kind: ActiveMQArtemisAddress
    listKind: ActiveMQArtemisAddressList
  scope: Namespaced
  conversion:
    strategy: None
  preserveUnknownFields: true
  version: v2alpha2
  validation:
    openAPIV3Schema:
      properties:
        apiVersion:
          type: string
        kind:
          type: string
        metadata:
          type: object
        spec:
          type: object
          required:
            - addressName
            - queueName
            - routingType
          properties:
            addressName:
              type: string
            queueName:
              type: string
            routingType:
              type: string
            removeFromBrokerOnDelete:
              type: boolean
        status:
          type: object
  versions:
    - name: v2alpha2
      served: true
      storage: true
    - name: v2alpha1
      served: true
      storage: false
    - name: v1alpha2
      served: true
      storage: false
    - name: v1alpha1
      served: false
      storage: false
  group: broker.amq.io

EOL

kubectl apply -f ${TMP_DIR}/broker_activemqartemisaddress_crd.yaml -n "${NAMESPACE}"

echo "broker_activemqartemisaddress_crd created"


cat <<EOL > ${TMP_DIR}/operator.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: amq-broker-operator
spec:
  replicas: 1
  selector:
    matchLabels:
      name: amq-broker-operator
  strategy:
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 1
    type: RollingUpdate
  template:
    metadata:
      labels:
        name: amq-broker-operator
    spec:
      containers:
      - args:
        # Explicitly set the logging level.
        # Valid values are debug, info, and error
        # from most to least.
        # If running entrypoint_debug then use '-- --zap-level debug'
        - '--zap-level info'
        - '--zap-encoder console'
        command:
        - /home/amq-broker-operator/bin/entrypoint
        env:
        - name: OPERATOR_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.labels['name']
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: WATCH_NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace

        # Below are the environment variables that inform the operator what container images to utilize for each product version.
        # By default the *_782 values are utilized.
        # The *Init* values refer to the init container images that configure the broker configuration prior to broker container start.
        # The *Kubernetes* values refer to the broker on openshift container that runs the broker itself.
        # NOTE: Below are the original image:tag values and equivalent SHA image references. The SHA values are unique to the specific
        #       container tag utilized during operator bundle build time.

        - name: RELATED_IMAGE_ActiveMQ_Artemis_Broker_Init_770
          #value: registry.redhat.io/amq7/amq-broker-init-rhel7:0.2-7
          value: registry.redhat.io/amq7/amq-broker-init-rhel7@sha256:b194c366a940f34aa86454f84f1a8ec3b2670456033882f4ef7f514da3f290c5
        - name: RELATED_IMAGE_ActiveMQ_Artemis_Broker_Init_780
          #value: registry.redhat.io/amq7/amq-broker-init-rhel7:0.2-10
          value: registry.redhat.io/amq7/amq-broker-init-rhel7@sha256:a83f896a0f2f048495b9bd9e5eabb620d450ab525b3ca6125c88a5a541d2653f
        - name: RELATED_IMAGE_ActiveMQ_Artemis_Broker_Init_781
          #value: registry.redhat.io/amq7/amq-broker-init-rhel7:0.2-13
          value: registry.redhat.io/amq7/amq-broker-init-rhel7@sha256:16b649b60ab0dcf93e4e0953033337bb651f99c2d1a1f11fff56ae8b93f5fefc
        - name: RELATED_IMAGE_ActiveMQ_Artemis_Broker_Init_782
          #value: registry.redhat.io/amq7/amq-broker-init-rhel7:0.2-14
          value: registry.redhat.io/amq7/amq-broker-init-rhel7@sha256:3267f2235f8721366a72a42dbb8ac26e6e296bf269b62bc6ab5339e25fdce817
        - name: RELATED_IMAGE_ActiveMQ_Artemis_Broker_Kubernetes_770
          #value: registry.redhat.io/amq7/amq-broker:7.7
          value: registry.redhat.io/amq7/amq-broker@sha256:6cdd36d43872146e852daadae6882370f657a60a3b1e88318767fa9641f5e882
        - name: RELATED_IMAGE_ActiveMQ_Artemis_Broker_Kubernetes_780
          #value: registry.redhat.io/amq7/amq-broker:7.8-12
          value: registry.redhat.io/amq7/amq-broker@sha256:a6a2fd548f4e89151a8e7d4bacb7380d0076bbd1b1f5bc5555f2e95e19e1441f
        - name: RELATED_IMAGE_ActiveMQ_Artemis_Broker_Kubernetes_781
          #value: registry.redhat.io/amq7/amq-broker:7.8-16
          value: registry.redhat.io/amq7/amq-broker@sha256:836b70b8a1d1c855d2dbb843e667fae94da639e352d344327f298015c2404d98
        - name: RELATED_IMAGE_ActiveMQ_Artemis_Broker_Kubernetes_782
          #value: registry.redhat.io/amq7/amq-broker:7.8-20
          value: registry.redhat.io/amq7/amq-broker@sha256:5dc83278496e1c0401aab5dafdc266b94e5458e47125c455b7edc74f9ee4e816

        #image: registry.redhat.io/amq7/amq-broker-rhel7-operator:7.8-8
        image: registry.redhat.io/amq7/amq-broker-rhel7-operator@sha256:325368abcfc8d1697868dc9ea00534c18721251068f759e316ca4661eda61939

        # If floating tags are configured above you may want to set this to true.
        #imagePullPolicy: Always

        name: amq-broker-operator
        resources: {}
      serviceAccountName: amq-broker-operator
EOL

kubectl apply -f ${TMP_DIR}/operator.yaml -n "${NAMESPACE}"

echo "operator created"

cat <<EOL > ${TMP_DIR}/broker_activemqartemis_cr.yaml
apiVersion: broker.amq.io/v2alpha4
kind: ActiveMQArtemis
metadata:
  name: ex-aao
  application: ex-aao-app
spec:
  deploymentPlan:
    size: 1
    image: placeholder
    requireLogin: false
    persistenceEnabled: false
    journalType: nio
    messageMigration: false
    resources:
      limits:
        cpu: 500m
        memory: 1024Mi
      requests:
        cpu: 250m
        memory: 512Mi
    storage:
      size: "4Gi"
    jolokiaAgentEnabled: false
    managementRBACEnabled: true
  console:
    expose: true
  acceptors:
    - name: amqp
      protocols: amqp
      port: 5672
      sslEnabled: false
      enabledProtocols: TLSv1,TLSv1.1,TLSv1.2
      needClientAuth: true
      wantClientAuth: true
      verifyHost: true
      sslProvider: JDK
      sniHost: localhost
      expose: true
      anycastPrefix: jms.queue.
      multicastPrefix: /topic/
  connectors:
    - name: connector0
      host: localhost
      port: 22222
      sslEnabled: false
      enabledProtocols: TLSv1,TLSv1.1,TLSv1.2
      needClientAuth: true
      wantClientAuth: true
      verifyHost: true
      sslProvider: JDK
      sniHost: localhost
      expose: true
  upgrades:
      enabled: false
      minor: false
EOL

kubectl apply -f ${TMP_DIR}/broker_activemqartemis_cr.yaml -n "${NAMESPACE}"

echo "broker_activemqartemis_cr operator created"






