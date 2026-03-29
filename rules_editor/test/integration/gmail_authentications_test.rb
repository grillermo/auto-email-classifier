require "test_helper"

class GmailAuthenticationsTest < ActionDispatch::IntegrationTest
  FakeCredentials = Struct.new(:access_token, :refresh_token, :expires_at)
  FakeProfile = Struct.new(:email_address)

  setup do
    @user = User.create!(email: "test@example.com")
  end

  test "signed in users can open the connect gmail page" do
    sign_in(@user)

    get new_gmail_authentication_path

    assert_response :success
    assert_select "a[href=?]", gmail_oauth_authorize_path, text: "Continue with Google"
    assert_select "a[href=?]", root_path, text: "Skip for now"
  end

  test "header shows add gmail auth link for signed in users" do
    sign_in(@user)

    get root_path

    assert_response :success
    assert_select "a[href=?]", new_gmail_authentication_path, text: "Add Gmail Auth"
  end

  test "callback creates a new gmail authentication" do
    sign_in(@user)
    credentials = FakeCredentials.new("new-access", "new-refresh", 2.hours.from_now)
    authorizer = build_authorizer(credentials)
    gmail_service = build_gmail_service("gmail@example.com")

    Gmail::OauthCallbackController.stub_any_instance(:build_authorizer, authorizer) do
      stub_method(Google::Apis::GmailV1::GmailService, :new, gmail_service) do
        assert_difference("GmailAuthentication.count", 1) do
          get gmail_oauth_callback_path, params: { code: "auth-code" }
        end
      end
    end

    assert_redirected_to root_path
    auth = @user.gmail_authentications.find_by!(email: "gmail@example.com")
    assert_equal "new-access", auth.access_token
    assert_equal "new-refresh", auth.refresh_token
    assert auth.status_active?
  end

  test "callback re-authorizes an existing gmail authentication without creating a duplicate" do
    sign_in(@user)
    existing_auth = @user.gmail_authentications.create!(
      email: "gmail@example.com",
      access_token: "old-access",
      refresh_token: "old-refresh",
      status: :needs_reauth
    )

    credentials = FakeCredentials.new("fresh-access", nil, 2.hours.from_now)
    authorizer = build_authorizer(credentials)
    gmail_service = build_gmail_service("gmail@example.com")

    Gmail::OauthCallbackController.stub_any_instance(:build_authorizer, authorizer) do
      stub_method(Google::Apis::GmailV1::GmailService, :new, gmail_service) do
        assert_no_difference("GmailAuthentication.count") do
          get gmail_oauth_callback_path, params: { code: "auth-code" }
        end
      end
    end

    assert_redirected_to root_path
    existing_auth.reload
    assert_equal "fresh-access", existing_auth.access_token
    assert_equal "old-refresh", existing_auth.refresh_token
    assert existing_auth.status_active?
  end

  private

  def build_authorizer(credentials)
    Object.new.tap do |obj|
      obj.define_singleton_method(:get_and_store_credentials_from_code) do |**kwargs|
        raise "missing code" unless kwargs[:code] == "auth-code"

        credentials
      end
    end
  end

  def build_gmail_service(email)
    Object.new.tap do |obj|
      obj.define_singleton_method(:authorization=) { |_credentials| }
      obj.define_singleton_method(:get_user_profile) do |_user_id|
        FakeProfile.new(email)
      end
    end
  end
end
