Context_default_quota = 500.megabytes
DoorkeeperConfig = {
      site: 'http://my.lvh.me:8082'.freeze, # url of the doorkeeper site
      authorize_url: 'http://my.lvh.me:8082/oauth/authorize', # url of the doorkeeper site to authorize login
      token_url: 'http://my.lvh.me:8082/oauth/token', # # url of the doorkeeper for token
      profile_url: "http://my.lvh.me:8082/users/{user_id}/profile/", # url of the doorkeeper site where to see the user profile
      domain: "my.lvh.me:8082", # domain of the doorkeeper site
      canvas_token: 'dfuLZRtCFCRmpILT4mI7duX7Rtge6GaWIAEjqStFABWU7fBPZ7MiMZ2Inl5aNu6S', # developer token generated in canvas lms
      default_pass: "^&*^&*^&*^&*^&*^*^&*^&*^&*^&*^$%^#@^%&*", # default pass for new users created by doorkeeper
      user_id_owner_accounts: 1, # profile id who will be the owner of new users created by doorkeeper
      logout_url: "http://my.lvh.me:8082/en/users/sign_out?redirect_url={canvas_login_url}", # url redirected after logout
      author: "hsf",
      author_url: "",
      version: "0.0.1",
      my_oauth_applications_url: "https://owen.com:3000/oauth/applications" # url of the doorkeeper site where to create applications
    }

DoorkeeperConfig = {
      site: 'https://university.hsf.net'.freeze, # url of the doorkeeper site
      authorize_url: 'https://university.hsf.net/oauth/authorize', # url of the doorkeeper site to authorize login
      token_url: 'https://university.hsf.net/oauth/token', # # url of the doorkeeper for token
      profile_url: "https://university.hsf.net/users/{user_id}/profile/", # url of the doorkeeper site where to see the user profile
      domain: "university.hsf.net", # domain of the doorkeeper site
      canvas_token: 'W7o2NJfhNEIHWCa7t6KlgwCceD4W2cdn3CookZYh5kotBShbxoZ0Y0IoeVFknAP2', # developer token generated in canvas lms
      default_pass: "^&*^&*^&*^&*^&*^*^&*^&*^&*^&*^$%^#@^%&*", # default pass for new users created by doorkeeper
      user_id_owner_accounts: 1, # profile id who will be the owner of new users created by doorkeeper
      logout_url: "https://university.hsf.net/en/users/sign_out?redirect_url={canvas_login_url}", # url redirected after logout
      author: "hsf",
      author_url: "",
      version: "0.0.1",
      my_oauth_applications_url: "https://hsf.net/oauth/applications" # url of the doorkeeper site where to create applications
    }

# local: rvm use 2.2.2
# Installation:
# Install canvas lms
# Create the doorkeeper oauth application (client id, client secret) in http://mydomain/oauth/applications, your callback must be like this: http://<mydomain-canvas>/login/oauth2/callback
# Go to Canvas LMS as admin admin (primary user) -> plugins -> doorkeeper -> and enter your client id and client secret generated in doorkeeper app.
# Go to admin (primary user) -> authentication -> Select sidebar dropdown "doorkeeper" and save changes
# Go to admin panel  (primary user) -> profile -> generate token and put in canvas_token setting in this file
# Go to admin (primary user) -> authentication -> remove canvas login and leave only doorkeeper (rightbar dropdown), Also fill login url in SSO form
# Note: after your config, the login url always will be redirected to doorkeeper site, use: http://cavnasdomain.com/login/canvas to access as a canvas administrator