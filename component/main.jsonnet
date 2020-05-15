// main template for openshift4-oauth
local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
// The hiera parameters for the component
local params = inv.parameters.openshift4_oauth;

local hasErrorTemplate = std.length(params.templates.err) > 0;
local hasLoginTemplate = std.length(params.templates.login) > 0;
local hasProviderSelectionTemplate = std.length(params.templates.providerSelection) > 0;
local hasTemplates = hasErrorTemplate || hasLoginTemplate || hasProviderSelectionTemplate;
local hasIdentityProviders = std.length(params.identityProviders) > 0;
local hasTokenTimeouts = std.type(params.token.timeoutSeconds) == 'number';
local hasTokenMaxAge = std.type(params.token.maxAgeSeconds) == 'number';
local hasTokenConfig = hasTokenTimeouts || hasTokenMaxAge;

local template = com.namespaced(params.namespace, kube.Secret('oauth-templates') {
  data: {
    [if hasErrorTemplate then 'errors.html']: params.templates.err,
    [if hasLoginTemplate then 'login.html']: params.templates.login,
    [if hasProviderSelectionTemplate then 'providers.html']: params.templates.providerSelection,
  },
});

local clusterOAuth = kube._Object('config.openshift.io/v1', 'OAuth', 'cluster') {
  spec: {
    [if hasTemplates then 'templates']: {
      [if hasErrorTemplate then 'error']: { name: template.metadata.name },
      [if hasLoginTemplate then 'login']: { name: template.metadata.name },
      [if hasProviderSelectionTemplate then 'providerSelection']: { name: template.metadata.name },
    },
    [if hasIdentityProviders then 'identityProviders']: params.identityProviders,
    [if hasTokenConfig then 'tokenConfig']: {
      [if hasTokenTimeouts then 'accessTokenInactivityTimeoutSeconds']: params.token.timeoutSeconds,
      [if hasTokenMaxAge then 'accessTokenMaxAgeSeconds']: params.token.maxAgeSeconds,
    },
  },
};

// Define outputs below
{
  [if hasTemplates then '01_template']: template,
  '05_oauth': clusterOAuth,
}
