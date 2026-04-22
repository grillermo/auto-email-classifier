puts "[save_as_markdown] calling it"

require "base64"
require "open3"
require "fileutils"
require "tempfile"
require "cgi"

extract_html = nil
extract_html = lambda do |payload|
  next "" if payload.nil?

  if payload.mime_type == "text/html" && payload.body&.data
    data = Base64.urlsafe_decode64(payload.body.data)
    next data.encode("UTF-8", invalid: :replace, undef: :replace)
  end

  Array(payload.parts).each do |part|
    result = extract_html.call(part)
    next if result.empty?
    break result
  end || ""
end

collect_attachments = nil
collect_attachments = lambda do |payload|
  found = []
  return found if payload.nil?

  Array(payload.parts).each do |part|
    if part.filename.present? && part.body&.attachment_id
      found << { filename: part.filename, attachment_id: part.body.attachment_id }
    end
    found.concat(collect_attachments.call(part))
  end

  found
end

sanitize = ->(str) { str.to_s.gsub(/[<>:"\/\\|?*]/, "_").squeeze("_").strip }

raw        = message[:raw]
from       = message[:from].to_s
subject    = message[:subject].to_s
date       = message[:date].to_s
message_id = message[:id].to_s

puts "[save_as_markdown] Processing message id=#{message_id} from=#{from.inspect} subject=#{subject.inspect}"

sender_folder = sanitize.call(from).first(100)
safe_subject  = sanitize.call(subject).first(100)
safe_date     = date.gsub(/[^a-zA-Z0-9\-]/, "_").squeeze("_").strip

output_dir = Rails.root.join("action-scripts", sender_folder)
FileUtils.mkdir_p(output_dir)
puts "[save_as_markdown] Output directory: #{output_dir}"

html_body = extract_html.call(raw.payload)

if html_body.empty?
  puts "[save_as_markdown] No HTML part found, converting plain text body"
  plain = message[:body].to_s
  html_body = "<html><body><pre>#{CGI.escapeHTML(plain)}</pre></body></html>"
else
  puts "[save_as_markdown] Extracted HTML body (#{html_body.bytesize} bytes)"
end

attachments = collect_attachments.call(raw.payload)
puts "[save_as_markdown] Found #{attachments.size} attachment(s)"

gmail_service     = Gmail::Client.new.send(:service)
saved_attachments = []

attachments.each do |att|
  puts "[save_as_markdown] Fetching attachment: #{att[:filename]}"
  att_response = gmail_service.get_user_message_attachment("me", message_id, att[:attachment_id])
  dest_path    = output_dir.join(att[:filename])
  File.binwrite(dest_path, Base64.urlsafe_decode64(att_response.data))
  puts "[save_as_markdown] Saved attachment: #{dest_path}"
  saved_attachments << att[:filename]
end

unless saved_attachments.empty?
  links = saved_attachments.map { |f| %(<li><a href="#{CGI.escapeHTML(f)}">#{CGI.escapeHTML(f)}</a></li>) }.join
  html_body += "<hr><p><strong>Attachments:</strong></p><ul>#{links}</ul>"
  puts "[save_as_markdown] Appended attachment links to HTML"
end

html_tmp = Tempfile.new(["email", ".html"])
html_tmp.write(html_body)
html_tmp.close
puts "[save_as_markdown] Wrote temp HTML: #{html_tmp.path}"

md_path = output_dir.join("#{safe_subject}__#{safe_date}.md")
puts "[save_as_markdown] Running pandoc -> #{md_path}"

_out, stderr, status = Open3.capture3("pandoc", "-f", "html", "-t", "gfm", "-o", md_path.to_s, html_tmp.path)
html_tmp.unlink

raise "pandoc failed: #{stderr}" unless status.success?

puts "[save_as_markdown] Done: #{md_path}"
