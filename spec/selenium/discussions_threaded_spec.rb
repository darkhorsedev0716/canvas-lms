require File.expand_path(File.dirname(__FILE__) + '/helpers/discussions_common')

describe "threaded discussions" do
  it_should_behave_like "discussions selenium tests"

  before (:each) do
    @topic_title = 'threaded discussion topic'
    course_with_teacher_logged_in
    @topic = create_discussion(@topic_title, 'threaded')
    @student = student_in_course.user
  end

  it "should create a threaded discussion" do
    get "/courses/#{@course.id}/discussion_topics/#{@topic.id}"
    wait_for_ajax_requests

    f('.discussion-title').text.should == @topic_title
  end

  it "should reply to the threaded discussion" do
    entry_text = 'new entry'
    get "/courses/#{@course.id}/discussion_topics/#{@topic.id}"
    wait_for_ajax_requests

    add_reply(entry_text)
    last_entry = DiscussionEntry.last
    get_all_replies.count.should == 1
    @last_entry.find_element(:css, '.message').text.should == entry_text
    last_entry.depth.should == 1
  end

  it "should allow replies more than 2 levels deep" do
    reply_depth = 10
    reply_depth.times { |i| @topic.discussion_entries.create!(:user => @student, :message => "new threaded reply #{i} from student", :parent_entry => DiscussionEntry.last) }
    get "/courses/#{@course.id}/discussion_topics/#{@topic.id}"
    wait_for_ajax_requests
    DiscussionEntry.last.depth.should == reply_depth
  end

  it "should allow edits to entries with replies" do
    edit_text = 'edit message '
    entry       = @topic.discussion_entries.create!(:user => @student, :message => 'new threaded reply from student')
    child_entry = @topic.discussion_entries.create!(:user => @student, :message => 'new threaded child reply from student', :parent_entry => entry)
    get "/courses/#{@course.id}/discussion_topics/#{@topic.id}"
    wait_for_ajax_requests
    edit_entry(entry, edit_text)
    entry.reload.message.should match(edit_text)
  end

  it "should edit a reply" do
    pending("intermittently fails")
    edit_text = 'edit message '
    entry = @topic.discussion_entries.create!(:user => @student, :message => "new threaded reply from student")
    get "/courses/#{@course.id}/discussion_topics/#{@topic.id}"
    wait_for_ajax_requests

    edit_entry(entry, edit_text)
  end

  it "should delete a reply" do
    pending("intermittently fails")
    entry = @topic.discussion_entries.create!(:user => @student, :message => "new threaded reply from student")
    get "/courses/#{@course.id}/discussion_topics/#{@topic.id}"
    wait_for_ajax_requests

    delete_entry(entry)
  end
end
