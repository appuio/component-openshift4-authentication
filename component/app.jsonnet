local kap = import 'lib/kapitan.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.openshift4_authentication;
local argocd = import 'lib/argocd.libjsonnet';

local app = argocd.App('openshift4-authentication', params.namespace);

{
  'openshift4-authentication': app,
}
