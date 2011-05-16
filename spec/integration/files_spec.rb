require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe FilesController do
  context "should support Submission as a context" do
    before(:each) do
      course_with_teacher_logged_in(:active_all => true)
      @me = @user
      submission_model
      @submission.attachment = attachment_model(:uploaded_data => stub_png_data, :content_type => 'image/png')
      @submission.save!
    end

    it "with safefiles" do
      HostUrl.stub!(:file_host).and_return('files-test.host')
      get "http://test.host/files/#{@submission.attachment.id}/download", :inline => '1', :verifier => @submission.attachment.uuid
      response.should be_redirect
      uri = URI.parse response['Location']
      qs = Rack::Utils.parse_nested_query(uri.query)
      uri.host.should == 'files-test.host'
      uri.path.should == "/files/#{@submission.attachment.id}/download"
      @me.valid_access_verifier?(qs['ts'], qs['sf_verifier']).should be_true
      qs['verifier'].should == @submission.attachment.uuid

      get response['Location']
      response.should be_success
      response.content_type.should == 'image/png'
    end

    it "without safefiles" do
      HostUrl.stub!(:file_host).and_return('test.host')
      get "http://test.host/files/#{@submission.attachment.id}/download", :inline => '1', :verifier => @submission.attachment.uuid
      response.should be_success
      response.content_type.should == 'image/png'
    end
  end
end
