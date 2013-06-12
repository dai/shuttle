# Copyright 2013 Square Inc.
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.

require 'fileutils'
require 'sidekiq_locking'

# Precompiles project manifests and stores them in a cache directory for
# download later.

class ManifestPrecompiler
  include Sidekiq::Worker
  sidekiq_options queue: :low

  include Precompiler

  # Executes this worker.
  #
  # @param [Fixnum] commit_id The ID of a Commit to manifest.
  # @param [String] format The format identifier of an exporter to use.

  def perform(commit_id, format)
    commit = Commit.find(commit_id)
    file_path = path(commit, format)
    write_precompiled_file(file_path) do
      Compiler.new(commit).manifest(format, force: true)
    end
  rescue Compiler::CommitNotReadyError
    # the commit was probably "downgraded" from ready between when the job was
    # queued and when it was started. ignore.
  end

  include SidekiqLocking

  # Returns the path to a cached manifest.
  #
  # @param [Commit] commit A commit that was manifested.
  # @param [Symbol] format A manifest format (such as `:yaml`).
  # @return [Pathname] The path to the cached manifest, if it exists.

  def path(commit, format)
    dir = directory(commit)
    FileUtils.mkdir_p dir
    dir.join "manifest.#{format.to_sym}"
  end

  private

  def directory(commit)
    Rails.root.join 'tmp', 'cache', 'manifest', Rails.env.to_s, commit.id.to_s
  end
end