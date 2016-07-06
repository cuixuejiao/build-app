#!/usr/bin/env ruby

project_name = ARGV[0]

require 'xcodeproj'
xcproj = Xcodeproj::Project.open("#{project_name}.xcodeproj")
xcproj.recreate_user_schemes
xcproj.save
