# == class: keystone::federation::openidc [70/1473]
#
# == Parameters
#
# [*idp_name*]
#  The name name associated with the IdP in Keystone.
#  (Required) String value.
#
# [*openidc_provider_metadata_url*]
#  The url that points to your OpenID Connect metadata provider
#  (Required) String value.
#
# [*openidc_client_id*]
#  The client ID to use when handshaking with your OpenID Connect provider
#  (Required) String value.
#
# [*openidc_client_secret*]
#  The client secret to use when handshaking with your OpenID Connect provider
#  (Required) String value.
#
# [*openidc_crypto_passphrase*]
#  Secret passphrase to use when encrypting data for OpenID Connect handshake
#  (Optional) String value.
#  Defaults to 'openstack'
#
# [*openidc_response_type*]
#  Response type to be expected from the OpenID Connect provider.
#  (Optional) String value.
#  Defaults to 'id_token'
#
# [* openidc_cache_type *]
#    (Optional) mod_auth_openidc cache type.  Can be any cache type
#    supported by mod_auth_openidc (shm, file, memcache, redis).
#    Defaults to undef.
#
# [* openidc_cache_shm_max *]
#    (Optional) The maximum number of name/value pair entries that can
#    be cached when using the 'shm' cache type. Defaults to undef.
#
# [* openidc_cache_shm_entry_size *]
#    (Optional) The maximum size for a single shm cache entry in bytes
#    with a minimum of 8464 bytes. Defaults to undef.
#
# [* openidc_cache_dir *]
#    (Optional) # Directory that holds cache files; must be writable
#    for the Apache process/user. Defaults to undef.
#
# [* openidc_cache_clean_interval *]
#    (Optional) # Cache file clean interval in seconds (only triggered
#    on writes). Defaults to undef.
#
# [* memcached_servers *]
#    (Optional) A list of memcache servers. Defaults to undef.
#
# [* redis_server *]
#    (Optional) Specifies the Redis server used for caching as
#    <hostname>[:<port>]. Defaults to undef.
#
# [* redis_password *]
#    (Optional) Password to be used if the Redis server requires
#    authentication. When not specified, no authentication is
#    performed. Defaults to undef.
#
# [*admin_port*]
#  A boolean value to ensure that you want to configure openidc Federation
#  using Keystone VirtualHost on port 35357.
#  (Optional) Defaults to false.
#
# [*main_port*]
#  A boolean value to ensure that you want to configure openidc Federation
#  using Keystone VirtualHost on port 5000.
#  (Optional) Defaults to true.
#
# [*template_order*]
#  This number indicates the order for the concat::fragment that will apply
#  the shibboleth configuration to Keystone VirtualHost. The value should
#  The value should be greater than 330 an less then 999, according to:
#  https://github.com/puppetlabs/puppetlabs-apache/blob/master/manifests/vhost.pp
#  The value 330 corresponds to the order for concat::fragment  "${name}-filters"
#  and "${name}-limits".
#  The value 999 corresponds to the order for concat::fragment "${name}-file_footer".
#  (Optional) Defaults to 331.
#
# [*package_ensure*]
#   (Optional) Desired ensure state of packages.
#   accepts latest or specific versions.
#   Defaults to present.
#
# [*keystone_public_url*]
#   (Optional) URL to keystone public endpoint.
#
# [*keystone_admin_url*]
#    (Optional) URL to keystone admin endpoint.
#
# === DEPRECATED
#
# [*module_plugin*]
#  This value is no longer used.
#
class keystone::federation::openidc (
  $idp_name,
  $openidc_provider_metadata_url,
  $openidc_client_id,
  $openidc_client_secret,
  $openidc_crypto_passphrase    = 'openstack',
  $openidc_response_type        = 'id_token',
  $openidc_cache_type           = undef,
  $openidc_cache_shm_max        = undef,
  $openidc_cache_shm_entry_size = undef,
  $openidc_cache_dir            = undef,
  $openidc_cache_clean_interval = undef,
  $memcached_servers            = undef,
  $redis_server                 = undef,
  $redis_password               = undef,
  $admin_port                   = false,
  $main_port                    = true,
  $template_order               = 331,
  $package_ensure               = present,
  $keystone_public_url          = undef,
  $keystone_admin_url           = undef,

  # DEPRECATED
  $module_plugin                = undef,
) {

  include ::apache
  include ::keystone::deps
  include ::keystone::params

  $_keystone_public_url = pick($keystone_public_url, $::keystone::public_endpoint)
  $_keystone_admin_url = pick($keystone_admin_url, $::keystone::admin_endpoint)
  $_memcached_servers = join(any2array($memcached_servers), ' ')

  # Note: if puppet-apache modify these values, this needs to be updated
  if $template_order <= 330 or $template_order >= 999 {
    fail('The template order should be greater than 330 and less than 999.')
  }

  validate_legacy(Boolean, 'validate_bool', $admin_port)
  validate_legacy(Boolean, 'validate_bool', $main_port)

  if( !$admin_port and !$main_port){
    fail('No VirtualHost port to configure, please choose at least one.')
  }

  keystone_config {
    'openid/remote_id_attribute': value => 'HTTP_OIDC_ISS';
  }

  ensure_packages([$::keystone::params::openidc_package_name], {
    ensure => $package_ensure,
    tag    => 'keystone-support-package',
  })

  if $admin_port and $_keystone_admin_url {
    keystone::federation::openidc_httpd_configuration{ 'admin':
      keystone_endpoint => $_keystone_admin_url,
    }
  }

  if $main_port and $_keystone_public_url {
    keystone::federation::openidc_httpd_configuration{ 'main':
      keystone_endpoint => $_keystone_public_url,
    }
  }
}
