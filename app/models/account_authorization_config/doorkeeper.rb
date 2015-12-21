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
  plugin_settings :client_id, :setting_domain_oauth, :setting_logout_url, :setting_oauth_site, :setting_token_url, :setting_authorize_url, :setting_profile_url, :setting_user_id_owner_accounts, :setting_default_pass, client_secret: :client_secret_dec

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
    setting_logout_url.sub('{canvas_login_url}', URI.escape(controller.login_url))
  end

  def unique_id(http_connect)
    puts "@@@@@@@@@@@@@@@@@@@ #{client_id.inspect}=======user_id_owner_accounts: #{setting_user_id_owner_accounts.inspect}"
    res = http_connect.get("/oauth/token/info", {"Authorization"=> http_connect.options[:header_format].sub("%s", http_connect.token)})
    resource_id = JSON.parse(res.response.body)["resource_owner_id"].to_s
    resource_id = resource_id.to_s
    resource_id = "hsf#{resource_id}"

    # uservice = UserService.where(service_user_id: resource_id, service: "doorkeeper").first
    uservice = self.pseudonyms.where(unique_id: resource_id, workflow_state: 'active')
    unless uservice.present?
      uservice = create_user_from_hsf(resource_id, http_connect)
    else
      uservice.first.update_attribute(:account_id, setting_user_id_owner_accounts)
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
            password: setting_default_pass,
            sis_user_id: "",
            send_confirmation: false,
            force_self_registration: false,
            authentication_provider_id: self.id
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
    res = create_user(data)
    puts "%%%%%%%%%%%%%%%%%%%%%%%% params post: #{data.inspect} res post: #{res.inspect}"
    if res.is_a?(Hash) # errors
      raise "Invalid user information: #{res.inspect}"
    else
      user = res
      # assign authentication for the new user
      user_service = UserService.register(
          :service => "doorkeeper",
          :token => http_connect.token,
          :user => user,
          :service_domain => setting_domain_oauth,
          :service_user_id => resource_id,
          :service_user_name => data[:pseudonym][:unique_id],
          :service_user_url => setting_profile_url.sub("{user_id}", resource_id)
      )

      user.pseudonym.update_attribute(:authentication_provider_id, self.id)
      user.pseudonym.update_attribute(:account_id, setting_user_id_owner_accounts)
      user_service
    end
  end

  def client_options
    {
      site: setting_oauth_site,
      authorize_url: setting_authorize_url,
      token_url: setting_token_url
    }
  end

  def authorize_options
    { scope: scope }
  end

  def scope
    'public'.freeze
  end

  # ======== methods copied from users controller to create a new user
  def create_user(params)
    @domain_root_account = LoadAccount.default_domain_root_account
    @current_user = User.find(setting_user_id_owner_accounts)
    @context = @domain_root_account.root_account
    session = {}

    # run_login_hooks
    # Look for an incomplete registration with this pseudonym

    sis_user_id = nil
    params[:pseudonym] ||= {}

    # if @context.grants_right?(@current_user, session, :manage_sis)
    sis_user_id = params[:pseudonym].delete(:sis_user_id)
    # end

    @pseudonym = nil
    @user = nil
    if sis_user_id && value_to_boolean(params[:enable_sis_reactivation])
      @pseudonym = @context.pseudonyms.where(:sis_user_id => sis_user_id, :workflow_state => 'deleted').first
      if @pseudonym
        @pseudonym.workflow_state = 'active'
        @pseudonym.save!
        @user = @pseudonym.user
        @user.workflow_state = 'registered'
        @user.update_account_associations
      end
    end

    if @pseudonym.nil?
      @pseudonym = @context.pseudonyms.active.by_unique_id(params[:pseudonym][:unique_id]).first
      # Setting it to nil will cause us to try and create a new one, and give user the login already exists error
      @pseudonym = nil if @pseudonym && !['creation_pending', 'pending_approval'].include?(@pseudonym.user.workflow_state)
    end

    @user ||= @pseudonym && @pseudonym.user
    @user ||= User.new

    force_validations = value_to_boolean(params[:force_validations])
    manage_user_logins = @context.grants_right?(@current_user, session, :manage_user_logins)
    self_enrollment = params[:self_enrollment].present?
    allow_non_email_pseudonyms = !force_validations && manage_user_logins || self_enrollment && params[:pseudonym_type] == 'username'
    require_password = self_enrollment && allow_non_email_pseudonyms
    allow_password = require_password || manage_user_logins

    notify_policy = Users::CreationNotifyPolicy.new(manage_user_logins, params[:pseudonym])

    includes = %w{locale}

    cc_params = params[:communication_channel]

    if cc_params
      cc_type = cc_params[:type] || CommunicationChannel::TYPE_EMAIL
      cc_addr = cc_params[:address] || params[:pseudonym][:unique_id]

      can_manage_students = [Account.site_admin, @context].any? do |role|
        role.grants_right?(@current_user, :manage_students)
      end

      if can_manage_students
        skip_confirmation = value_to_boolean(cc_params[:skip_confirmation])
      end

      if can_manage_students && cc_type == CommunicationChannel::TYPE_EMAIL
        includes << 'confirmation_url' if value_to_boolean(cc_params[:confirmation_url])
      end

    else
      cc_type = CommunicationChannel::TYPE_EMAIL
      cc_addr = params[:pseudonym].delete(:path) || params[:pseudonym][:unique_id]
    end

    if params[:user]
      if self_enrollment && params[:user][:self_enrollment_code]
        params[:user][:self_enrollment_code].strip!
      else
        params[:user].delete(:self_enrollment_code)
      end
      if params[:user][:birthdate].present? && params[:user][:birthdate] !~ Api::ISO8601_REGEX &&
          params[:user][:birthdate] !~ Api::DATE_REGEX
        return {:errors => {:birthdate => t(:birthdate_invalid, 'Invalid date or invalid datetime for birthdate')}}
      end

      @user.attributes = params[:user]
      accepted_terms = params[:user].delete(:terms_of_use)
      @user.accept_terms if value_to_boolean(accepted_terms)
      includes << "terms_of_use" unless accepted_terms.nil?
    end
    @user.name ||= params[:pseudonym][:unique_id]
    skip_registration = value_to_boolean(params[:user].try(:[], :skip_registration))
    unless @user.registered?
      @user.workflow_state = if require_password || skip_registration
                               # no email confirmation required (self_enrollment_code and password
                               # validations will ensure everything is legit)
                               'registered'
                             elsif notify_policy.is_self_registration? && @user.registration_approval_required?
                               'pending_approval'
                             else
                               'pre_registered'
                             end
    end
    if force_validations || !manage_user_logins
      @user.require_acceptance_of_terms = @domain_root_account.terms_required?
      @user.require_presence_of_name = true
      @user.require_self_enrollment_code = self_enrollment
      @user.validation_root_account = @domain_root_account
    end

    @invalid_observee_creds = nil
    if @user.initial_enrollment_type == 'observer'
      if (observee_pseudonym = authenticate_observee)
        @observee = observee_pseudonym.user
      else
        @invalid_observee_creds = Pseudonym.new
        @invalid_observee_creds.errors.add('unique_id', 'bad_credentials')
      end
    end

    @pseudonym ||= @user.pseudonyms.build(:account => @context)
    @pseudonym.account.email_pseudonyms = !allow_non_email_pseudonyms
    @pseudonym.require_password = require_password
    # pre-populate the reverse association
    @pseudonym.user = @user
    # don't require password_confirmation on api calls
    params[:pseudonym][:password_confirmation] = params[:pseudonym][:password] if api_request?
    # don't allow password setting for new users that are not self-enrolling
    # in a course (they need to go the email route)
    unless allow_password
      params[:pseudonym].delete(:password)
      params[:pseudonym].delete(:password_confirmation)
    end
    if params[:pseudonym][:authentication_provider_id]
      @pseudonym.authentication_provider = @context.
          authentication_providers.active.
          find(params[:pseudonym][:authentication_provider_id])
    end
    @pseudonym.attributes = params[:pseudonym]
    @pseudonym.sis_user_id = sis_user_id

    @pseudonym.account = @context
    @pseudonym.workflow_state = 'active'
    @cc =
        @user.communication_channels.where(:path_type => cc_type).by_path(cc_addr).first ||
            @user.communication_channels.build(:path_type => cc_type, :path => cc_addr)
    @cc.user = @user
    @cc.workflow_state = skip_confirmation ? 'active' : 'unconfirmed' unless @cc.workflow_state == 'confirmed'

    if @user.valid? && @pseudonym.valid? && @invalid_observee_creds.nil?
      # saving the user takes care of the @pseudonym and @cc, so we can't call
      # save_without_session_maintenance directly. we don't want to auto-log-in
      # unless the user is registered/pre_registered (if the latter, he still
      # needs to confirm his email and set a password, otherwise he can't get
      # back in once his session expires)
      if !@current_user # automagically logged in
        PseudonymSession.new(@pseudonym).save unless @pseudonym.new_record?
      else
        @pseudonym.send(:skip_session_maintenance=, true)
      end
      @user.save!
      if @observee && !@user.user_observees.where(user_id: @observee).exists?
        @user.user_observees << @user.user_observees.create!{ |uo| uo.user_id = @observee.id }
      end

      if notify_policy.is_self_registration?
        registration_params = params.fetch(:user, {}).merge(remote_ip: request.remote_ip, cookies: cookies)
        @user.new_registration(registration_params)
      end
      return @user
    else
      errors = {
          :errors => {
              :user => @user.errors.as_json[:errors],
              :pseudonym => @pseudonym ? @pseudonym.errors.as_json[:errors] : {},
              :observee => @invalid_observee_creds ? @invalid_observee_creds.errors.as_json[:errors] : {}
          }
      }
      return errors
    end
  end

  def value_to_boolean(value)
    if value.is_a?(String) || value.is_a?(Symbol)
      return true if ["yes", "true", "on", "1"].include?(value.to_s.downcase)
      return false if ["no", "false", "off", "0"].include?(value.to_s.downcase)
    end
    return value if [true, false].include?(value)
    return value.to_i != 0
  end

  def api_request?
    true
  end

end
