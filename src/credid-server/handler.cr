require "socket"
require "openssl"

require "./options"
require "./client_handler"
require "./configure"

class Credid::Server::Handler
  getter options : Credid::Server::Options
  getter users : Acl::Users
  getter groups : Acl::Groups
  # Used to close the server during the execution
  @socket : TCPSocket?
  @handlers : Array(ClientHandler)

  def initialize(@options)
    @users = Acl::Users.new(@options.users_file).load!
    @groups = Acl::Groups.new(@options.groups_file).load!
    @handlers = Array(ClientHandler).new
    Configure.root!(self) if @options.configure_root
    Configure.default_group!(self) if @options.configure_default_group
    exit if @options.configure_and_exit
  end

  def start
    server = TCPServer.new @options.ip, @options.port
    @socket = server
    STDOUT.puts "Credid-Server started on #{@options.ip}:#{@options.port} (#{@options.ssl ? "secure" : "unsecure"})" if @options.verbosity

    context = nil
    if @options.ssl
      context = OpenSSL::SSL::Context::Server.new
      context.private_key = @options.ssl_key_file
      context.certificate_chain = @options.ssl_cert_file
    end

    loop do
      if client = server.accept?
        spawn handle_client(server, client, context)
      else
        break
      end
    end
  end

  def disconnect_user(username : String)
    STDERR.puts "DISCONNECT_USER(#{username})"
    @handlers.select do |handler|
      (user = handler.user) && user.name == username
    end.each do |selected_handler|
      selected_handler.stream.send "DISCONNECT"
    end
  end

  def update_connection(client_handler : ClientHandler)
    # ... ?
    return nil
  end

  # TODO: check ssl socket too
  def stop
    @socket.as(TCPServer).close unless @socket.nil?
  end

  private def handle_client(socket, client, ssl_context = nil)
    STDOUT.puts "New client connected" if @options.verbosity
    handler = (if ssl_context
      ssl_client = OpenSSL::SSL::Socket::Server.new client, ssl_context
      ClientHandler.new(self, ssl_client)
    else
      ClientHandler.new(self, client)
    end)
    @handlers << handler
    handler.start
    # Garbage collect
    @handlers.delete handler
  end
end
