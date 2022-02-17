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
          @test_was_skipped = false
          @test_was_printed = false
        end

        def mark_as_done(success, skipped, error, stacktrace)
          @test_done = true
          @test_successful = success
          @test_was_skipped = skipped
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

        def can_print
          !@test_was_printed
        end

        def get_status
          if @test_was_skipped
            'skipped'
          else
            @test_successful
          end
        end

        def _generate_message
          tag = @test_was_skipped ? 'skipped' : @test_successful

          default_message = "[#{tag}] #{@test_name}"
          if @test_successful != 'success'
            default_message += "\n[ERROR] -> #{@test_error}\n[STACKTRACE]\n#{@test_stacktrace}"
          end

          if %w[success error].include?(@test_successful) || @test_was_skipped
            color = if @test_was_skipped
                      34 # Skipped tests are displayed in blue
                    else
                      # Successful tests are in green and the failed in red
                      @test_successful == 'success' ? 32 : 31
                    end

            "\e[#{color}m#{default_message}\e[0m"
          else
            default_message
          end
        end

        def print
          UI.message(_generate_message)
          @test_was_printed = true
        end
      end

      class TestRunner
        def initialize
          @launched_tests = Hash.new { |hash, key| hash[key] = nil }
        end

        # Wraps the message to color it
        #
        # @param message [String] the message that has to be wrapped
        # @param color [Integer] the color of the message (34 -> blue, 32 -> green, 31 -> red)
        def _colorize(message, color)
          "\e[#{color}m#{message}\e[0m"
        end

        # Launches all the unit tests contained in the project
        # folder
        def run(flutter_command, print_only_failed, print_stats)
          Open3.popen3("#{flutter_command} test --machine") do |stdin, stdout, stderr, thread|
            stdout.each_line do |line|
              parse_json_output(line, print_only_failed)
            end
          end

          if print_stats
            stats = Hash.new { |hash, key| hash[key] = 0 }
            @launched_tests.values.each { |item|
              unless item.nil?
                stats[item.get_status] += 1
              end
            }

            skipped_tests = stats['skipped'].nil? ? 0 : stats['skipped']
            failed_tests = stats['error'].nil? ? 0 : stats['error']
            successful_tests = stats['success'].nil? ? 0 : stats['success']
            table = [
              %w[Successful Failed Skipped],
              [successful_tests, failed_tests, skipped_tests]
            ]

            messages = ["Ran #{@launched_tests.values.filter { |e| !e.nil? }.length} tests"]
            colors = { 0 => 32, 1 => 31, 2 => 34 }
            max_length = 0
            (0..2).each { |i|
              msg = "#{table[0][i]}:\t#{table[1][i]}"
              max_length = [max_length, msg.length].max
              messages.append(_colorize(msg, colors[i]))
            }

            UI.message('-' * max_length)
            messages.each { |m| UI.message(m) }
            UI.message('-' * max_length)
          end
        end

        # Parses the json output given by [self.run]
        def parse_json_output(line, print_only_failed)
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
                if !test_item.nil? && test_item.can_print
                  was_skipped = output['skipped']
                  test_item.mark_as_done(output['result'], was_skipped, nil, nil)
                  if was_skipped || !print_only_failed
                    test_item.print
                  end
                end
              when 'error'
                test_id = output['testID']
                test_item = @launched_tests[test_id]
                if !test_item.nil? && test_item.can_print
                  test_item.mark_as_done('error', false, output['error'], output['stackTrace'])
                  test_item.print
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
        TestRunner.new.run(params[:flutter_command], params[:print_only_failed], params[:print_stats])
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
        ]
      end

      def self.is_supported?(platform)
        true
      end
    end
  end
end
