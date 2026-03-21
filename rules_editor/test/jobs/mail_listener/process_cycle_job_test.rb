# frozen_string_literal: true

require "test_helper"

module MailListener
  class ProcessCycleJobTest < ActiveJob::TestCase
    setup do
      @user = User.create!(email: "test@example.com")
      @auth = GmailAuthentication.create!(
        user: @user,
        email: "gmail@example.com",
        access_token: "tok",
        refresh_token: "ref",
        status: :active
      )
    end

    test "calls CycleProcessor for each active gmail_authentication" do
      processed = []

      CycleProcessor.stub(:new, ->(gmail_authentication:, **) {
        processed << gmail_authentication.email
        Minitest::Mock.new.tap { |m| m.expect(:process!, nil) }
      }) do
        ProcessCycleJob.new.perform
      end

      assert_includes processed, "gmail@example.com"
    end

    test "skips needs_reauth accounts" do
      @auth.update!(status: :needs_reauth)
      processed = []

      CycleProcessor.stub(:new, ->(**) { processed << true; Minitest::Mock.new.tap { |m| m.expect(:process!, nil) } }) do
        ProcessCycleJob.new.perform
      end

      assert_empty processed
    end

    test "continues processing remaining accounts when one raises" do
      second_auth = GmailAuthentication.create!(
        user: @user, email: "second@gmail.com",
        access_token: "tok", refresh_token: "ref", status: :active
      )
      processed = []
      call_count = 0

      CycleProcessor.stub(:new, ->(gmail_authentication:, **) {
        call_count += 1
        mock = Minitest::Mock.new
        if call_count == 1
          mock.expect(:process!, nil) { raise StandardError, "boom" }
        else
          mock.expect(:process!, nil)
          processed << gmail_authentication.email
        end
        mock
      }) do
        ProcessCycleJob.new.perform
      end

      assert_equal 1, processed.size
    end
  end
end
