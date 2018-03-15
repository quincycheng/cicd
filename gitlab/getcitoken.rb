#!/usr/bin/env ruby

require 'mechanize'
require 'logger'
require 'yaml'

gitlab_ci_url = ENV['GITLAB_EXT_URL']

agent = Mechanize.new
agent.log = Logger.new "getcitoken.log"

login_page = agent.get gitlab_ci_url+"/users/sign_in"
login_form = login_page.form

email_field = login_form.field_with(name: "user[login]")
password_field = login_form.field_with(name: "user[password]")

email_field.value = 'root'
password_field.value = ENV['GITLAB_ROOT_PASSWORD']

home_page = login_form.submit
runner_page = agent.get agent.get gitlab_ci_url+"/admin/runners"

# Return Token
puts runner_page.at('code#registration_token').text

