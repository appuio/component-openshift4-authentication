local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local oauth = import 'lib/openshift4-oauth.libjsonnet';
local inv = kap.inventory();

local params = inv.parameters.openshift4_oauth;

local syncConfig(namespace, idp, sa) =
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
        'blacklist.txt': if std.objectHas(idp.ldap.sync, 'blacklist') then idp.ldap.sync.blacklist else '',
        'ca-bundle.crt': idp.ldap.ca,
        'config.yaml': std.manifestYamlDoc(syncCfg),
        'whitelist.txt': if std.objectHas(idp.ldap.sync, 'whitelist') then idp.ldap.sync.whitelist else '',
      },
    }),

    com.namespaced(namespace, kube.CronJob(name) {
      spec+: {
        schedule: if std.objectHas(idp.ldap.sync, 'schedule') then idp.ldap.sync.schedule else params.ldapSync.schedule,
        jobTemplate+: {
          spec+: {
            template+: {
              spec+: {
                containers: [
                  kube.Container('sync') {
                    image: std.join(':', std.prune([params.images.sync.image, params.images.sync.tag])),
                    command: [
                      'oc',
                      'adm',
                      'groups',
                      'sync',
                      '--sync-config=/etc/sync-config/config.yaml',
                      '--confirm',
                      '--blacklist=/etc/sync-config/blacklist.txt',
                      '--whitelist=/etc/sync-config/whitelist.txt',
                    ],
                    volumeMounts_+: {
                      'sync-config': {mountPath: '/etc/sync-config'},
                    },
                  },
                ],
                serviceAccountName: sa,
                volumes_+: {
                  'sync-config': {secret: {secretName: name}},
                },
              },
            },
          },
        },
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
