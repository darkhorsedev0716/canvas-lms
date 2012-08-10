require File.expand_path(File.dirname(__FILE__) + '/common')

describe "Account Authorization Configs" do
  it_should_behave_like "in-process server selenium tests"

  it "should show the error message generated by the server" do
    site_admin_logged_in
    Account.default.account_authorization_configs.create!({
      :auth_host => "blah.blah",
      :auth_over_tls => false,
      :auth_port => "123",
      :auth_type => "ldap",
    })
    get "/accounts/#{Account.default.id}/account_authorization_configs"
    f(".test_ldap_link").click
    wait_for_ajaximations
    f("#ldap_connection_help .server_error").text.should == "Unknown host: blah.blah"
  end
end
