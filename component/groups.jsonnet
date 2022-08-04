// main template for openshift4-authentication
local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
// The hiera parameters for the component
local params = inv.parameters.openshift4_authentication;


local groups = std.prune([
  local group = params.groupMemberships[groupName];

  if com.getValueOrDefault(group, 'state', 'present') == 'present' && std.length(group.users) > 0 then {
    apiVersion: 'user.openshift.io/v1',
    kind: 'Group',
    metadata: {
      name: groupName,
    },
    users: std.prune([
      if com.getValueOrDefault(group.users[userName], 'state', 'present') == 'present' then userName
      for userName in std.objectFields(group.users)
    ]),
  }
  for groupName in std.objectFields(params.groupMemberships)
]);

{
  [if std.length(groups) > 0 then '31_groups']: groups,
}
