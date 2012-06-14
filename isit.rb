require 'bundler/setup'
require 'sinatra'
require 'rugged'
require 'haml'
require 'ansible'

include Ansible

REPO_PATH = ENV['REPO_PATH']

get '/' do
  @repo = Rugged::Repository.new(REPO_PATH)
  haml :index
end

get '/refs/*' do
  @ref = params[:splat].join('/')
  @repo = Rugged::Repository.new(REPO_PATH)

  @branch = @repo.ref("refs/#{@ref}")

  @master = @repo.ref('refs/remotes/origin/master')

  @walker = Rugged::Walker.new(@repo)
  @walker.sorting(Rugged::SORT_TOPO | Rugged::SORT_REVERSE)
  @walker.push(@branch.target)
  @walker.hide(@master.target)
  haml :branch
end

get '/commits/:sha' do |sha|
  origin_url = `cd #{REPO_PATH} && git config --get remote.origin.url`
  @path = origin_url.match(%r[github.com:(\w+/\w+)\.git$])[1]

  @sha = sha
  @repo = Rugged::Repository.new(REPO_PATH)
  @commit = @repo.lookup(sha)
  @diff = ansi_escaped(`cd #{REPO_PATH} && git show #{sha} --color`)
  haml :commit
end

get '/log' do
  command = "git log -n 100 --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)[%an]%Creset' --abbrev-commit --date=relative"
  @log = ansi_escaped(`cd #{REPO_PATH} && #{command}`)
  haml :log
end

__END__

@@index
%ul
  - @repo.remotes.each do |remote|
    %li
      %h2= remote
      %ul
        - @repo.refs("refs/remotes/#{remote}").each do |ref|
          %li
            %a{href: "/#{ref.name}"}= ref.name.sub("refs/remotes/#{remote}/", '')

@@commit
%h1
  = @sha
  %a{href: "https://github.com/#{@path}/commit/#{@sha}"} github

%pre= @commit.message
%p== #{@commit.author[:name]} (#{@commit.author[:email]}) @ #{@commit.author[:time]}

%pre= @diff

@@branch
%h1= @ref
%p (showing commits not on refs/remotes/origin/master)
%ul
  - @walker.each do |c|
    %li
      %a{href: "/commits/#{c.oid}"}= c.message

@@log
%h1 Log

%pre= @log

@@layout
%html
  %head
    :css
      .ansible_31    { color: red; }
      .ansible_32    { color: green; }
      .ansible_33    { color: blue; }
      .ansible_34    { color: orange; }

  %body
    = yield
