require "json"

module VagrantPlugins
  module Orchestrate
    class RepoStatus
      attr_reader :last_sync
      attr_accessor :local_path

      def initialize
        @last_sync = Time.now.utc    # Managed servers could be in different timezones
        @local_path = nil
      end

      def ref
        # Env vars are here only for testing, since vagrant-spec is executed from
        # a temp directory and can't use git to get repository information
        @ref ||= ENV["VAGRANT_ORCHESTRATE_STATUS_TEST_REF"]
        @ref ||= `git log --pretty=format:'%H' --abbrev-commit -1`
        @ref
      end

      def remote_origin_url
        @remote_origin_url ||= ENV["VAGRANT_ORCHESTRATE_STATUS_TEST_REMOTE_ORIGIN_URL"]
        @remote_origin_url ||= `git config --get remote.origin.url`.chomp
        @remote_origin_url
      end

      def repo
        @repo ||= File.basename(remote_origin_url, ".git")
        @repo
      end

      def user
        user = ENV["USER"] || ENV["USERNAME"] || "unknown"
        user = ENV["USERDOMAIN"] + "\\" + user if ENV["USERDOMAIN"]

        @user ||= user
        @user
      end

      def to_json
        contents = {
          repo: repo,
          remote_url: remote_origin_url,
          ref: ref,
          user: user,
          last_sync: last_sync
        }
        JSON.pretty_generate(contents)
      end

      def write(tmp_path)
        @local_path = File.join(tmp_path, "vagrant_orchestrate_status")
        File.write(@local_path, to_json)
      end

      # The path to where this should be stored on a remote machine, inclusive
      # of the file name.
      def remote_path(communicator)
        if communicator == :winrm
          File.join("c:", "programdata", "vagrant_orchestrate", repo)
        else
          File.join("/var", "state", "vagrant_orchestrate", repo)
        end
      end

      def self.clean?
        `git diff --exit-code 2>&1`
        $CHILD_STATUS == 0
      end

      def self.committed?
        `git diff-index --quiet --cached HEAD 2>&1`
        $CHILD_STATUS == 0
      end

      # Return whether there are any untracked files in the git repo
      def self.untracked?
        output = `git ls-files --other --exclude-standard --directory --no-empty-directory 2>&1`
        # This command lists untracked files. There are untracked files if the ouput is not empty.
        !output.empty?
      end
    end
  end
end
