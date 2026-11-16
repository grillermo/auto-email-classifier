# frozen_string_literal: true

require "open3"
require "tmpdir"

# Builds real PDFs, encrypted PDFs and encrypted ZIPs with qpdf and zip, and a
# fake Gmail service that serves them as attachments.
module StatementTestHelpers
  FakeAttachment = Struct.new(:data)

  class FakeGmailService
    attr_reader :requested

    def initialize(attachments)
      @attachments = attachments
      @requested = []
    end

    def get_user_message_attachment(_user, message_id, attachment_id)
      @requested << [ message_id, attachment_id ]
      FakeAttachment.new(@attachments.fetch(attachment_id))
    end
  end

  def plain_pdf
    @plain_pdf ||= in_tmpdir do |dir|
      run!("qpdf", "--empty", "#{dir}/plain.pdf")
      File.binread("#{dir}/plain.pdf")
    end
  end

  def encrypted_pdf(password)
    in_tmpdir do |dir|
      File.binwrite("#{dir}/in.pdf", plain_pdf)
      run!("qpdf", "--encrypt", password, "owner-#{password}", "256", "--", "#{dir}/in.pdf", "#{dir}/out.pdf")
      File.binread("#{dir}/out.pdf")
    end
  end

  def zip_with(files, password: nil)
    in_tmpdir do |dir|
      files.each { |name, bytes| File.binwrite("#{dir}/#{name}", bytes) }
      args = [ "zip", "-q", "-j" ]
      args += [ "-P", password ] if password
      run!(*args, "#{dir}/out.zip", *files.keys.map { |name| "#{dir}/#{name}" })
      File.binread("#{dir}/out.zip")
    end
  end

  def attachment_part(filename, mime_type, attachment_id)
    Google::Apis::GmailV1::MessagePart.new(
      filename: filename,
      mime_type: mime_type,
      body: Google::Apis::GmailV1::MessagePartBody.new(attachment_id: attachment_id)
    )
  end

  def payload_with(*parts)
    html = Google::Apis::GmailV1::MessagePart.new(
      mime_type: "text/html", filename: "", body: Google::Apis::GmailV1::MessagePartBody.new(data: "<p>hola</p>")
    )
    Google::Apis::GmailV1::MessagePart.new(
      mime_type: "multipart/mixed", filename: "", body: Google::Apis::GmailV1::MessagePartBody.new, parts: [ html, *parts ]
    )
  end

  private

  def in_tmpdir(&block) = Dir.mktmpdir("statement-test", &block)

  def run!(*cmd)
    _out, err, status = Open3.capture3(*cmd)
    # qpdf exits 3 for warnings.
    raise "#{cmd.first} failed: #{err}" unless [ 0, 3 ].include?(status.exitstatus)
  end
end
