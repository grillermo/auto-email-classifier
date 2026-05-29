# frozen_string_literal: true

require "test_helper"

class PagesHomeTest < ActionDispatch::IntegrationTest
  setup { host! "auto-email-classifier.chiq.me" }

  test "public root renders the landing page" do
    get root_path

    assert_response :success
    assert_select "h1", text: /Your inbox/
    assert_select "a[href=?]", privacy_path
    assert_select "a[href=?]", new_gmail_authentication_path, count: 0
  end

  test "signed in root keeps the app header available" do
    user = User.create!(email: "test@example.com")
    sign_in user

    get root_path

    assert_response :success
    assert_select "a[href=?]", new_gmail_authentication_path, text: "Add Gmail Auth"
    assert_includes response.body, "Open rules"
  end

  test "sign in header links to the privacy policy" do
    get new_user_session_path

    assert_response :success
    assert_select "header a[href=?]", privacy_path, text: "Privacy Policy"
    assert_select "header a[href=?]", terms_of_service_path, count: 0
  end
end
