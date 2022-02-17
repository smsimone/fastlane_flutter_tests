require 'fastlane/action'
require_relative '../helper/flutter_unit_test_helper'
require_relative '../helper/flutter_integration_test_helper'
require 'open3'
require 'json'
require_relative '../model/test_item'

module Fastlane
  module Actions
    class FlutterTestsAction < Action
      def self.run(params)
        test_type = params[:test_type]
        if %w[all unit].include? test_type
          Helper::FlutterUnitTestHelper.new.run(params[:flutter_command], params[:print_only_failed], params[:print_stats])
        end
        if %w[all integration].include? test_type

          if params[:driver_path].nil? || params[:integration_tests].nil?
            UI.user_error!("If launching integration tests, 'driver_path' and 'integration_tests' parameters must be inserted")
            exit(1)
          end

          Helper::FlutterIntegrationTestHelper.new(params[:driver_path], params[:integration_tests], params[:flutter_command]).run(params[:platform], params[:force_launch])
        end
      end

      def self.description
        "Extension that helps to run flutter tests"
      end

      def self.authors
        ["smaso"]
      end

      def self.return_value
        "Returns 0 or 1 based on the tests output"
      end

      def self.details
        # Optional:
        "Extension that helps to run both unit tests and integration tests for your flutter application and parses the output given by the default tester and shows in a more readable way"
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(
            key: :flutter_command,
            default_value: 'flutter',
            description: 'Specifies the command to use flutter',
            optional: false,
            type: String
          ),
          FastlaneCore::ConfigItem.new(
            key: :print_only_failed,
            default_value: true,
            description: 'Specifies if it should only print the failed and the skipped tests',
            optional: false,
            type: Boolean
          ),
          FastlaneCore::ConfigItem.new(
            key: :print_stats,
            default_value: true,
            description: 'If defined, it will print how many tests were done/skipped/failed',
            optional: false,
            type: Boolean
          ),
          FastlaneCore::ConfigItem.new(
            key: :test_type,
            default_value: 'all',
            description: "Specifies which tests should be run. Accepted values",
            verify_block: proc do |value|
              UI.user_error!("Wrong value, #{value} not accepted. Should be 'unit','integration' or 'all'.") unless %w[unit integration all].include? value
            end,
            optional: false,
            type: String,
          ),
          FastlaneCore::ConfigItem.new(
            key: :driver_path,
            description: "Specifies the path of the driver file",
            optional: true,
            type: String,
            verify_block: proc do |value|
              UI.user_error!("Driver file doesn't exists") unless File.file?(value)
            end
          ),
          FastlaneCore::ConfigItem.new(
            key: :integration_tests,
            description: "Specifies the path of the folder containing all the integration tests",
            optional: true,
            type: String,
            verify_block: proc do |value|
              UI.user_error!("Integration test folder doesn't exists") unless File.exist?(value) && File.directory?(value)
            end
          ),
          FastlaneCore::ConfigItem.new(
            key: :platform,
            description: "Specifies the os on which the tests should run on",
            optional: false,
            type: String,
            verify_block: proc do |value|
              UI.user_error!("Platform #{value} is not supported") unless %w[android ios].include? value.to_s.downcase
            end
          ),
          FastlaneCore::ConfigItem.new(
            key: :force_launch,
            description: "If true, the plugin will try to launch an emulator in case it's not already running",
            optional: false,
            type: Boolean,
            default_value: true,
          ),
        ]
      end

      def self.is_supported?(platform)
        true
      end
    end
  end
end
