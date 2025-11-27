// main template for openshift4-authentication
local common = import 'common.libjsonnet';
local ldap = import 'ldap.libsonnet';
local com = import 'lib/commodore.libjsonnet';
local esp = import 'lib/espejote.libsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'kube-ssa-compat.libsonnet';
local rbac = import 'rbac.libsonnet';
local sp = import 'self-provisioning.libsonnet';
local inv = kap.inventory();
// The hiera parameters for the component
local params = inv.parameters.openshift4_authentication;

local hasErrorTemplate = std.length(params.templates.err) > 0;
local hasLoginTemplate = std.length(params.templates.login) > 0;
local hasProviderSelectionTemplate = std.length(params.templates.providerSelection) > 0;
local hasTemplates = hasErrorTemplate || hasLoginTemplate || hasProviderSelectionTemplate;
local hasIdentityProviders = std.length(params.identityProviders) > 0;
local hasTokenTimeouts = std.type(params.token.timeoutSeconds) == 'number';
local hasTokenMaxAge = std.type(params.token.maxAgeSeconds) == 'number';
local hasTokenConfig = hasTokenTimeouts || hasTokenMaxAge;

local template = com.namespaced(params.namespace, kube.Secret('oauth-templates') {
  metadata+: {
    annotations+: common.argoAnnotations,
    labels+: common.commonLabels,
  },
  data:: {},
  stringData: {
    [if hasErrorTemplate then 'errors.html']: params.templates.err,
    [if hasLoginTemplate then 'login.html']: params.templates.login,
    [if hasProviderSelectionTemplate then 'providers.html']: params.templates.providerSelection,
  },
});

local idps = std.prune(params.identityProviders);

local configs = [
  local idp = idps[idpname];

  com.namespaced(params.namespace, kube.ConfigMap(common.RefName(idp.name)) {
    metadata+: {
      annotations+: common.argoAnnotations,
      labels+: common.commonLabels,
    },
    data: {
      'ca.crt': idp.ldap.ca,
    },
  })
  for idpname in std.objectFields(idps)
  if idps[idpname].type == 'LDAP' && std.objectHas(idps[idpname].ldap, 'ca')
];

local identityProviders = [
  local idp = idps[idpname];

  idp {
    ldap+: {
      [if std.objectHas(idp.ldap, 'ca') then 'ca']: { name: common.RefName(idp.name) },
      bindPassword:
        if std.isString(super.bindPassword) then
          // Legacy variant: value of `bindPassword` is a string, so we inject the secret name for the generated legacy secret
          { name: common.RefName(idp.name) }
        else
          // In other cases: Just reuse the original value for `bindPassword`, leave it to the user to correctly format it.
          super.bindPassword,
    },
  }
  for idpname in std.objectFields(idps)
  if idps[idpname].type == 'LDAP'
] + [
  idps[idpname]
  for idpname in std.objectFields(idps)
  if idps[idpname].type != 'LDAP'
];

local ldapSync =
  local ldapSyncServiceAccount = com.namespaced(params.namespace, kube.ServiceAccount('ldap-sync'));
  local ldapSyncRole = kube.ClusterRole('syn-ldap-sync') {
    rules: [
      {
        apiGroups: [ 'user.openshift.io' ],
        resources: [ 'groups' ],
        verbs: [ '*' ],
      },
    ],
  };

  local ldapIDPs = std.flattenArrays([
    ldap.syncConfig(params.namespace, idps[idpname], ldapSyncServiceAccount.metadata.name)
    for idpname in std.objectFields(idps)
    if idps[idpname].type == 'LDAP'
  ]);
  if std.length(ldapIDPs) > 0 then
    [
      ldapSyncServiceAccount,
      ldapSyncRole,
      kube.ClusterRoleBinding('syn-ldap-sync') {
        subjects_: [ ldapSyncServiceAccount ],
        roleRef_: ldapSyncRole,
      },
    ] + ldapIDPs
  else [];

local clusterOAuth = kube._Object('config.openshift.io/v1', 'OAuth', 'cluster') {
  spec: {
    [if hasTemplates then 'templates']: {
      [if hasErrorTemplate then 'error']: { name: template.metadata.name },
      [if hasLoginTemplate then 'login']: { name: template.metadata.name },
      [if hasProviderSelectionTemplate then 'providerSelection']: { name: template.metadata.name },
    },
    [if hasIdentityProviders then 'identityProviders']: ldap.withoutLdapSyncConfig(identityProviders),
    [if hasTokenConfig then 'tokenConfig']: {
      [if hasTokenTimeouts then 'accessTokenInactivityTimeoutSeconds']: params.token.timeoutSeconds,
      [if hasTokenMaxAge then 'accessTokenMaxAgeSeconds']: params.token.maxAgeSeconds,
    },
  },
};

local removeKubeAdmin =
  local sa = kube.ServiceAccount('kube-admin-manager') {
    metadata+: {
      namespace: params.namespace,
    },
  };
  local role = kube.Role('kube-admin-manager') {
    metadata+: {
      namespace: 'kube-system',
    },
    rules: [
      {
        apiGroups: [ '' ],
        resources: [ 'secrets' ],
        verbs: [ 'delete' ],
        resourceNames: [ 'kubeadmin' ],
      },
    ],
  };
  local rolebinding = kube.RoleBinding('kube-admin-manager') {
    metadata+: {
      namespace: 'kube-system',
    },
    roleRef_: role,
    subjects_: [ sa ],
  };
  [
    sa,
    role,
    rolebinding,
    esp.managedResource('remove-kube-admin', params.namespace) {
      metadata+: {
        annotations+: {
          // Remove kubeadmin secret after oauth providers have been configured
          'argocd.argoproj.io/sync-wave': '10',
        },
        labels+: {
          'app.kubernetes.io/component': 'openshift4-authentication',
          'app.kubernetes.io/managed-by': 'commodore',
        },
      },
      spec: {
        serviceAccountRef: {
          name: sa.metadata.name,
        },
        template: |||
          local esp = import 'espejote.libsonnet';
          local kubeadminSecret = {
            apiVersion: 'v1',
            kind: 'Secret',
            metadata: {
              name: 'kubeadmin',
              namespace: 'kube-system',
            }
          };
          esp.markForDelete(kubeadminSecret)
        |||,
        triggers: [],
      },
    },
  ];

// Define outputs below
{
  [if hasTemplates then '01_template']: template,
  [if std.length(configs) > 0 then '03_configs']: configs,
  '10_oauth': clusterOAuth,
  [if std.length(ldapSync) > 0 then '20_ldap_sync']: ldapSync,
  '30_rbac': rbac,
  '40_remove_kubeadmin_managedresource': removeKubeAdmin,
  '50_self_provisioning': sp.selfProvisioning,
}
