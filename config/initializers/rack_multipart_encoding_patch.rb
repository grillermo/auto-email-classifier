# TEMPORARY mitigation (2026-11-19) for ruby/ruby#20005, a heap buffer overflow in
# String#upcase and friends on ISO-8859-x / Windows-125x strings (sharp s).
# Multipart form-data lets a client choose the encoding of parsed strings; this forces
# UTF-8 (for UTF-8/ASCII) or BINARY (anything else), so those encodings never reach app code.
# Source: https://gist.github.com/byroot/db331487935e344a70cab1c41b722006
# REMOVE once Ruby is upgraded to a release that includes the fix (and Rack 3.3+ ships this).
require "rack/multipart"
require "stringio"

module RackMultipartEncodingPatch
  def find_encoding(enc)
    case super
    when Encoding::UTF_8, Encoding::US_ASCII
      Encoding::UTF_8
    else
      Encoding::BINARY
    end
  end
end

Rack::Multipart::Parser.prepend(RackMultipartEncodingPatch)

# Boot-time self-test: fails loudly if a Rack upgrade makes the patch ineffective.
params = Rack::Multipart.parse_multipart({
  "REQUEST_METHOD" => "GET", "SERVER_NAME" => "example.org", "SERVER_PORT" => "80",
  "SERVER_PROTOCOL" => "HTTP/1.1", "QUERY_STRING" => "", "PATH_INFO" => "/",
  "rack.url_scheme" => "http", "HTTPS" => "off", "SCRIPT_NAME" => "",
  "rack.errors" => StringIO.new("".b),
  "rack.input" => StringIO.new("--AaB03x\r\ncontent-disposition: form-data; name=\"text\"\r\ncontent-type: text/plain; charset=ISO-8859-1\r\n\r\ncontents\r\n--AaB03x--\r\n".b),
  "CONTENT_LENGTH" => "123",
  "CONTENT_TYPE" => "multipart/form-data; boundary=AaB03x"
})

unless params.flatten.map(&:encoding).uniq == [Encoding::BINARY]
  raise "Rack::Multipart encoding patch is ineffective and must be adapted (see ruby/ruby#20005)"
end
