local common = import 'common.libjsonnet';
local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();

local params = inv.parameters.openshift4_authentication;

local syncConfig(namespace, idp, sa) =
  local name = 'ldap-sync-' + common.RefName(idp.name);
  local ca_name = '%s-ca' % name;
  local config_mount = '/etc/sync-config/';
  local ca_mount = '/etc/sync-config-ca/';
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
    bindPassword:
      if std.isString(idp.ldap.bindPassword) then
        idp.ldap.bindPassword
      else
        params.secrets[idp.ldap.bindPassword.name].bindPassword,
    [if std.objectHas(idp.ldap.sync, 'insecure') then 'insecure']: true,
    [if !std.get(idp.ldap.sync, 'insecure', false) then 'ca']: ca_mount + files.caBundle,
    [if std.objectHas(idp.ldap.sync, 'rfc2307') then 'rfc2307']: idp.ldap.sync.rfc2307,
    [if std.objectHas(idp.ldap.sync, 'activeDirectory') then 'activeDirectory']: idp.ldap.sync.activeDirectory,
    [if std.objectHas(idp.ldap.sync, 'augmentedActiveDirectory') then 'augmentedActiveDirectory']: idp.ldap.sync.augmentedActiveDirectory,
  };

  [
    com.namespaced(namespace, kube.ConfigMap(ca_name) {
      metadata+: {
        annotations+: common.argoAnnotations,
        labels+: common.commonLabels {
          // OpenShift creates a key called 'ca-bundle.crt' with the system
          // trusted CAs when this label is set on the configmap. We ensure to
          // only set this label if the user hasn't provided a custom CA for
          // the LDAP IdP config.
          [if !std.objectHas(idp.ldap, 'ca') then 'config.openshift.io/inject-trusted-cabundle']: 'true',
        },
      },
    } + (
      if std.objectHas(idp.ldap, 'ca') then {
        data: {
          [files.caBundle]: idp.ldap.ca,
        },
      } else {
        // Hide key `data` to omit it when populating the ConfigMap with the
        // OpenShift system CA bundle. Otherwise ArgoCD will repeatedly delete
        // the CA bundle which is inserted by OpenShift and the App won't
        // sync.
        data:: {},
      }
    )),
    com.namespaced(namespace, kube.Secret(name) {
      stringData: {
        [files.blacklist]: if std.objectHas(idp.ldap.sync, 'blacklist') then idp.ldap.sync.blacklist else '',
        [files.config]: std.manifestYamlDoc(syncCfg),
        [files.whitelist]: if std.objectHas(idp.ldap.sync, 'whitelist') then idp.ldap.sync.whitelist else '',
      },
    }),

    local n = std.foldl(function(x, y) x + y, std.encodeUTF8(std.md5(inv.parameters.cluster.name)), 0);
    local config_volume = 'sync-config';
    local custom_command = std.get(idp.ldap.sync, 'command', {});
    local ca_volume = 'ldap-ca';
    local security_context = {
      allowPrivilegeEscalation: false,
      capabilities: {
        drop: [ 'ALL' ],
      },
      runAsNonRoot: true,
      runAsUser: 1000,
      seccompProfile: {
        type: 'RuntimeDefault',
      },
    };
    com.namespaced(namespace, kube.CronJob(name) {
      spec+: {
        startingDeadlineSeconds: 30,
        schedule: if std.objectHas(idp.ldap.sync, 'schedule') then idp.ldap.sync.schedule else params.ldapSync.schedule % (n % 60),
        jobTemplate+: {
          spec+: {
            template+: {
              spec+: {
                local container(command) = kube.Container(command) {
                  image: std.join(':', std.prune([ params.images.sync.image, params.images.sync.tag ])),
                  securityContext: security_context,
                  command: std.get(params.ldapSync.command, command, [
                    'oc',
                    'adm',
                    'groups',
                    command,
                    '--sync-config=' + config_mount + files.config,
                    '--confirm',
                    '--blacklist=' + config_mount + files.blacklist,
                    '--whitelist=' + config_mount + files.whitelist,
                  ]),
                  volumeMounts_+: {
                    [config_volume]: { mountPath: config_mount },
                    [ca_volume]: { mountPath: ca_mount },
                  },
                },
                containers: [
                  container('sync'),
                  container('prune'),
                ],
                serviceAccountName: sa,
                volumes_+: {
                  [config_volume]: { secret: { secretName: name } },
                  [ca_volume]: { configMap: { name: ca_name } },
                },
                nodeSelector: {
                  'node-role.kubernetes.io/master': '',
                },
                tolerations: [
                  {
                    key: 'node-role.kubernetes.io/master',
                    operator: 'Exists',
                    effect: 'NoSchedule',
                  },
                ],
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
