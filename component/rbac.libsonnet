local common = import 'common.libjsonnet';
local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();

local params = inv.parameters.openshift4_authentication;

local sudoGroups =
  local legacyGroup =
    if params.sudoGroupName != null && params.sudoGroupName != '' then
      std.trace(
        (
          '\nParameter `sudoGroupName` is deprecated.\n' +
          'Please update your config to use `sudoGroups` instead.'
        ),
        [ params.sudoGroupName ]
      )
    else
      [];
  com.renderArray(legacyGroup + params.sudoGroups);

local sudoGroupSubjects = std.map(
  function(g) {
    apiGroup: 'rbac.authorization.k8s.io',
    kind: 'Group',
    name: g,
  }, sudoGroups
);

local sudoClusterRole = kube.ClusterRole('sudo-impersonator') {
  rules: [ {
    apiGroups: [ '' ],
    resources: [ 'users', 'serviceaccounts' ],
    verbs: [ 'impersonate' ],
  }, {
    apiGroups: [ 'rbac.authorization.k8s.io' ],
    resources: [ 'clusterrolebindings', 'rolebindings' ],
    verbs: [ 'get', 'list', 'watch' ],
  } ],
};

local sudoClusterRoleBinding = kube.ClusterRoleBinding(sudoClusterRole.metadata.name) {
  subjects: sudoGroupSubjects,
  roleRef_: sudoClusterRole,
};

local sudoClusterRoleBindingView = kube.ClusterRoleBinding('sudo-view') {
  subjects: sudoGroupSubjects,
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
  kube.RoleBinding('alertmanager-access-sudoer-groups') {
    metadata+: {
      namespace: 'openshift-monitoring',
    },
    subjects: sudoGroupSubjects,
    roleRef_: {
      kind: 'Role',
      metadata: {
        name: 'monitoring-alertmanager-edit',
      },
    },
  };

local sudoMonitoringRulesView =
  kube.ClusterRoleBinding('monitoring-rules-view-sudoer-groups') {
    subjects: sudoGroupSubjects,
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
