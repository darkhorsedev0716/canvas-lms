#
# Copyright (C) 2011 Instructure, Inc.
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

require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe PseudonymSessionsController do

  it "should re-render if no user" do
    post 'create'
    response.status.should == '400 Bad Request'
    response.should render_template('new')
  end

  it "should re-render if incorrect password" do
    user_with_pseudonym(:username => 'jt@instructure.com', :active_all => 1, :password => 'qwerty')
    post 'create', :pseudonym_session => { :unique_id => 'jt@instructure.com', :password => 'dvorak'}
    response.status.should == '400 Bad Request'
    response.should render_template('new')
  end

  it "password auth should work" do
    user_with_pseudonym(:username => 'jt@instructure.com', :active_all => 1, :password => 'qwerty')
    post 'create', :pseudonym_session => { :unique_id => 'jt@instructure.com', :password => 'qwerty'}
    response.should be_redirect
    response.should redirect_to(dashboard_url(:login_success => 1))
    assigns[:user].should == @user
    assigns[:pseudonym].should == @pseudonym
    assigns[:pseudonym_session].should_not be_nil
  end

  context "saml" do
    it "should scope logins to the correct domain root account" do
      Setting.set_config("saml", {})
      unique_id = 'foo@example.com'

      account1 = account_with_saml
      user1 = user_with_pseudonym({:active_all => true, :username => unique_id})
      @pseudonym.account = account1
      @pseudonym.save!

      account2 = account_with_saml
      user2 = user_with_pseudonym({:active_all => true, :username => unique_id})
      @pseudonym.account = account2
      @pseudonym.save!

      controller.stubs(:saml_response).returns(
        stub('response', :is_valid? => true, :success_status? => true, :name_id => unique_id, :name_qualifier => nil, :session_index => nil)
      )

      controller.request.env['canvas.domain_root_account'] = account1
      get 'saml_consume', :SAMLResponse => "foo"
      response.should redirect_to(dashboard_url(:login_success => 1))
      session[:name_id].should == unique_id
      Pseudonym.find(session[:pseudonym_credentials_id]).should == user1.pseudonyms.first

      (controller.instance_variables.grep(/@[^_]/) - ['@mock_proxy']).each{ |var| controller.send :remove_instance_variable, var }
      session.reset

      controller.stubs(:saml_response).returns(
        stub('response', :is_valid? => true, :success_status? => true, :name_id => unique_id, :name_qualifier => nil, :session_index => nil)
      )

      controller.request.env['canvas.domain_root_account'] = account2
      get 'saml_consume', :SAMLResponse => "bar"
      response.should redirect_to(dashboard_url(:login_success => 1))
      session[:name_id].should == unique_id
      Pseudonym.find(session[:pseudonym_credentials_id]).should == user2.pseudonyms.first

      Setting.set_config("saml", nil)
    end
  end

  context "cas" do
    def stubby(stub_response, use_mock = true)
      cas_client = use_mock ? stub_everything(:cas_client) : controller.cas_client
      cas_client.instance_variable_set(:@stub_response, stub_response)
      def cas_client.validate_service_ticket(st)
        st.response = CASClient::ValidationResponse.new(@stub_response)
      end
      PseudonymSessionsController.any_instance.stubs(:cas_client).returns(cas_client) if use_mock
    end

    it "should scope logins to the correct domain root account" do
      unique_id = 'foo@example.com'

      account1 = account_with_cas
      user1 = user_with_pseudonym({:active_all => true, :username => unique_id})
      @pseudonym.account = account1
      @pseudonym.save!

      account2 = account_with_cas
      user2 = user_with_pseudonym({:active_all => true, :username => unique_id})
      @pseudonym.account = account2
      @pseudonym.save!

      stubby("yes\n#{unique_id}\n")

      controller.request.env['canvas.domain_root_account'] = account1
      get 'new', :ticket => 'ST-abcd'
      response.should redirect_to(dashboard_url(:login_success => 1))
      session[:cas_login].should == true
      Pseudonym.find(session[:pseudonym_credentials_id]).should == user1.pseudonyms.first

      (controller.instance_variables.grep(/@[^_]/) - ['@mock_proxy']).each{ |var| controller.send :remove_instance_variable, var }
      session.reset

      stubby("yes\n#{unique_id}\n")

      controller.request.env['canvas.domain_root_account'] = account2
      get 'new', :ticket => 'ST-efgh'
      response.should redirect_to(dashboard_url(:login_success => 1))
      session[:cas_login].should == true
      Pseudonym.find(session[:pseudonym_credentials_id]).should == user2.pseudonyms.first
    end
  end
end
