# frozen_string_literal: true

require "json"
require "open3"

module Rules
  class ScriptRunner
    def run!(script:, message:)
      script_path = ActionScripts.path_for(script)
      raise ArgumentError, "script is invalid" unless script_path

      message_payload = message.to_h
      stdout, stderr, status = Open3.capture3(
        environment_for(script:, message: message_payload),
        script_path.to_s,
        stdin_data: JSON.generate(message_payload)
      )

      return if status.success?

      raise "script #{script} failed with exit #{status.exitstatus}: #{stderr.presence || stdout.presence || 'no output'}"
    end

    private

    def environment_for(script:, message:)
      {
        "RULE_ACTION_SCRIPT" => script.to_s,
        "RULE_MESSAGE_ID" => message["id"].to_s,
        "RULE_MESSAGE_JSON" => JSON.generate(message)
      }
    end
  end
end
