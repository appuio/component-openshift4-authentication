local common = import 'common.libsonnet';
local com = import 'lib/commodore.libjsonnet';
local esp = import 'lib/espejote.libsonnet';
local kap = import 'lib/kapitan.libjsonnet';

// The hiera parameters for the component
local inv = kap.inventory();
local params = inv.parameters.openshift4_authentication;

local metadataPatch = {
  annotations+: {
    'syn.tools/source': 'https://github.com/appuio/component-openshift4-authentication.git',
  },
  labels+: {
    'app.kubernetes.io/managed-by': 'espejote',
    'app.kubernetes.io/part-of': 'syn',
    'app.kubernetes.io/component': 'openshift4-authentication',
  },
};

local patch = {
  apiVersion: 'rbac.authorization.k8s.io/v1',
  kind: 'ClusterRoleBinding',
  metadata: {
    name: 'self-provisioners',
  },
  roleRef: {
    apiGroup: 'rbac.authorization.k8s.io',
    kind: 'ClusterRole',
    name: 'self-provisioner',
  },
  subjects: [
    {
      apiGroup: 'rbac.authorization.k8s.io',
      kind: 'Group',
      name: group,
    }
    for group in com.renderArray(params.selfProvisionerGroups)
  ],
};

local serviceAccount = {
  apiVersion: 'v1',
  kind: 'ServiceAccount',
  metadata: {
    name: 'rbac-clusterrolebinding-self-provisioners',
    namespace: inv.parameters.espejote.namespace,
  } + metadataPatch,
};

local clusterRole = {
  apiVersion: 'rbac.authorization.k8s.io/v1',
  kind: 'ClusterRole',
  metadata: {
    name: 'syn-espejote:rbac-clusterrolebinding-self-provisioners',
  } + metadataPatch,
  rules: [
    {
      apiGroups: [ '', 'project.openshift.io' ],
      resources: [ 'projectrequests' ],
      verbs: [ 'create' ],
    },
    {
      apiGroups: [ 'rbac.authorization.k8s.io' ],
      resources: [ 'clusterrolebindings' ],
      resourceNames: [ 'self-provisioners' ],
      verbs: [ '*' ],
    },
  ],
};

local clusterRoleBinding = {
  apiVersion: 'rbac.authorization.k8s.io/v1',
  kind: 'ClusterRoleBinding',
  metadata: {
    name: 'syn-espejote:rbac-clusterrolebinding-self-provisioners',
  } + metadataPatch,
  roleRef: {
    apiGroup: 'rbac.authorization.k8s.io',
    kind: 'ClusterRole',
    name: clusterRole.metadata.name,
  },
  subjects: [
    {
      kind: 'ServiceAccount',
      name: serviceAccount.metadata.name,
      namespace: serviceAccount.metadata.namespace,
    },
  ],
};

local managedResource = esp.managedResource('rbac-clusterrolebinding-self-provisioners', inv.parameters.espejote.namespace) {
  metadata+: metadataPatch,
  spec: {
    applyOptions: {
      force: true,
    },
    serviceAccountRef: {
      name: serviceAccount.metadata.name,
    },
    template: std.manifestJson(patch),
    triggers: [ {
      name: 'clusterrolebinding',
      watchResource: {
        apiVersion: patch.apiVersion,
        kind: patch.kind,
        name: patch.metadata.name,
      },
    } ],
  },
};

{
  selfProvisioning: [
    serviceAccount,
    clusterRole,
    clusterRoleBinding,
    managedResource,
  ],
}
