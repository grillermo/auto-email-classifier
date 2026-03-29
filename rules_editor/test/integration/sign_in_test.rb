require "test_helper"

class SignInTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "test@example.com")
    @user.create_ntfy_channel!(channel: "test-channel")
  end

  test "can view the sign in page" do
    get new_user_session_path
    assert_response :success
    assert_select "h2", "Sign in"
  end

  test "submitting email triggers the magic link logic" do
    Users::DeviseNotifier.class_eval do
      alias_method :original_deliver, :deliver_via_ntfy
      def deliver_via_ntfy(*args); end
    end

    begin
      post user_session_path, params: { user: { email: @user.email } }
    ensure
      Users::DeviseNotifier.class_eval do
        alias_method :deliver_via_ntfy, :original_deliver
      end
    end
    
    assert_response :success
    assert_select ".bg-secondary-container", /A magic link has been sent/
  end
end
