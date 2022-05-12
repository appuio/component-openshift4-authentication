local common = import 'common.libjsonnet';
local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
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
      name: 'cluster-reader',
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

local sudoAlertmanagerAccess =
  local sanitizedGroupName = kube.hyphenate(
    std.strReplace(
      std.asciiLower(params.sudoGroupName), ' ', '-'
    )
  );
  kube.RoleBinding('alertmanager-access-' + sanitizedGroupName) {
    metadata+: {
      namespace: 'openshift-monitoring',
    },
    subjects: [ {
      apiGroup: 'rbac.authorization.k8s.io',
      kind: 'Group',
      name: params.sudoGroupName,
    } ],
    roleRef_: {
      kind: 'Role',
      metadata: {
        name: 'monitoring-alertmanager-edit',
      },
    },
  };

local sudoMonitoringRulesView =
  local sanitizedGroupName = kube.hyphenate(
    std.strReplace(
      std.asciiLower(params.sudoGroupName), ' ', '-'
    )
  );
  kube.ClusterRoleBinding('monitoring-rules-view' + sanitizedGroupName) {
    subjects: [ {
      apiGroup: 'rbac.authorization.k8s.io',
      kind: 'Group',
      name: params.sudoGroupName,
    } ],
    roleRef_: {
      kind: 'ClusterRole',
      metadata: {
        name: 'monitoring-rules-view',
      },
    },
  };

[
  sudoClusterRole,
  sudoClusterRoleBinding,
  sudoClusterRoleBindingView,
  clusterRoleBindingAdmin,
  sudoAlertmanagerAccess,
  sudoMonitoringRulesView,
]
