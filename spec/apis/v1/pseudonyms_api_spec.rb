#
# Copyright (C) 2012 Instructure, Inc.
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

require File.expand_path(File.dirname(__FILE__) + '/../api_spec_helper')

describe PseudonymsController, :type => :integration do
  before do
    course_with_student(:active_all => true)
    account_admin_user
    @account = @user.account
  end
  describe "pseudonym listing" do
    before do
      @path = "/api/v1/accounts/#{@account.id}/logins"
      @path_options = { :controller => 'pseudonyms', :action => 'index', :format => 'json', :account_id => @account.id.to_param }
    end
    context "An authorized user with a valid query" do
      it "should return a list of pseudonyms" do
        json = api_call(:get, @path, @path_options, {
          :user => { :id => @student.id }
        })
        json.should == @student.pseudonyms.map do |p|
          {
            'account_id' => p.account_id,
            'id' => p.id,
            'sis_user_id' => p.sis_user_id,
            'unique_id' => p.unique_id,
            'user_id' => p.user_id
          }
        end
      end
      it "should return multiple pseudonyms if they exist" do
        %w{ one@example.com two@example.com }.each { |id| @student.pseudonyms.create(:unique_id => id) }
        json = api_call(:get, @path, @path_options, {
          :user => { :id => @student.id }
        })
        json.count.should eql 2
      end
      it "should paginate results" do
        %w{ one@example.com two@example.com }.each { |id| @student.pseudonyms.create(:unique_id => id) }
        json = api_call(:get, "#{@path}?per_page=1", @path_options.merge({ :per_page => '1' }), {
          :user => { :id => @student.id }
        })
        json.count.should eql 1
        headers = response.headers['Link'].split(',')
        headers[0].should match /page=2&per_page=1/ # next page
        headers[1].should match /page=1&per_page=1/ # first page
        headers[2].should match /page=2&per_page=1/ # last page
      end
    end
    context "An authorized user with an empty query" do
      it "should return an empty array" do
        json = api_call(:get, @path, @path_options, {
          :user => { :id => @student.id }
        })
        json.should be_empty
      end
    end
    context "An unauthorized user" do
      it "should return 401 unauthorized" do
        @user = user_with_pseudonym
        raw_api_call(:get, @path, @path_options, {
          :user => { :id => @student.id }
        })
        response.code.should eql '401'
      end
    end
  end

  describe "pseudonym creation" do
    before do
      @path = "/api/v1/accounts/#{@account.id}/logins"
      @path_options = { :controller => 'pseudonyms', :action => 'create', :format => 'json', :account_id => @account.id.to_param }
    end

    context "an authorized user" do
      it "should create a new pseudonym" do
        json = api_call(:post, @path, @path_options, {
          :user => { :id => @student.id },
          :login => {
            :password    => 'abc123',
            :sis_user_id => '12345',
            :unique_id   => 'test@example.com'
          }
        })
        json.should == {
          'account_id'  => @account.id,
          'id'          => json['id'],
          'sis_user_id' => '12345',
          'unique_id'   => 'test@example.com',
          'user_id'     => @student.id
        }
      end

      it "should return 400 if account_id is not a root account" do
        @subaccount = Account.create!(:parent_account => @account)
        @path = "/api/v1/accounts/#{@subaccount.id}/logins"
        @path_options = { :controller => 'pseudonyms', :action => 'create', :format => 'json', :account_id => @subaccount.id.to_param }
        raw_api_call(:post, @path, @path_options, {
          :user  => { :id => @student.id },
          :login => {
            :password => 'abc123',
            :sis_user_id => '12345',
            :unique_id => 'duplicate@example.com'
          }
        })
        response.code.should eql '400'
      end

      it "should return 400 on duplicate pseudonyms" do
        @student.pseudonyms.create(:unique_id => 'duplicate@example.com')
        raw_api_call(:post, @path, @path_options, {
          :user  => { :id => @student.id },
          :login => {
            :password => 'abc123',
            :sis_user_id => '12345',
            :unique_id => 'duplicate@example.com'
          }
        })
        response.code.should eql '400'
      end
    end

    context "an unauthorized user" do
      it "should return 401" do
        @user = @student
        raw_api_call(:post, @path, @path_options, {
          :user => { :id => @admin.id },
          :login => {
            :password => 'abc123',
            :sis_user_id => '12345',
            :unique_id => 'test@example.com'
          }
        })
        response.code.should eql '401'
      end
    end
  end
end
