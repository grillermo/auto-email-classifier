# frozen_string_literal: true

require "base64"
require "open3"
require "tmpdir"

module Statements
  # Pulls the statement PDFs out of a Gmail message, ready to post:
  # - PDF attachments as they are, decrypted with qpdf when encrypted;
  # - PDFs inside ZIP attachments (Santander), unzipped with the password.
  # Other attachments (logos, XML invoices, images) are ignored.
  class AttachmentExtractor
    Pdf = Data.define(:filename, :bytes)

    def initialize(gmail_service:, message_id:, payload:, password: nil)
      @gmail_service = gmail_service
      @message_id = message_id
      @payload = payload
      @password = password
    end

    def pdfs
      attachment_parts.flat_map do |part|
        if pdf?(part)
          [ Pdf.new(filename: part.filename, bytes: decrypt(download(part), part.filename)) ]
        elsif zip?(part)
          unzip_pdfs(download(part), part.filename)
        else
          []
        end
      end
    end

    private

    attr_reader :gmail_service, :message_id, :payload, :password

    def attachment_parts(part = payload)
      return [] if part.nil?

      own = part.filename.present? && part.body&.attachment_id.present? ? [ part ] : []
      own + Array(part.parts).flat_map { |child| attachment_parts(child) }
    end

    def pdf?(part) = part.filename.to_s.downcase.end_with?(".pdf") || part.mime_type == "application/pdf"
    def zip?(part) = part.filename.to_s.downcase.end_with?(".zip") || part.mime_type == "application/zip"

    # google-apis-gmail_v1 already base64-decodes attachment data; decode here
    # only if a client hands back the raw base64url text.
    def download(part)
      data = gmail_service.get_user_message_attachment("me", message_id, part.body.attachment_id).data.to_s.b
      return data if data.start_with?("%PDF", "PK")

      Base64.urlsafe_decode64(data.delete("\r\n"))
    rescue ArgumentError
      data
    end

    def unzip_pdfs(zip_bytes, zip_name)
      Dir.mktmpdir("statement-zip") do |dir|
        zip_path = File.join(dir, "statement.zip")
        out_dir = File.join(dir, "out")
        File.binwrite(zip_path, zip_bytes)

        # -P "" fails fast on an encrypted ZIP instead of prompting.
        _out, err, status = Open3.capture3("unzip", "-qq", "-o", "-j", "-P", password.to_s, zip_path, "-d", out_dir, stdin_data: "")
        unless status.success?
          raise RetryableError, "#{zip_name}: #{password ? "wrong ZIP password" : "ZIP is encrypted and no password is set"} (unzip: #{err.strip.first(200)})"
        end

        Dir.glob(File.join(out_dir, "*")).select { |path| path.downcase.end_with?(".pdf") }.sort.map do |path|
          Pdf.new(filename: File.basename(path), bytes: decrypt(File.binread(path), File.basename(path)))
        end
      end
    end

    def decrypt(bytes, filename)
      raise RejectedError, "#{filename} is not a PDF" unless bytes.start_with?("%PDF")

      Dir.mktmpdir("statement-pdf") do |dir|
        input = File.join(dir, "in.pdf")
        output = File.join(dir, "out.pdf")
        File.binwrite(input, bytes)
        return bytes unless encrypted?(input)

        # Decrypting also drops owner-only restrictions; an empty password is
        # enough for those.
        _out, err, status = Open3.capture3(qpdf, "--decrypt", "--password=#{password}", input, output)
        # qpdf exits 3 for warnings, with a usable output file.
        unless [ 0, 3 ].include?(status.exitstatus) && File.file?(output)
          raise RetryableError, "#{filename}: #{password ? "wrong PDF password" : "PDF is encrypted and no password is set"} (qpdf: #{err.strip.first(200)})"
        end

        File.binread(output)
      end
    end

    # qpdf --is-encrypted exits 0 when encrypted, 2 when not.
    def encrypted?(path)
      _out, _err, status = Open3.capture3(qpdf, "--is-encrypted", path)
      status.exitstatus.zero?
    end

    def qpdf
      ENV["QPDF_BIN"].presence || (File.executable?("/opt/homebrew/bin/qpdf") ? "/opt/homebrew/bin/qpdf" : "qpdf")
    end
  end
end
