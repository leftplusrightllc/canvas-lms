#
# Copyright (C) 2015 Instructure, Inc.
#
# This file is part of Canvas.
#
# Canvas is free software: you can redistribute it and/or modify it under
# the terms of the GNU Affero General Public License as published by the Free
# Software Foundation, version 3 of the License.
#
# Canvas is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
# details.
#
# You should have received a copy of the GNU Affero General Public License along
# with this program. If not, see <http://www.gnu.org/licenses/>.
#

class AccountAuthorizationConfig::Doorkeeper < AccountAuthorizationConfig::Oauth2
  include AccountAuthorizationConfig::PluginSettings
  self.plugin = :doorkeeper
  plugin_settings :client_id, client_secret: :client_secret_dec

  def self.sti_name
    'doorkeeper'.freeze
  end

  def self.recognized_params
    [ :login_attribute ].freeze
  end

  def self.login_attributes
    ['id'.freeze].freeze
  end
  validates :login_attribute, inclusion: login_attributes

  def login_attribute
    super || 'id'.freeze
  end

  def login_button?
    true
  end

  def user_logout_redirect(controller, current_u)
    DoorkeeperConfig[:logout_url].sub('{canvas_login_url}', URI.escape(controller.login_url))
  end

  def unique_id(http_connect)
    res = http_connect.get("/oauth/token/info", {"Authorization"=> http_connect.options[:header_format].sub("%s", http_connect.token)})
    resource_id = JSON.parse(res.response.body)["resource_owner_id"].to_s
    resource_id = resource_id.to_s
    resource_id = "t#{resource_id}"

    uservice = UserService.where(service_user_id: resource_id, service: "doorkeeper").first
    unless uservice.present?
      uservice = create_user_from_hsf(resource_id, http_connect)
    end

    resource_id
  end

  protected

  # create another user with hsf information
  def create_user_from_hsf(resource_id, http_connect)
    
    require 'net/http'
    require 'net/https'

    # get profile info for resource_id
    hsf_res = http_connect.get("/api/v1/me", {"Authorization"=> http_connect.options[:header_format].sub("%s", http_connect.token)})
    user_hsf = JSON.parse(hsf_res.response.body)
    puts "*************************user: #{user_hsf.inspect}"

    hsf_res2 = http_connect.get("/api/v2/users/#{user_hsf["uuid"]}/profiles", {"Authorization"=> http_connect.options[:header_format].sub("%s", http_connect.token)})
    profile_hsf = JSON.parse(hsf_res2.response.body)["profile"]
    puts "****************************profile: #{profile_hsf.inspect}"

    # Create te http object
    http = Net::HTTP.new('localhost', 3000)
    http.read_timeout = 500
    http.use_ssl = false

    data = {
        user: {
            name: user_hsf["full_name"],
            short_name: user_hsf["profile"]["first_name"],
            sortable_name: user_hsf["profile"]["first_name"],
            time_zone: profile_hsf["time_zone"],
            #locale: "BO",
            birthdate: profile_hsf["birthday"],
            terms_of_use: true,
            skip_registration: true
        },
        pseudonym:{
            unique_id: resource_id,
            password: DoorkeeperConfig[:default_pass],
            sis_user_id: "",
            send_confirmation: false,
            force_self_registration: false,
            authentication_provider_id: 3
        },
        communication_channel:{
            type: "email",
            address: user_hsf["email"],
            confirmation_url: false,
            skip_confirmation: true,
        },
        force_validations: false,
        enable_sis_reactivation: false
    }
    headers = {
        'Authorization' => "Bearer #{DoorkeeperConfig[:canvas_token]}", # token generated in canvas lms
        'Content-Type' => 'application/json'
    }

    account = Account.find(DoorkeeperConfig[:user_id_owner_accounts]) # account creator
    res = http.post("/api/v1/accounts/#{account.id}/users", data.to_json, headers)

    # create new user using the API of CANVAS
    res = JSON.parse(res.body)
    user = User.find(res["id"])


    # assign authentication for the new user
    user_service = UserService.register(
        :service => "doorkeeper",
        :token => http_connect.token,
        :user => user,
        :service_domain => DoorkeeperConfig[:domain],
        :service_user_id => resource_id,
        :service_user_name => data[:pseudonym][:unique_id],
        :service_user_url => DoorkeeperConfig[:profile_url].sub("{user_id}", resource_id)
    )
    
    authentication_provider_id = account.authentication_providers.where(auth_type: "doorkeeper").first.id # authentication configured by this account creator 
    user.pseudonym.update_attribute(:authentication_provider_id, authentication_provider_id)
    user_service
  end
  
  def client_options
    {
      site: DoorkeeperConfig[:site],
      authorize_url: DoorkeeperConfig[:authorize_url],
      token_url: DoorkeeperConfig[:token_url]
    }
  end

  def authorize_options
    { scope: scope }
  end

  def scope
    'public'.freeze
  end

end
