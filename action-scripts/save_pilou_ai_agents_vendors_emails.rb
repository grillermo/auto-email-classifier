require "base64"
require "open3"
require "fileutils"
require "tempfile"
require "cgi"

def decode_data(data)
  Base64.urlsafe_decode64(data)
rescue ArgumentError
  data.dup
end

def find_part(payload, mime_type)
  return nil if payload.nil?
  return payload if payload.mime_type == mime_type && payload.body&.data&.present?
  Array(payload.parts).each do |part|
    found = find_part(part, mime_type)
    return found if found
  end
  nil
end

def collect_attachments(payload)
  return [] if payload.nil?
  found = []
  Array(payload.parts).each do |part|
    if part.filename.present? && part.body&.attachment_id.present?
      found << { filename: part.filename, attachment_id: part.body.attachment_id }
    end
    found.concat(collect_attachments(part))
  end
  found
end

def sanitize(str)
  str.to_s.gsub(/[<>:"\/\\|?*]/, "_").squeeze("_").strip
end

raw        = message[:raw]
from       = message[:from].to_s
subject    = message[:subject].to_s
date       = message[:date].to_s
message_id = message[:id].to_s

puts "[save_as_markdown] id=#{message_id} from=#{from.inspect} subject=#{subject.inspect}"

sender_folder = sanitize(from).first(100)
safe_subject  = sanitize(subject).first(100)
safe_date     = date.gsub(/[^a-zA-Z0-9\-]/, "_").squeeze("_").strip

output_dir = '/Users/grillermo/google drive personal/documentos/notas/Proyectos/pilou/AI agent project/emails_proveedores'
FileUtils.mkdir_p(output_dir)
puts "[save_as_markdown] output_dir=#{output_dir}"

html_part = find_part(raw.payload, "text/html")

if html_part
  html_body = decode_data(html_part.body.data).encode("UTF-8", invalid: :replace, undef: :replace)
  puts "[save_as_markdown] html extracted (#{html_body.bytesize} bytes)"
else
  html_body = "<html><body><pre>#{CGI.escapeHTML(message[:body].to_s)}</pre></body></html>"
  puts "[save_as_markdown] no html part, using plain text (#{html_body.bytesize} bytes)"
end

attachments   = collect_attachments(raw.payload)
gmail_service = gmail_client.send(:service)
puts "[save_as_markdown] attachments=#{attachments.size}"

saved_filenames = attachments.filter_map do |att|
  puts "[save_as_markdown] fetching #{att[:filename]}"
  response  = gmail_service.get_user_message_attachment("me", message_id, att[:attachment_id])
  att_bytes = decode_data(response.data)
  dest_path = output_dir.join(att[:filename])
  File.binwrite(dest_path, att_bytes)
  puts "[save_as_markdown] saved #{dest_path}"
  att[:filename]
rescue => e
  puts "[save_as_markdown] ERROR saving #{att[:filename]}: #{e.message}"
  nil
end

unless saved_filenames.empty?
  links = saved_filenames.map { |f| %(<li><a href="#{CGI.escapeHTML(f)}">#{CGI.escapeHTML(f)}</a></li>) }.join
  html_body += "\n<hr><p><strong>Attachments:</strong></p><ul>#{links}</ul>"
  puts "[save_as_markdown] appended #{saved_filenames.size} attachment link(s)"
end

html_tmp = Tempfile.new(["email", ".html"])
html_tmp.write(html_body)
html_tmp.close

md_path = output_dir.join("#{safe_subject}__#{safe_date}.md")
puts "[save_as_markdown] pandoc -> #{md_path}"

_out, stderr, status = Open3.capture3(
  "pandoc", "-f", "html", "-t", "gfm", "--wrap=none", "-o", md_path.to_s, html_tmp.path
)
html_tmp.unlink

raise "pandoc failed: #{stderr}" unless status.success?
puts "[save_as_markdown] done -> #{md_path}"
