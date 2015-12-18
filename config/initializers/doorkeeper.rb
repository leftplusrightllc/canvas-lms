Context_default_quota = 500.megabytes
DoorkeeperConfig = {
      site: "hsf.net",
      author: "hsf",
      author_url: "",
      version: "0.0.1"
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