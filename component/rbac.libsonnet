local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local authentication = import 'common.libjsonnet';
local inv = kap.inventory();

local params = inv.parameters.openshift4_authentication;

local sudoClusterRole = kube.ClusterRole('sudo-impersonator') {
  rules: [ {
    apiGroups: [ '' ],
    resources: [ 'users' ],
    verbs: [ 'impersonate' ],
    resourceNames: [ params.adminUserName ],
  }, {
    apiGroups: [ 'rbac.authorization.k8s.io' ],
    resources: [ 'clusterrolebindings', 'rolebindings' ],
    verbs: [ 'get', 'list', 'watch' ],
  } ],
};

local sudoClusterRoleBinding = kube.ClusterRoleBinding(sudoClusterRole.metadata.name) {
  subjects: [ {
    apiGroup: 'rbac.authorization.k8s.io',
    kind: 'Group',
    name: params.sudoGroupName,
  } ],
  roleRef_: sudoClusterRole,
};

local sudoClusterRoleBindingView = kube.ClusterRoleBinding('sudo-view') {
  subjects: [ {
    apiGroup: 'rbac.authorization.k8s.io',
    kind: 'Group',
    name: params.sudoGroupName,
  } ],
  roleRef_: {
    kind: 'ClusterRole',
    metadata: {
      name: 'view',
    },
  },
};

local clusterRoleBindingAdmin = kube.ClusterRoleBinding('impersonate-' + params.adminUserName) {
  subjects: [ {
    apiGroup: 'rbac.authorization.k8s.io',
    kind: 'User',
    name: params.adminUserName,
  } ],
  roleRef_: {
    kind: 'ClusterRole',
    metadata: {
      name: 'cluster-admin',
    },
  },
};


[
  sudoClusterRole,
  sudoClusterRoleBinding,
  sudoClusterRoleBindingView,
  clusterRoleBindingAdmin,
]
