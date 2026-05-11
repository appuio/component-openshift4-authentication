// main template for openshift4-authentication
local kube = import 'kube-ssa-compat.libsonnet';
local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local inv = kap.inventory();
// The hiera parameters for the component
local params = inv.parameters.openshift4_authentication;


local namespace = {
  metadata+: {
    namespace: params.namespace,
  },
};

local role = kube.ClusterRole('group-prune') {
  rules: [ {
    apiGroups: [ 'user.openshift.io' ],
    resources: [ 'users' ],
    verbs: [ 'get', 'list' ],
  }, {
    apiGroups: [ 'user.openshift.io' ],
    resources: [ 'groups' ],
    verbs: [ 'get', 'list', 'update', 'patch' ],
  }, {
    apiGroups: [ 'oauth.openshift.io' ],
    resources: [ 'oauthaccesstokens' ],
    verbs: [ 'get', 'list' ],
  } ],
};

local sa = kube.ServiceAccount('group-prune') + namespace;

local rb = kube.ClusterRoleBinding('group-prune') {
  subjects: [
    {
      apiGroup: '',
      kind: 'ServiceAccount',
      name: sa.metadata.name,
      namespace: sa.metadata.namespace,
    },
  ],
  roleRef_: role,
};

local cm = kube.ConfigMap('group-prune') + namespace {
  data: {
    prune: importstr './scripts/prune-groups.sh',
  },
};

local jobTemplate = {
  spec+: {
    template+: {
      spec+: {
        nodeSelector: params.groupPrune.nodeSelector,
        restartPolicy: 'Never',
        serviceAccountName: sa.metadata.name,
        containers_+: {
          prune: kube.Container('group-prune') {
            image: params.images.oc.image + ':' + params.images.oc.tag,
            command: [ '/usr/local/bin/prune' ],
            volumeMounts_+: {
              scripts: {
                mountPath: '/usr/local/bin/prune',
                subPath: 'prune',
                readOnly: true,
              },
            },
          },
        },
        volumes_+: {
          scripts: {
            configMap: {
              name: cm.metadata.name,
              defaultMode: std.parseOctal('0550'),
            },
          },
        },
      },
    },
  },
};

local cronJob = kube.CronJob('group-prune') + namespace {
  spec+: {
    schedule: params.groupPrune.schedule,
    failedJobsHistoryLimit: params.groupPrune.jobHistoryLimit.failed,
    successfulJobsHistoryLimit: params.groupPrune.jobHistoryLimit.successful,
    jobTemplate+: jobTemplate,
  },
};

local job = kube.Job('group-prune-' + std.substr(std.sha1(std.manifestJsonMinified({
  data: cm.data,
  jobTemplate: jobTemplate,
})), 0, 8)) + namespace {
  spec+: jobTemplate.spec {
    template+: {
      spec+: {
        restartPolicy: 'OnFailure',
      },
    },
  },
};

[
  role,
  sa,
  rb,
  cm,
  cronJob,
  job,
]
