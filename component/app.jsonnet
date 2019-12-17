local kap = import 'lib/kapitan.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.openshift4_oauth;
local argocd = import 'lib/argocd.libjsonnet';

local app = argocd.App('openshift4-oauth', params.namespace);

{
  'openshift4-oauth': app,
}
