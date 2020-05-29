local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local oauth = import 'lib/openshift4-oauth.libjsonnet';
local inv = kap.inventory();

local params = inv.parameters.openshift4_oauth;

local syncConfig(idp) = [
  local syncCfg = {
    kind: 'LDAPSyncConfig',
    apiVersion: 'v1',
    url: idp.ldap.url,
    bindDN: idp.ldap.bindDN,
    bindPassword: idp.ldap.bindPassword,
    ca: '/etc/sync-config/ca-bundle.crt',
    rfc2307: {
      groupsQuery: {
        baseDN: 'ou=groups,dc=example,dc=com',
        scope: 'sub',
        derefAliases: 'never',
        pageSize: 0,
      },
      groupUIDAttribute: 'dn',
      groupNameAttributes: [
        'cn',
      ],
      groupMembershipAttributes: [
        'member',
      ],
      usersQuery: {
        baseDN: 'ou=users,dc=example,dc=com',
        scope: 'sub',
        derefAliases: 'never',
        pageSize: 0,
      },
      userUIDAttribute: 'dn',
      userNameAttributes: [
        'mail',
      ],
      tolerateMemberNotFoundErrors: false,
      tolerateMemberOutOfScopeErrors: false,
    },
  };
  local configMap = kube.Secret('ldap-sync-' + oauth.RefName(idp.name)) {
    metadata+: {
      namespace: params.namespace,
    },
    stringData: {
      'ca-bundle.crt': idp.ldap.ca,
      'config.yaml': std.manifestYamlDoc(syncCfg),
    },
  };
  configMap,
];

{
  syncConfig: syncConfig,
}
