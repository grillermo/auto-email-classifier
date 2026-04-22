# frozen_string_literal: true

module Rules
  class ScriptRunner
    attr_reader :message

    def run!(script:, message:)
      script_path = ActionScripts.path_for(script)
      raise ArgumentError, "script is invalid #{script}" unless script_path

      @message = message.to_h
      instance_eval(File.read(script_path), script_path.to_s)
    end
  end
end
