require 'spec_helper'

describe 'keystone::federation::openidc' do

  let(:pre_condition) do
    <<-EOS
    class { 'keystone':
      admin_token => 'service_token',
      public_endpoint => 'http://os.example.com:5000',
      admin_endpoint => 'http://os.example.com:35357',
    }

    include keystone::wsgi::apache
    EOS
  end

  let :params do
    { :idp_name => 'myidp',
      :openidc_provider_metadata_url => 'https://accounts.google.com/.well-known/openid-configuration',
      :openidc_client_id => 'openid_client_id',
      :openidc_client_secret => 'openid_client_secret',
      :template_order => 331
     }
  end

  context 'with invalid params' do
    before do
      params.merge!(:admin_port => false,
                    :main_port  => false)
      it_raises 'a Puppet:Error', /No VirtualHost port to configure, please choose at least one./
    end

    before do
      params.merge!(:template_port => 330)
      it_raises 'a Puppet:Error', /The template order should be greater than 330 and less than 999./
    end

    before do
      params.merge!(:template_port => 999)
      it_raises 'a Puppet:Error', /The template order should be greater than 330 and less than 999./
    end
  end

  on_supported_os({
  }).each do |os,facts|
    let (:facts) do
      facts.merge!(OSDefaults.get_facts({}))
    end

    let(:platform_parameters) do
      case facts[:osfamily]
      when 'Debian'
        {
          :openidc_package_name => 'libapache2-mod-auth-openidc',
        }
      when 'RedHat'
        {
          :openidc_package_name => 'mod_auth_openidc',
        }
      end
    end

    context 'with only required parameters' do
      it 'should set remote_id_attribute in keystone' do
        is_expected.to contain_keystone_config('openid/remote_id_attribute').with_value('HTTP_OIDC_ISS')
      end

      it { is_expected.to contain_concat__fragment('configure_openidc_on_main').with({
        :target => "10-keystone_wsgi_main.conf",
        :order  => params[:template_order],
      })}

    end

    context 'with override default parameters' do
      before do
        params.merge!({
          :admin_port => true,
        })
      end

      it 'should set remote_id_attribute in keystone' do
        is_expected.to contain_keystone_config('openid/remote_id_attribute').with_value('HTTP_OIDC_ISS')
      end

      it { is_expected.to contain_concat__fragment('configure_openidc_on_main').with({
        :target => "10-keystone_wsgi_main.conf",
        :order  => params[:template_order],
      })}

      it { is_expected.to contain_concat__fragment('configure_openidc_on_admin').with({
        :target => "10-keystone_wsgi_admin.conf",
        :order  => params[:template_order],
      })}
    end

    it { is_expected.to contain_package(platform_parameters[:openidc_package_name]) }
  end
end
