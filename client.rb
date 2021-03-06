#! /usr/bin/env ruby
Thread.abort_on_exception = true

require 'socket'
require 'json'
require 'curses'
require_relative File.join *%w( lib client render )
require_relative File.join *%w( lib client state )
require_relative File.join *%w( lib client title_screen )
require_relative File.join *%w( lib client options )

options = Options.parse!
require_relative File.join(*%w( lib client debug_log )) if options.debug

SHIP            = ARGV[0]
CLIENT_PORT     = options.client_port
SERVER_IP       = options.server_ip
SERVER_PORT     = options.server_port
SOCK            = UDPSocket.new.tap{ |s| s.connect(SERVER_IP, SERVER_PORT) }
GAME_WIN_HEIGHT = 30
GAME_WIN_WIDTH  = 60
LOG_WIN_HEIGHT  = 1
@game_states    = []

def ship_valid?
  return false unless SHIP
  SHIP.length == 4  &&
  SHIP.match(/.*[aeiouy].*[aeiouy].*/i)
end
abort("Your ship configuration needs to be 4 charaters with two vowels") unless ship_valid?

TitleScreen.show

@win = Curses::Window.new( GAME_WIN_HEIGHT, GAME_WIN_WIDTH, 0              , 0 )
@log = Curses::Window.new( LOG_WIN_HEIGHT,  GAME_WIN_WIDTH, GAME_WIN_HEIGHT, 0 )

def notify_server(mvmt=' ')
  msg  = {}.update conf: SHIP, mvmt: mvmt, port: CLIENT_PORT, 
              win_width: GAME_WIN_WIDTH, win_height: GAME_WIN_HEIGHT 
  SOCK.send(msg.to_json, 0)
end

def ident
  "#{SOCK.addr.last}:#{CLIENT_PORT}"
end

def mvmt_valid?(mvmt)
  mvmt.match /[hjkl\s]/i
end

# Send my initial movement to the server to connect
notify_server

# Listen for key presses and update the server
Thread.new do
  loop do
    mvmt = @win.getch
    notify_server(mvmt) if mvmt_valid?(mvmt)
  end
end

# Listen for server state updates
Thread.new do
  Socket.udp_server_loop(CLIENT_PORT) do |msg, msg_src|
    new_state       = State.new(JSON.parse(msg))
    old_state       = @game_states.last
    @game_states   << new_state
    render = Render.new(@win, @log, new_state, old_state, ident)
    render.draw
    render.update_score
  end
end.join
