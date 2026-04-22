# frozen_string_literal: true

module Rules
  class ActionScripts
    class << self
      def available_scripts
        return [] unless root.exist?

        root.glob("**/*").filter_map do |path|
          next unless path.file?

          path.relative_path_from(root).to_s
        end.sort
      end

      def path_for(script)
        script_path = script.to_s.strip
        return nil if script_path.empty?

        candidate = root.join(script_path).cleanpath
        return nil unless candidate.to_s.start_with?("#{root.to_s}/") || candidate == root
        return nil unless candidate.file?

        candidate
      end

      def root
        Rails.root.join("action-scripts")
      end
    end
  end
end
