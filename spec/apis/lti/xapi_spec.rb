require File.expand_path(File.dirname(__FILE__) + '/../api_spec_helper')

# https://github.com/adlnet/xAPI-Spec/blob/master/xAPI.md

describe LtiApiController, type: :request do
  before :once do
    course_with_student(:active_all => true)
    @student = @user
    @course.enroll_teacher(user_with_pseudonym(:active_all => true))
    @tool = @course.context_external_tools.create!(:shared_secret => 'test_secret', :consumer_key => 'test_key', :name => 'my xapi test tool', :domain => 'example.com')
    assignment_model(:course => @course, :name => 'tool assignment', :submission_types => 'external_tool', :points_possible => 20, :grading_type => 'points')
    tag = @assignment.build_external_tool_tag(:url => "http://example.com/one")
    tag.content_type = 'ContextExternalTool'
    tag.save!
  end

  def make_call(opts = {})
    opts['path'] ||= "/api/lti/v1/tools/#{@tool.id}/xapi"
    opts['key'] ||= @tool.consumer_key
    opts['secret'] ||= @tool.shared_secret
    opts['content-type'] ||= 'application/json'
    consumer = OAuth::Consumer.new(opts['key'], opts['secret'], :site => "https://www.example.com", :signature_method => "HMAC-SHA1")
    req = consumer.create_signed_request(:post, opts['path'], nil, :scheme => 'header', :timestamp => opts['timestamp'], :nonce => opts['nonce'])
    req.body = JSON.generate(opts['body']) if opts['body']
    post "https://www.example.com#{req.path}",
      req.body,
      { "CONTENT_TYPE" => opts['content-type'], "HTTP_AUTHORIZATION" => req['Authorization'] }
  end

  def source_id
    @tool.shard.activate do
      payload = [@tool.id, @course.id, @assignment.id, @student.id].join('-')
      "#{payload}-#{Canvas::Security.hmac_sha1(payload, @tool.shard.settings[:encryption_key])}"
    end
  end

  it "should require a content-type of application/json" do
    make_call('content-type' => 'application/xml')
    assert_status(415)
  end

  it "should require the correct shared secret" do
    make_call('secret' => 'bad secret is bad')
    assert_status(401)
  end

  def xapi_body
    # https://github.com/adlnet/xAPI-Spec/blob/master/xAPI.md#AppendixA
    {
      id: "12345678-1234-5678-1234-567812345678",
      actor: {
        account: {
          homePage: "http://www.instructure.com/",
          name: source_id
        }
      },
      verb: {
        id: "http://adlnet.gov/expapi/verbs/interacted",
        display: {
          "en-US" => "interacted"
        }
      },
      object: {
        id: "http://example.com/"
      },
      result: {
        duration: "PT10M0S"
      }
    }
  end

  it "should increment activity time" do
    e = Enrollment.where(user_id: @student, course_id: @course).first
    previous_time = e.total_activity_time

    make_call('body' => xapi_body)
    expect(response).to be_success

    expect(e.reload.total_activity_time).to eq previous_time + 600
  end

  it "should create an asset user access" do
    accesses = AssetUserAccess.where(user_id: @student)
    previous_count = accesses.count

    make_call('body' => xapi_body)

    expect(accesses.reload.count).to eq previous_count + 1
  end

  describe "page view creation" do
    before { Setting.set 'enable_page_views', 'db' }

    it "should include url and interaction_seconds" do
      page_views = PageView.where(user_id: @student, context_id: @course, context_type: 'Course')
      previous_count = page_views.count
      body = xapi_body

      make_call('body' => body)

      expect(page_views.reload.count).to eq previous_count + 1

      page_view = page_views.last
      expect(page_view.url).to eq body[:object][:id]
      expect(page_view.interaction_seconds).to eq 600
    end

    after { Setting.set 'enable_page_views', 'false' }
  end
end
