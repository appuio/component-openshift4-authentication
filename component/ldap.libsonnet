local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local oauth = import 'lib/openshift4-oauth.libjsonnet';
local inv = kap.inventory();

local params = inv.parameters.openshift4_oauth;

local syncConfig(namespace, idp, sa) =
  local name = 'ldap-sync-' + oauth.RefName(idp.name);
  local mount = '/etc/sync-config/';
  local files = {
    caBundle: 'ca-bundle.crt',
    config: 'config.yaml',
    blacklist: 'blacklist.txt',
    whitelist: 'whitelist.txt',
  };
  local syncCfg = {
    kind: 'LDAPSyncConfig',
    apiVersion: 'v1',
    url: idp.ldap.url,
    bindDN: idp.ldap.bindDN,
    bindPassword: idp.ldap.bindPassword,
    ca: mount + files.caBundle,
    [if std.objectHas(idp.ldap.sync, 'rfc2307') then 'rfc2307']: idp.ldap.sync.rfc2307,
    [if std.objectHas(idp.ldap.sync, 'activeDirectory') then 'activeDirectory']: idp.ldap.sync.activeDirectory,
    [if std.objectHas(idp.ldap.sync, 'augmentedActiveDirectory') then 'augmentedActiveDirectory']: idp.ldap.sync.augmentedActiveDirectory,
  };

  [
    com.namespaced(namespace, kube.Secret(name) {
      stringData: {
        [files.blacklist]: if std.objectHas(idp.ldap.sync, 'blacklist') then idp.ldap.sync.blacklist else '',
        [files.caBundle]: idp.ldap.ca,
        [files.config]: std.manifestYamlDoc(syncCfg),
        [files.whitelist]: if std.objectHas(idp.ldap.sync, 'whitelist') then idp.ldap.sync.whitelist else '',
      },
    }),

    local volume = 'sync-config';
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
                      '--sync-config=' + mount + files.config,
                      '--confirm',
                      '--blacklist=' + mount + files.blacklist,
                      '--whitelist=' + mount + files.whitelist,
                    ],
                    volumeMounts_+: {
                      [volume]: { mountPath: mount },
                    },
                  },
                ],
                serviceAccountName: sa,
                volumes_+: {
                  [volume]: { secret: { secretName: name } },
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
