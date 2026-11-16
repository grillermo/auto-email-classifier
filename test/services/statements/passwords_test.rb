# frozen_string_literal: true

require "test_helper"

class Statements::PasswordsTest < ActiveSupport::TestCase
  def with_passwords_file(content)
    Dir.mktmpdir do |dir|
      path = File.join(dir, "statement_passwords.rb")
      File.write(path, content)
      yield path
    end
  end

  test "returns the bank's password from the Ruby file" do
    with_passwords_file(%({ "banamex" => "abc123", "santander" => "CHANGE_ME" })) do |path|
      assert_equal "abc123", Statements::Passwords.for("banamex", path: path)
    end
  end

  test "treats the placeholder, a missing bank and a missing file as unset" do
    with_passwords_file(%({ "banamex" => "abc123", "santander" => "CHANGE_ME" })) do |path|
      assert_nil Statements::Passwords.for("santander", path: path)
      assert_nil Statements::Passwords.for("didi", path: path)
    end
    assert_nil Statements::Passwords.for("banamex", path: "/nonexistent/statement_passwords.rb")
  end

  test "the example file parses and holds only placeholders" do
    example = Rails.root.join("config/statement_passwords.example.rb")

    assert_nil Statements::Passwords.for("banamex", path: example)
    assert_nil Statements::Passwords.for("santander", path: example)
  end
end
