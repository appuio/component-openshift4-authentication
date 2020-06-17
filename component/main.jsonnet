// main template for openshift4-authentication
local ldap = import 'ldap.libsonnet';
local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local authentication = import 'lib/openshift4-authentication.libjsonnet';
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

local secrets = [
  com.namespaced(params.namespace, kube.Secret(authentication.RefName(idp.name)) {
    metadata+: {
      annotations+: {
        'argocd.argoproj.io/sync-options': 'Prune=false',
        'argocd.argoproj.io/compare-options': 'IgnoreExtraneous',
      },
    },
    stringData+: {
      bindPassword: idp.ldap.bindPassword,
    },
  })
  for idp in params.identityProviders
  if idp.type == 'LDAP'
];

local configs = [
  com.namespaced(params.namespace, kube.ConfigMap(authentication.RefName(idp.name)) {
    metadata+: {
      annotations+: {
        'argocd.argoproj.io/sync-options': 'Prune=false',
        'argocd.argoproj.io/compare-options': 'IgnoreExtraneous',
      },
    },
    data: {
      'ca.crt': idp.ldap.ca,
    },
  })
  for idp in params.identityProviders
  if idp.type == 'LDAP'
];

local identityProviders = [
  idp {
    ldap+: {
      ca: { name: authentication.RefName(idp.name) },
      bindPassword: { name: authentication.RefName(idp.name) },
    },
  }
  for idp in params.identityProviders
  if idp.type == 'LDAP'
];

local ldapSync =
  local ldapSyncServiceAccount = com.namespaced(params.namespace, kube.ServiceAccount('ldap-sync'));

  [
    ldapSyncServiceAccount,
    kube.ClusterRoleBinding('ldap-sync') {
      subjects_: [ldapSyncServiceAccount],
      roleRef: {
        kind: 'ClusterRole',
        metadata: {
          name: 'cluster-admin',
        },
      },
    },
  ] + std.flattenArrays([
    ldap.syncConfig(params.namespace, idp, ldapSyncServiceAccount.metadata.name)
    for idp in params.identityProviders
    if idp.type == 'LDAP'
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
  [if std.length(secrets) > 0 then '02_secrets']: secrets,
  [if std.length(configs) > 0 then '03_configs']: configs,
  '10_oauth': clusterOAuth,
  [if std.length(ldapSync) > 2 then '20_ldap_sync']: ldapSync,
}
