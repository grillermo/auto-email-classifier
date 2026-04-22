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
      fake_processor = ->(gmail_authentication:, **) {
        processed << gmail_authentication.email
        Object.new.tap { |obj| obj.define_singleton_method(:process!) {} }
      }

      stub_method(CycleProcessor, :new, fake_processor) do
        ProcessCycleJob.new.perform
      end

      assert_includes processed, "gmail@example.com"
    end

    test "skips needs_reauth accounts" do
      @auth.update!(status: :needs_reauth)
      processed = []
      fake_processor = ->(**) {
        processed << true
        Object.new.tap { |obj| obj.define_singleton_method(:process!) {} }
      }

      stub_method(CycleProcessor, :new, fake_processor) do
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

      fake_processor = ->(gmail_authentication:, **) {
        call_count += 1
        if call_count == 1
          Object.new.tap { |obj| obj.define_singleton_method(:process!) { raise StandardError, "boom" } }
        else
          processed << gmail_authentication.email
          Object.new.tap { |obj| obj.define_singleton_method(:process!) {} }
        end
      }

      stub_method(CycleProcessor, :new, fake_processor) do
        ProcessCycleJob.new.perform
      end

      assert_equal 1, processed.size
    end
  end
end
