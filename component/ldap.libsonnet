local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local oauth = import 'lib/openshift4-oauth.libjsonnet';
local inv = kap.inventory();

local params = inv.parameters.openshift4_oauth;

local syncConfig(namespace, idp) =
  local name = 'ldap-sync-' + oauth.RefName(idp.name);
  local syncCfg = {
    kind: 'LDAPSyncConfig',
    apiVersion: 'v1',
    url: idp.ldap.url,
    bindDN: idp.ldap.bindDN,
    bindPassword: idp.ldap.bindPassword,
    ca: '/etc/sync-config/ca-bundle.crt',
    [if std.objectHas(idp.ldap.sync, 'rfc2307') then 'rfc2307']: idp.ldap.sync.rfc2307,
    [if std.objectHas(idp.ldap.sync, 'activeDirectory') then 'activeDirectory']: idp.ldap.sync.activeDirectory,
    [if std.objectHas(idp.ldap.sync, 'augmentedActiveDirectory') then 'augmentedActiveDirectory']: idp.ldap.sync.augmentedActiveDirectory,
  };

  [
    com.namespaced(namespace, kube.Secret(name) {
      stringData: {
        'ca-bundle.crt': idp.ldap.ca,
        'config.yaml': std.manifestYamlDoc(syncCfg),
      },
    }),
  ];

local replaceField(obj, name, replacement) = std.prune(std.mapWithKey(function(k, v)
  if k == name
  then replacement
  else v, obj));

local withoutLdapSyncConfig(idps) = std.map(function(idp) replaceField(idp, 'ldap', replaceField(idp.ldap, 'sync', null)), idps);

{
  syncConfig: syncConfig,
  withoutLdapSyncConfig: withoutLdapSyncConfig,
}
