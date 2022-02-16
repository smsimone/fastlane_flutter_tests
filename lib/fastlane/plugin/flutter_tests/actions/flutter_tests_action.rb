require 'fastlane/action'
require_relative '../helper/flutter_tests_helper'
require 'open3'
require 'json'

module Fastlane
  module Actions
    class FlutterTestsAction < Action
      # Class that represents a single test that has been run
      class Test
        def initialize(id, name)
          @test_id = id
          @test_name = name
          @test_done = false
          @test_successful = ''
          @test_error = nil
          @test_stacktrace = nil
        end

        def mark_as_done(success, error, stacktrace)
          @test_done = true
          @test_successful = success
          @test_error = error
          unless stacktrace.nil?
            stacktrace = stacktrace.gsub(/ {2,}/, "\n")
            @test_stacktrace = stacktrace
          end
        end

        def get_name
          @test_name
        end

        def get_id
          @test_id
        end

        def _generate_message(print_errors)
          default_message = "[#{@test_successful}] #{@test_name}"
          if print_errors and @test_successful != 'success'
            default_message += "\n[ERROR] -> #{@test_error}\n[STACKTRACE]\n#{@test_stacktrace}"
          end

          if %w[success error].include?(@test_successful)
            color = @test_successful == 'success' ? 32 : 31

            "\e[#{color}m#{default_message}\e[0m"
          else
            default_message
          end
        end

        def print(print_errors)
          UI.message(_generate_message(print_errors))
        end
      end

      class TestRunner
        def initialize
          @launched_tests = Hash.new { |hash, key| hash[key] = nil }
        end

        # Launches all the unit tests contained in the project
        # folder
        def run(flutter_command, print_errors)
          Open3.popen3("#{flutter_command} test --machine") do |stdin, stdout, stderr, thread|
            stdout.each_line do |line|
              parse_json_output(line, print_errors)
            end
          end
        end

        # Parses the json output given by [self.run]
        def parse_json_output(line, print_errors)
          unless line.to_s.strip.empty?
            output = JSON.parse(line)
            unless output.kind_of?(Array)
              type = output['type']
              case type
              when 'testStart'
                id = output['test']['id']
                name = output['test']['name']
                if name.include?('loading')
                  return
                end

                test_item = Test.new(id, name)
                @launched_tests[test_item.get_id] = test_item
              when 'testDone'
                test_id = output['testID']
                test_item = @launched_tests[test_id]
                unless test_item.nil?
                  @launched_tests.delete(test_id)
                  test_item.mark_as_done(output['result'], nil, nil)
                  test_item.print(print_errors)
                end
              when 'error'
                test_id = output['testID']
                test_item = @launched_tests[test_id]
                unless test_item.nil?
                  @launched_tests.delete(test_id)
                  test_item.mark_as_done('error', output['error'], output['stackTrace'])
                  test_item.print(print_errors)
                end
              else
                # ignored
              end
            end
          end
        rescue StandardError => e
          UI.error("Got error during parse_json: #{e.message}")
          UI.error(e.backtrace.join('\n'))
          exit(1)
        end
      end

      def self.run(params)
        TestRunner.new.run(params[:flutter_command], params[:print_errors])
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
            key: :print_errors,
            default_value: true,
            description: 'Specifies if it should print the error of failed tests',
            optional: false,
            type: Boolean
          )
        ]
      end

      def self.is_supported?(platform)
        true
      end
    end
  end
end
