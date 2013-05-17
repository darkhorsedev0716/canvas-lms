#
# Copyright (C) 2011 - 2012 Instructure, Inc.
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

describe ContentMigrationsController, :type => :integration do
  before do
    course_with_teacher_logged_in(:active_all => true, :user => user_with_pseudonym)
    @migration_url = "/api/v1/courses/#{@course.id}/content_migrations"
    @params = { :controller => 'content_migrations', :format => 'json', :course_id => @course.id.to_param}

    @migration = @course.content_migrations.create
    @migration.migration_type = 'common_cartridge_importer'
    @migration.context = @course
    @migration.user = @user
    @migration.started_at = 1.week.ago
    @migration.finished_at = 1.day.ago
    @migration.save!
  end

  describe 'index' do
    before do
      @params = @params.merge( :action => 'index')
    end

    it "should return list" do
      json = api_call(:get, @migration_url, @params)
      json.length.should == 1
      json.first['id'].should == @migration.id
    end

    it "should paginate" do
      migration = @course.content_migrations.create!
      json = api_call(:get, @migration_url + "?per_page=1", @params.merge({:per_page=>'1'}))
      json.length.should == 1
      json.first['id'].should == migration.id
      json = api_call(:get, @migration_url + "?per_page=1&page=2", @params.merge({:per_page => '1', :page => '2'}))
      json.length.should == 1
      json.first['id'].should == @migration.id
    end

    it "should 401" do
      course_with_student_logged_in(:course => @course, :active_all => true)
      api_call(:get, @migration_url, @params, {}, {}, :expected_status => 401)
    end
  end

  describe 'show' do
    before do
      @migration_url = @migration_url + "/#{@migration.id}"
      @params = @params.merge( :action => 'show', :id => @migration.id.to_param )
    end

    it "should return migration" do
      @migration.attachment = Attachment.create!(:context => @migration, :filename => "test.txt", :uploaded_data => StringIO.new("test file"))
      @migration.save!
      progress = Progress.create!(:tag => "content_migration", :context => @migration)
      json = api_call(:get, @migration_url, @params)

      json['id'].should == @migration.id
      json['migration_type'].should == @migration.migration_type
      json['finished_at'].should_not be_nil
      json['started_at'].should_not be_nil
      json['user_id'].should == @user.id
      json["workflow_state"].should == "pre_processing"
      json["migration_issues_url"].should == "http://www.example.com/api/v1/courses/#{@course.id}/content_migrations/#{@migration.id}/migration_issues"
      json["migration_issues_count"].should == 0
      json["attachment"]["url"].should =~ %r{/files/#{@migration.attachment.id}/download}
      json['progress_url'].should == "http://www.example.com/api/v1/progress/#{progress.id}"
      json['migration_type_title'].should == 'Common Cartridge Importer'
    end

    it "should return waiting_for_select when it's supposed to" do
      @migration.workflow_state = 'exported'
      @migration.migration_settings[:import_immediately] = false
      @migration.save!
      json = api_call(:get, @migration_url, @params)
      json['workflow_state'].should == 'waiting_for_select'
    end

    it "should 404" do
      api_call(:get, @migration_url + "000", @params.merge({:id => @migration.id.to_param + "000"}), {}, {}, :expected_status => 404)
    end

    it "should 401" do
      course_with_student_logged_in(:course => @course, :active_all => true)
      api_call(:get, @migration_url, @params, {}, {}, :expected_status => 401)
    end
  end

  describe 'create' do

    before do
      @params = {:controller => 'content_migrations', :format => 'json', :course_id => @course.id.to_param, :action => 'create'}
      @post_params = {:migration_type => 'common_cartridge_importer', :pre_attachment => {:name => "test.zip"}}
    end

    it "should error for unknown type" do
      json = api_call(:post, @migration_url, @params, {:migration_type => 'jerk'}, {}, :expected_status => 400)
      json.should == {"message"=>"Invalid migration_type"}
    end

    it "should queue a migration" do
      @post_params.delete :pre_attachment
      p = Canvas::Plugin.new("hi")
      p.stubs(:settings).returns('worker' => 'CCWorker')
      Canvas::Plugin.stubs(:find).returns(p)
      json = api_call(:post, @migration_url, @params, @post_params)
      json["workflow_state"].should == 'running'
      migration = ContentMigration.find json['id']
      migration.workflow_state.should == "exporting"
      migration.job_progress.workflow_state.should == 'queued'
    end

    it "should not queue a migration if do_not_run flag is set" do
      @post_params.delete :pre_attachment
      Canvas::Plugin.stubs(:find).returns(Canvas::Plugin.new("oi"))
      json = api_call(:post, @migration_url, @params, @post_params.merge(:do_not_run => true))
      json["workflow_state"].should == 'pre_processing'
      migration = ContentMigration.find json['id']
      migration.workflow_state.should == "created"
      migration.job_progress.should be_nil
    end

    context "migration file upload" do
      it "should set attachment pre-flight data" do
        json = api_call(:post, @migration_url, @params, @post_params)
        json['pre_attachment'].should_not be_nil
        json['pre_attachment']["upload_params"]["key"].end_with?("test.zip").should == true
      end

      it "should not queue migration with pre_attachent on create" do
        json = api_call(:post, @migration_url, @params, @post_params)
        json["workflow_state"].should == 'pre_processing'
        migration = ContentMigration.find json['id']
        migration.workflow_state.should == "pre_processing"
      end
      
      it "should error if upload file required but not provided" do
        @post_params.delete :pre_attachment
        json = api_call(:post, @migration_url, @params, @post_params, {}, :expected_status => 400)
        json.should == {"message"=>"File upload is required"}
      end

      it "should queue the migration when file finishes uploading" do
        local_storage!
        @attachment = Attachment.create!(:context => @migration, :filename => "test.zip", :uploaded_data => StringIO.new("test file"))
        @attachment.file_state = "deleted"
        @attachment.workflow_state = "unattached"
        @attachment.save
        @migration.attachment = @attachment
        @migration.save!
        @attachment.workflow_state = nil
        @content = Tempfile.new(["test", ".zip"])
        def @content.content_type
          "application/zip"
        end
        @content.write("test file")
        @content.rewind
        @attachment.uploaded_data = @content
        @attachment.save!
        api_call(:post, "/api/v1/files/#{@attachment.id}/create_success?uuid=#{@attachment.uuid}",
                        {:controller => "files", :action => "api_create_success", :format => "json", :id => @attachment.to_param, :uuid => @attachment.uuid})

        @migration.reload
        @migration.attachment.should_not be_nil
        @migration.workflow_state.should == "exporting"
        @migration.job_progress.workflow_state.should == 'queued'
      end

      it "should error if course quota exceeded" do
        @post_params.merge!(:pre_attachment => {:name => "test.zip", :size => 1.gigabyte})
        json = api_call(:post, @migration_url, @params, @post_params)
        json['pre_attachment'].should == {"message"=>"file size exceeds quota", "error" => true}
        json["workflow_state"].should == 'failed'
        migration = ContentMigration.find json['id']
        migration.workflow_state = 'pre_process_error'
      end
    end

  end

  describe 'update' do
    before do
      @migration_url = "/api/v1/courses/#{@course.id}/content_migrations/#{@migration.id}"
      @params = {:controller => 'content_migrations', :format => 'json', :course_id => @course.id.to_param, :action => 'update', :id => @migration.id.to_param}
      @post_params = {}
    end

    it "should queue a migration" do
      json = api_call(:put, @migration_url, @params, @post_params)
      json["workflow_state"].should == 'running'
      @migration.reload
      @migration.workflow_state.should == "exporting"
      @migration.job_progress.workflow_state.should == 'queued'
    end

    it "should not queue a migration if do_not_run flag is set" do
      json = api_call(:put, @migration_url, @params, @post_params.merge(:do_not_run => true))
      json["workflow_state"].should == 'pre_processing'
      migration = ContentMigration.find json['id']
      migration.workflow_state.should == "created"
      migration.job_progress.should be_nil
    end

    it "should not change migration_type" do
      json = api_call(:put, @migration_url, @params, @post_params.merge(:migration_type => "oioioi"))
      json['migration_type'].should == 'common_cartridge_importer'
    end

    it "should reset progress after queue" do
      p = @migration.reset_job_progress
      p.completion = 100
      p.workflow_state = 'completed'
      p.save!
      api_call(:put, @migration_url, @params, @post_params)
      p.reload
      p.completion.should == 0
      p.workflow_state.should == 'queued'
    end
  end



end
