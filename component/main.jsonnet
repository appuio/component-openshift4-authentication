// main template for openshift4-authentication
local common = import 'common.libjsonnet';
local ldap = import 'ldap.libsonnet';
local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local rbac = import 'rbac.libsonnet';
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
  data: {
    [if hasErrorTemplate then 'errors.html']: params.templates.err,
    [if hasLoginTemplate then 'login.html']: params.templates.login,
    [if hasProviderSelectionTemplate then 'providers.html']: params.templates.providerSelection,
  },
});

local idps = params.identityProviders;

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
  if idps[idpname].type == 'LDAP'
];

local identityProviders = [
  local idp = idps[idpname];

  idp {
    ldap+: {
      ca: { name: common.RefName(idp.name) },
      bindPassword: {
        name: if std.objectHas(idp, 'bindPasswordSecretRef') then params.secrets[idp.bindPasswordSecretRef] else common.RefName(idp.name),
      },
    },
  }
  for idpname in std.objectFields(idps)
  if idps[idpname].type == 'LDAP'
] + [
  local idp = idps[idpname];
  idp {
    openID+: {
      clientSecret: {
        name: params.secrets[idp.openID.clientSecretRef],
      },
    },
  }
  for idpname in std.objectFields(idps)
  if idps[idpname].type == 'OpenID'
] + [
  idps[idpname]
  for idpname in std.objectFields(idps)
  if idps[idpname].type != 'LDAP' && idps[idpname].type != 'OpenID'
];

local ldapSync =
  local ldapSyncServiceAccount = com.namespaced(params.namespace, kube.ServiceAccount('ldap-sync'));

  [
    ldapSyncServiceAccount,
    kube.ClusterRoleBinding('ldap-sync') {
      subjects_: [ ldapSyncServiceAccount ],
      roleRef_: {
        kind: 'ClusterRole',
        metadata: {
          name: 'cluster-admin',
        },
      },
    },
  ] + std.flattenArrays([
    ldap.syncConfig(params.namespace, idps[idpname], ldapSyncServiceAccount.metadata.name)
    for idpname in std.objectFields(idps)
    if idps[idpname].type == 'LDAP'
  ]);

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


// Define outputs below
{
  [if hasTemplates then '01_template']: template,
  [if std.length(configs) > 0 then '03_configs']: configs,
  '10_oauth': clusterOAuth,
  [if std.length(ldapSync) > 2 then '20_ldap_sync']: ldapSync,
  '30_rbac': rbac,
}
