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

local idps = params.identityProviders;

// To avoid breaking changes for LDAP, we support the identityProviders.<name>.ldap.bindPassword parameter
local legacySecrets = [
  local idp = idps[idpname];

  com.namespaced(params.namespace, kube.Secret(common.RefName(idp.name)) {
    metadata+: {
      annotations+: {
        'argocd.argoproj.io/compare-options': 'IgnoreExtraneous',
      },
      labels+: common.commonLabels(),
    },
    stringData+: {
      bindPassword: idp.ldap.bindPassword,
    },
  })
  for idpname in std.objectFields(idps)
  if idps[idpname].type == 'LDAP'
];

local secrets = [
  com.namespaced(params.namespace, kube.Secret(common.RefName(secretName)) {
    metadata+: {
      annotations+: common.argoAnnotations(),
      labels+: common.commonLabels(),
    },
    stringData: params.secrets[secretName],
  })
  for secretName in std.objectFields(params.secrets)
] + legacySecrets;


// Define outputs below
{
  [if std.length(secrets) > 0 then '02_secrets']: secrets,
}
