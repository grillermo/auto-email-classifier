# frozen_string_literal: true

module Rules
  class ForwardedContentParser
    FROM_REGEX = /^(?:From|De):\s*(.+)$/i
    SUBJECT_REGEX = /^(?:Subject|Asunto):\s*(.+)$/i

    def parse(body_text)
      from_line = nil
      subject_line = nil

      body_text.to_s.each_line do |line|
        line = line.strip
        from_line ||= line[FROM_REGEX, 1]
        subject_line ||= line[SUBJECT_REGEX, 1]

        break if from_line && subject_line
      end

      return nil if from_line.to_s.strip.empty? || subject_line.to_s.strip.empty?

      {
        sender: normalize_sender(from_line),
        subject: subject_line.strip
      }
    end

    private

    def normalize_sender(from_line)
      from_line = from_line.strip
      matched = from_line.match(/<([^>]+)>/)
      return matched[1].strip if matched

      email = from_line.match(/[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}/i)
      email ? email[0].strip : from_line
    end
  end
end
