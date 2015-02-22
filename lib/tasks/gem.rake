namespace :bump do
  namespace :version do
    class ProjectVersion
      FILE = File.dirname(__FILE__) + '/../yap/shell/version.rb'
      PATTERN = /VERSION\s*=\s*"(\d+)\.(\d+)\.(\d+)"/m

      def initialize(file=FILE, pattern=PATTERN)
        @file = file
        @pattern = pattern
      end

      def bump(major:nil, minor:nil, patch:nil)
        version = nil
        contents.sub!(@pattern) do
          _major = major.call($1) if major
          _minor = minor.call($2) if minor
          _patch = patch.call($3) if patch
          version = %|VERSION = "#{_major}.#{_minor}.#{_patch}"|
        end
        File.write(@file, contents)
        system "bundle"
        system "git add #{ProjectVersion::FILE}\ && git commit -m 'Bumping version to #{version}'"
      end

      private

      def contents
        @contents ||= File.read(@file)
      end
    end

    desc "Increments the patch number by 1 for the project"
    task :patch do
      ProjectVersion.new.bump(
        major: ->(major){ major },
        minor: ->(minor){ minor },
        patch: ->(patch){ patch.succ }
      )
    end

    desc "Increments the minor number by 1 for the project"
    task :minor do
      ProjectVersion.new.bump(
        major: ->(major){ major },
        minor: ->(minor){ minor.succ },
        patch: ->(patch){ 0 }
      )
    end

    desc "Increments the major number by 1 for the project"
    task :major do
      ProjectVersion.new.bump(
        major: ->(major){ major.succ },
        minor: ->(minor){ 0 },
        patch: ->(patch){ 0 }
      )
    end

  end
end
