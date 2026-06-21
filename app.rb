# frozen_string_literal: true

require "sinatra/base"
require "open3"
require "tempfile"
require "fileutils"
require "securerandom"
require "yaml"

# Manages SSH public keys (~/.ssh/authorized_keys): list, add, and delete.
# Runs as an Open OnDemand Passenger app with the privileges of the
# already-authenticated user.
class App < Sinatra::Base
  APPEARANCE_DEFAULTS = {
    navbar_bg:     "#212529",
    navbar_text:   "#ffffff",
    body_bg:       "#f8f9fa",
    primary_color: "#0d6efd"
  }.freeze

  VALID_COLOR = /\A#[0-9a-fA-F]{3,8}\z/

  set :appearance, begin
    config_file = File.join(__dir__, "appearance.yml")
    loaded = File.exist?(config_file) ? (YAML.load_file(config_file, symbolize_names: true) || {}) : {}
    APPEARANCE_DEFAULTS.each_with_object({}) do |(key, default), h|
      value = loaded[key].to_s
      h[key] = value.match?(VALID_COLOR) ? value : default
    end
  end

  enable :sessions
  set :session_secret, lambda {
    # Persist a per-user secret so sessions (and CSRF tokens) survive
    # Passenger process restarts
    secret_file = File.join(Dir.home, ".config", "ssh_key_manager", "session_secret")
    unless File.exist?(secret_file)
      FileUtils.mkdir_p(File.dirname(secret_file), mode: 0o700)
      File.write(secret_file, SecureRandom.hex(64))
      File.chmod(0o600, secret_file)
    end
    File.read(secret_file).strip
  }.call

  use Rack::Protection::AuthenticityToken

  helpers do
    def h(text)
      Rack::Utils.escape_html(text)
    end

    def csrf_token
      Rack::Protection::AuthenticityToken.token(session)
    end

    def ssh_dir
      File.join(Dir.home, ".ssh")
    end

    def authorized_keys_path
      File.join(ssh_dir, "authorized_keys")
    end

    # Validate a single public key line with `ssh-keygen -lf` and return its
    # details, or nil if the key is invalid.
    # Sample output: "256 SHA256:xxxx... user@host (ED25519)"
    def key_info(key_line)
      Tempfile.create("pubkey") do |f|
        f.write("#{key_line}\n")
        f.flush
        out, _err, status = Open3.capture3("ssh-keygen", "-lf", f.path)
        break nil unless status.success?

        bits, fingerprint, *comment, type = out.strip.split(" ")
        {
          line: key_line,
          bits: bits,
          fingerprint: fingerprint,
          comment: comment.join(" "),
          type: type.to_s.delete("()")
        }
      end
    end

    # Load keys from authorized_keys, skipping blank lines and "#" comments
    def load_keys
      return [] unless File.exist?(authorized_keys_path)

      File.readlines(authorized_keys_path).filter_map do |line|
        stripped = line.strip
        next if stripped.empty? || stripped.start_with?("#")

        key_info(stripped) || { line: stripped, fingerprint: nil }
      end
    end

    def set_flash(type, message)
      session[:flash] = { "type" => type, "message" => message }
    end
  end

  before do
    @appearance = settings.appearance
  end

  get "/" do
    @flash = session.delete(:flash)
    @keys = load_keys
    erb :index
  end

  post "/keys" do
    key = params[:public_key].to_s.strip

    if key.empty?
      set_flash("danger", "Please enter a public key.")
      redirect url("/")
    end

    if key.include?("\n")
      set_flash("danger", "Please add one public key at a time.")
      redirect url("/")
    end

    info = key_info(key)
    if info.nil?
      set_flash("danger", "Not a valid SSH public key. Please check the format.")
      redirect url("/")
    end

    if load_keys.any? { |k| k[:fingerprint] == info[:fingerprint] }
      set_flash("warning", "This public key is already registered (#{info[:fingerprint]}).")
      redirect url("/")
    end

    FileUtils.mkdir_p(ssh_dir, mode: 0o700)
    existing = File.exist?(authorized_keys_path) ? File.read(authorized_keys_path) : ""
    File.open(authorized_keys_path, File::WRONLY | File::APPEND | File::CREAT, 0o600) do |f|
      f.write("\n") unless existing.empty? || existing.end_with?("\n")
      f.write("#{key}\n")
    end

    set_flash("success", "Public key added (#{info[:fingerprint]}).")
    redirect url("/")
  end

  post "/keys/delete" do
    fingerprint = params[:fingerprint].to_s
    if fingerprint.empty? || !File.exist?(authorized_keys_path)
      set_flash("danger", "The key to delete was not found.")
      redirect url("/")
    end

    lines = File.readlines(authorized_keys_path)
    kept = lines.reject do |line|
      stripped = line.strip
      next false if stripped.empty? || stripped.start_with?("#")

      key_info(stripped)&.dig(:fingerprint) == fingerprint
    end

    if kept.size == lines.size
      set_flash("danger", "The key to delete was not found.")
      redirect url("/")
    end

    # Rewrite atomically (write a temp file, then rename) keeping mode 0600
    tmp_path = File.join(ssh_dir, ".authorized_keys.tmp-#{Process.pid}")
    File.open(tmp_path, File::WRONLY | File::CREAT | File::TRUNC, 0o600) do |f|
      f.write(kept.join)
    end
    File.rename(tmp_path, authorized_keys_path)

    set_flash("success", "Public key deleted (#{fingerprint}).")
    redirect url("/")
  end
end
