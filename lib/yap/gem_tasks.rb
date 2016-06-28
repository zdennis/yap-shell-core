# frozen_string_literal: true
require "rake/clean"
CLOBBER.include "pkg"

require "yap/gem_helper"
Yap::GemHelper.install_tasks
